#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.5 — Aplicador Seguro de Configurações de Sistema (/etc)
# Destino: scripts/instalacao/easyarch-aplicar-etc.sh
#
# Correções estruturais v4.4:
#   - Não substitui /etc/resolv.conf dentro de arch-chroot (evita EBUSY no bind
#     mount e evita matar DNS no chroot); instala drop-in tmpfiles.d para criar
#     o symlink no primeiro boot.
#   - Em sistema ativo, só troca /etc/resolv.conf após systemd-resolved subir
#     com sucesso, contabilizando qualquer falha de ln -sf em FAILS.
# ==============================================================================

set -uo pipefail

ASSUME_YES=0
while [[ "${1:-}" == -* ]]; do
    case "$1" in
        --yes|-y) ASSUME_YES=1; shift ;;
        -h|--help)
            printf 'Uso: sudo easyarch-aplicar-etc.sh [--yes]\n'
            exit 0
            ;;
        *) printf '[ERRO] Opção desconhecida: %s\n' "$1" >&2; exit 1 ;;
    esac
done

if [[ "$(id -u)" -ne 0 ]]; then
    printf '[ERRO] Execute com sudo: sudo %s\n' "$0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BACKUP_DIR="/root/easyarch-etc-backup-$(date '+%Y%m%d-%H%M%S')"
FAILS=0
SKIP_NFT_RESTART=0

IS_LIVE_SYSTEMD=0
if [[ -d /run/systemd/system ]] && ! systemd-detect-virt --chroot >/dev/null 2>&1; then
    IS_LIVE_SYSTEMD=1
fi

printf '=== EasyArch v5.5 — Aplicar Configurações de Sistema (/etc) ===\n'
printf 'Backup automático será salvo em: %s\n' "$BACKUP_DIR"
if (( IS_LIVE_SYSTEMD == 0 )); then
    printf '[INFO] Ambiente chroot/sem systemd detectado: serviços serão apenas habilitados para o próximo boot.\n'
fi
printf '\n'

if (( ASSUME_YES == 0 )); then
    read -r -p "Confirmar aplicação das configs em /etc? (s/N): " ans
    if [[ "${ans,,}" != "s" && "${ans,,}" != "sim" ]]; then
        printf '[EasyArch] Cancelado pelo usuário.\n'
        exit 0
    fi
fi

mkdir -p "$BACKUP_DIR" \
         /etc/xdg/reflector \
         /etc/systemd/resolved.conf.d \
         /etc/systemd/journald.conf.d \
         /etc/systemd/coredump.conf.d \
         /etc/tmpfiles.d \
         /etc/NetworkManager/conf.d \
         /etc/sysctl.d \
         /etc/modules-load.d \
         /etc/nftables.d \
         /etc/pacman.d/hooks \
         /etc/default

copy_with_backup() {
    local rel="$1"
    local src="${ROOT_DIR}/${rel}"
    local dst="/${rel}"
    if [[ ! -f "$src" ]]; then
        printf '[FALHA] Arquivo de origem ausente: %s\n' "$src" >&2
        FAILS=$((FAILS + 1))
        return 1
    fi
    if [[ -e "$dst" || -L "$dst" ]]; then
        mkdir -p "$(dirname "${BACKUP_DIR}/${rel}")"
        cp -a "$dst" "${BACKUP_DIR}/${rel}"
    fi
    [[ -L "$dst" ]] && rm -f "$dst"
    install -m 0644 "$src" "$dst"
    printf '[OK]    Aplicado: %s\n' "$dst"
}

copy_with_backup "etc/systemd/zram-generator.conf"
copy_with_backup "etc/systemd/resolved.conf.d/10-easyarch-dot.conf"
copy_with_backup "etc/systemd/journald.conf.d/10-easyarch-lean.conf"
copy_with_backup "etc/systemd/coredump.conf.d/10-easyarch-nocore.conf"
if (( IS_LIVE_SYSTEMD == 0 )); then
    copy_with_backup "etc/tmpfiles.d/10-easyarch-resolv.conf"
fi
copy_with_backup "etc/NetworkManager/conf.d/10-easyarch-dns.conf"
copy_with_backup "etc/default/earlyoom"
copy_with_backup "etc/sysctl.d/90-easyarch-memory.conf"
copy_with_backup "etc/sysctl.d/95-easyarch-security.conf"
copy_with_backup "etc/modules-load.d/ntsync.conf"
copy_with_backup "etc/nftables.conf"
copy_with_backup "etc/nftables.d/00-base.nft"
copy_with_backup "etc/nftables.d/20-waydroid.nft"
copy_with_backup "etc/xdg/reflector/reflector.conf"
copy_with_backup "etc/pacman.d/hooks/50-bootbackup.hook"

# Validação explícita do nftables
if command -v nft >/dev/null 2>&1; then
    if nft -c -f /etc/nftables.conf; then
        printf '[OK]    Sintaxe /etc/nftables.conf validada.\n'
    else
        printf '[FALHA] Erro de sintaxe em /etc/nftables.conf. Restaurando a versão anterior.\n' >&2
        FAILS=$((FAILS + 1))
        SKIP_NFT_RESTART=1
        for nft_rel in etc/nftables.conf etc/nftables.d/00-base.nft etc/nftables.d/20-waydroid.nft; do
            if [[ -e "${BACKUP_DIR}/${nft_rel}" || -L "${BACKUP_DIR}/${nft_rel}" ]]; then
                cp -a "${BACKUP_DIR}/${nft_rel}" "/${nft_rel}"
                printf '[INFO]  /%s restaurado de %s\n' "$nft_rel" "$BACKUP_DIR" >&2
            else
                rm -f "/${nft_rel}"
                printf '[INFO]  /%s removido (não existia antes); firewall NÃO será reiniciado.\n' "$nft_rel" >&2
            fi
        done
    fi
fi

if (( IS_LIVE_SYSTEMD == 1 )); then
    if sysctl --system; then
        printf '[OK]    Parâmetros sysctl aplicados.\n'
    else
        printf '[FALHA] sysctl --system retornou erro (verifique parâmetros acima).\n' >&2
        FAILS=$((FAILS + 1))
    fi

    systemctl daemon-reload

    resolved_ok=0
    if systemctl enable systemd-resolved.service && systemctl restart systemd-resolved.service; then
        printf '[OK]    Serviço habilitado e reiniciado: systemd-resolved.service\n'
        resolved_ok=1
    else
        printf '[FALHA] Falha ao habilitar/reiniciar: systemd-resolved.service\n' >&2
        FAILS=$((FAILS + 1))
    fi

    # Só aponta /etc/resolv.conf para o stub depois que systemd-resolved estiver ativo
    if (( resolved_ok == 1 )); then
        if [[ -e /etc/resolv.conf && ! -L /etc/resolv.conf ]]; then
            cp -a /etc/resolv.conf "${BACKUP_DIR}/resolv.conf.orig"
        fi
        if ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf; then
            printf '[OK]    Link configurado: /etc/resolv.conf -> /run/systemd/resolve/stub-resolv.conf\n'
        else
            printf '[FALHA] Não foi possível criar symlink /etc/resolv.conf -> /run/systemd/resolve/stub-resolv.conf.\n' >&2
            FAILS=$((FAILS + 1))
        fi
    else
        printf '[AVISO] /etc/resolv.conf preservado pois systemd-resolved.service falhou ao iniciar.\n' >&2
    fi

    # Evita conflito de DHCP/rotas com outros gerenciadores de rede pré-existentes
    for conflict in systemd-networkd.service systemd-networkd.socket iwd.service dhcpcd.service; do
        if systemctl is-enabled --quiet "$conflict" 2>/dev/null || systemctl is-active --quiet "$conflict" 2>/dev/null; then
            systemctl disable --now "$conflict" >/dev/null 2>&1 || true
            printf '[INFO]  Gerenciador conflitante desabilitado: %s\n' "$conflict"
        fi
    done

    for svc in NetworkManager.service earlyoom.service nftables.service; do
        if [[ "$svc" == "nftables.service" ]]; then
            if (( SKIP_NFT_RESTART == 1 )); then
                printf '[AVISO] nftables.service NÃO recarregado: configuração inválida foi revertida.\n' >&2
                continue
            fi
            # Usa reload quando já ativo (evita ExecStop=nft flush ruleset da unit do Arch, preservando Docker/libvirt/Waydroid)
            if systemctl enable "$svc" && {
                if systemctl is-active --quiet "$svc" 2>/dev/null; then
                    systemctl reload "$svc"
                else
                    systemctl start "$svc"
                fi
            }; then
                printf '[OK]    Serviço habilitado e carregado sem flush global: %s\n' "$svc"
            else
                printf '[FALHA] Falha ao habilitar/recarregar: %s\n' "$svc" >&2
                FAILS=$((FAILS + 1))
            fi
            continue
        fi
        if systemctl enable "$svc" && systemctl restart "$svc"; then
            printf '[OK]    Serviço habilitado e reiniciado: %s\n' "$svc"
        else
            printf '[FALHA] Falha ao habilitar/reiniciar: %s\n' "$svc" >&2
            FAILS=$((FAILS + 1))
        fi
    done

    if systemctl restart systemd-journald.service; then
        printf '[OK]    Serviço reiniciado: systemd-journald.service\n'
    else
        printf '[FALHA] Falha ao reiniciar: systemd-journald.service\n' >&2
        FAILS=$((FAILS + 1))
    fi

    swaps_now="$(swapon --noheadings --show=NAME 2>/dev/null || true)"
    if ! grep -q 'zram0' <<<"$swaps_now"; then
        if systemctl start dev-zram0.swap 2>/dev/null; then
            printf '[OK]    ZRAM ativada como swap imediatamente: dev-zram0.swap\n'
        elif systemctl start systemd-zram-setup@zram0.service 2>/dev/null; then
            printf '[INFO]  Dispositivo zram0 preparado; swap será ativado no próximo boot.\n'
        else
            printf '[INFO]  ZRAM será ativada automaticamente no próximo boot.\n'
        fi
    fi

    if systemctl cat reflector.timer >/dev/null 2>&1; then
        if systemctl enable --now reflector.timer; then
            printf '[OK]    Timer ativo: reflector.timer\n'
        else
            printf '[FALHA] Falha ao ativar: reflector.timer\n' >&2
            FAILS=$((FAILS + 1))
        fi
    fi

    if systemctl enable --now fstrim.timer; then
        printf '[OK]    Timer ativo: fstrim.timer\n'
    else
        printf '[FALHA] Falha ao ativar: fstrim.timer\n' >&2
        FAILS=$((FAILS + 1))
    fi
else
    printf '[INFO]  Em chroot, /etc/resolv.conf foi preservado; /etc/tmpfiles.d/10-easyarch-resolv.conf criará o symlink no primeiro boot.\n'
    for conflict in systemd-networkd.service systemd-networkd.socket iwd.service dhcpcd.service; do
        systemctl disable "$conflict" >/dev/null 2>&1 || true
    done
    for svc in systemd-resolved.service NetworkManager.service earlyoom.service nftables.service fstrim.timer; do
        if systemctl enable "$svc"; then
            printf '[OK]    Habilitado para o próximo boot: %s\n' "$svc"
        else
            printf '[FALHA] Falha ao habilitar: %s\n' "$svc" >&2
            FAILS=$((FAILS + 1))
        fi
    done
    if [[ -f /usr/lib/systemd/system/reflector.timer ]]; then
        if systemctl enable reflector.timer; then
            printf '[OK]    Habilitado para o próximo boot: reflector.timer\n'
        else
            printf '[FALHA] Falha ao habilitar: reflector.timer\n' >&2
            FAILS=$((FAILS + 1))
        fi
    fi
fi

if systemctl enable apparmor.service; then
    printf '[OK]    apparmor.service habilitado (requer lsm= no kernel e reboot).\n'
else
    printf '[FALHA] Falha ao habilitar apparmor.service.\n' >&2
    FAILS=$((FAILS + 1))
fi

if systemctl list-unit-files auditd.service >/dev/null 2>&1; then
    if (( IS_LIVE_SYSTEMD == 1 )); then
        systemctl enable --now auditd.service >/dev/null 2>&1 && printf '[OK]    auditd.service habilitado e ativo (logs AppArmor).\n' || true
    else
        systemctl enable auditd.service >/dev/null 2>&1 && printf '[OK]    auditd.service habilitado para o próximo boot.\n' || true
    fi
fi


if [[ "$(findmnt -n -o FSTYPE / 2>/dev/null || true)" == "btrfs" ]] && [[ -f /usr/lib/systemd/system/btrfs-scrub@.timer ]]; then
    if (( IS_LIVE_SYSTEMD == 1 )); then
        systemctl enable --now btrfs-scrub@-.timer >/dev/null 2>&1 && printf '[OK]    Timer ativo: btrfs-scrub@-.timer (integridade Btrfs mensal).
' || true
    else
        systemctl enable btrfs-scrub@-.timer >/dev/null 2>&1 && printf '[OK]    Habilitado para o próximo boot: btrfs-scrub@-.timer
' || true
    fi
fi

if (( FAILS > 0 )); then
    printf '\n[ATENÇÃO] Concluído com %d falha(s). Revise as mensagens acima antes de prosseguir.\n' "$FAILS" >&2
    exit 1
fi

printf '\n[SUCESSO] Todas as configurações de /etc e serviços foram aplicadas sem erros.\n'
printf 'Próximo passo: configurar Snapper (sudo ./scripts/instalacao/easyarch-configurar-snapper.sh) e reiniciar.\n'
