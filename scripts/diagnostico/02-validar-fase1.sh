#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Script 02: Validação Pós-Instalação da Fase 1 (SOMENTE LEITURA)
# Objetivo: Verificar objetivamente cada componente da Fase 1 sem mascarar falhas.
# ==============================================================================

set -uo pipefail

PASS=0
WARN=0
FAIL=0

ok()   { printf '[OK]    %s\n' "$1"; PASS=$((PASS + 1)); }
warn() { printf '[AVISO] %s\n' "$1"; WARN=$((WARN + 1)); }
fail() { printf '[FALHA] %s\n' "$1"; FAIL=$((FAIL + 1)); }

printf '============================================================\n'
printf ' EasyArch v5.4 — VALIDAÇÃO DA FASE 1 (%s)\n' "$(date -Is)"
printf '============================================================\n\n'

# 1. UEFI
if [[ -d /sys/firmware/efi/efivars ]]; then
    ok "Boot em modo UEFI confirmado."
else
    fail "Sistema não iniciou em modo UEFI."
fi

# 2. Kernel e ntsync (existência + permissões de leitura/escrita)
kver="$(uname -r)"
ok "Kernel em execução: ${kver}"
if [[ -c /dev/ntsync ]]; then
    if [[ -r /dev/ntsync && -w /dev/ntsync ]]; then
        ok "/dev/ntsync presente e acessível (rw) ($(ls -l /dev/ntsync | awk '{print $1, $3, $4}'))."
    else
        warn "/dev/ntsync presente, mas sem permissão rw para o usuário atual ($(ls -l /dev/ntsync | awk '{print $1, $3, $4}'))."
    fi
else
    warn "/dev/ntsync ausente (verifique se o módulo ntsync está carregado)."
fi

# 3. Btrfs e compressão
root_fs="$(findmnt -n -o FSTYPE / 2>/dev/null || echo desconhecido)"
root_opts="$(findmnt -n -o OPTIONS / 2>/dev/null || echo '')"
if [[ "$root_fs" == "btrfs" ]]; then
    ok "Raiz montada em Btrfs."
    if [[ "$root_opts" == *"compress=zstd"* ]]; then
        ok "Compressão Zstd ativa na raiz (${root_opts})."
    else
        warn "Compressão Zstd não detectada nas opções da raiz (${root_opts})."
    fi
else
    fail "Sistema de arquivos raiz não é Btrfs (atual: ${root_fs})."
fi

# 4. ZRAM e zswap
if [[ -r /sys/module/zswap/parameters/enabled ]] && [[ "$(cat /sys/module/zswap/parameters/enabled)" == "N" ]]; then
    ok "zswap desabilitado (sem conflito com ZRAM)."
else
    warn "zswap parece ativo; adicione zswap.enabled=0 nos parâmetros do kernel."
fi

swaps_out="$(swapon --noheadings --show=NAME,SIZE,USED,PRIO 2>/dev/null || true)"
if grep -q 'zram0' <<<"$swaps_out"; then
    ok "ZRAM ativa como swap: $(grep 'zram0' <<<"$swaps_out" | head -n 1)"
elif command -v zramctl >/dev/null 2>&1 && grep -q 'zram0' <<<"$(zramctl --noheadings 2>/dev/null || true)"; then
    warn "Dispositivo zram0 existe mas ainda não está ativo no swap (rode: sudo systemctl start dev-zram0.swap ou reinicie)."
else
    fail "Dispositivo zram0 não encontrado."
fi

# 5. Serviços críticos da Fase 1
for svc in earlyoom.service apparmor.service nftables.service systemd-resolved.service fstrim.timer; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        ok "Serviço/timer ativo: ${svc}"
    else
        fail "Serviço/timer INATIVO: ${svc}"
    fi
done

# 6. AppArmor LSM
if [[ -r /sys/kernel/security/lsm ]] && grep -q apparmor /sys/kernel/security/lsm; then
    ok "AppArmor carregado no kernel ($(cat /sys/kernel/security/lsm))."
else
    fail "AppArmor não está listado em /sys/kernel/security/lsm."
fi

# 7. DNS-over-TLS (verificação ponta a ponta incluindo /etc/resolv.conf)
resolv_ok=0
if [[ -L /etc/resolv.conf ]] && readlink -f /etc/resolv.conf | grep -q 'stub-resolv\.conf'; then
    resolv_ok=1
elif [[ -r /etc/resolv.conf ]] && grep -q '^nameserver 127\.0\.0\.53' /etc/resolv.conf; then
    resolv_ok=1
fi
if command -v resolvectl >/dev/null 2>&1; then
    rstatus="$(resolvectl status 2>/dev/null || true)"
    rglobal="$(awk '/^Global/{g=1; next} /^Link /{g=0} g{print}' <<<"$rstatus")"
    [[ -z "$rglobal" ]] && rglobal="$rstatus"
    dot_mode="off"
    if grep -qiE 'DNSOverTLS setting:[[:space:]]*opportunistic|DNSOverTLS=opportunistic' <<<"$rglobal"; then
        dot_mode="opportunistic"
    elif grep -qiE 'DNSOverTLS setting:[[:space:]]*yes|DNSOverTLS=yes' <<<"$rglobal"; then
        dot_mode="yes"
    elif grep -q '+DNSOverTLS' <<<"$rglobal"          && ! grep -qiE 'DNSOverTLS setting:[[:space:]]*no|-DNSOverTLS' <<<"$rglobal"; then
        dot_mode="yes"
    fi
    if (( resolv_ok == 1 )) && [[ "$dot_mode" == "yes" ]]; then
        ok "DNS-over-TLS estrito ativo no systemd-resolved e /etc/resolv.conf apontando para stub-resolv."
    elif (( resolv_ok == 1 )) && [[ "$dot_mode" == "opportunistic" ]]; then
        warn "DNS-over-TLS em modo opportunistic (esperado na Live ISO; em instalação definitiva use DNSOverTLS=yes)."
    else
        warn "DNS-over-TLS incompleto (verifique resolvectl status e symlink /etc/resolv.conf -> /run/systemd/resolve/stub-resolv.conf)."
    fi
fi

# 8. Snapper
snap_cfgs="$(snapper list-configs 2>/dev/null || true)"
if command -v snapper >/dev/null 2>&1 && grep -q '^root ' <<<"$snap_cfgs"; then
    ok "Configuração Snapper 'root' detectada."
elif [[ -f /etc/snapper/configs/root ]]; then
    ok "Configuração Snapper 'root' presente em /etc/snapper/configs/root (requer sudo/wheel ACL para listar via D-Bus)."
else
    warn "Configuração Snapper 'root' não detectada (rode sudo ./scripts/instalacao/easyarch-configurar-snapper.sh)."
fi

printf '\n============================================================\n'
printf ' RESUMO: OK=%d | AVISOS=%d | FALHAS=%d\n' "$PASS" "$WARN" "$FAIL"
printf '============================================================\n'

if (( FAIL > 0 )); then
    exit 1
fi
exit 0
