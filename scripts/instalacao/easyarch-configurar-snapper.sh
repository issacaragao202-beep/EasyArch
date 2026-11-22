#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Configurador Real do Snapper em Btrfs (Compatível com @snapshots)
# Destino: scripts/instalacao/easyarch-configurar-snapper.sh
#
# Correções v4.5:
#   - Valida montagem de /.snapshots via /etc/fstab ANTES de deletar qualquer
#     subvolume aninhado (evita estado irrecuperável em erro de fstab/UUID).
#   - Garante montagem de @snapshots mesmo quando a config "root" já existe.
#   - Aplica ACL de leitura para o grupo `wheel` em /.snapshots via `setfacl`
#     mesmo em ambiente `arch-chroot` (sem D-Bus ativo).
# ==============================================================================

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    printf '[ERRO] Execute com sudo: sudo %s\n' "$0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

root_fs="$(findmnt -n -o FSTYPE / 2>/dev/null || echo desconhecido)"
if [[ "$root_fs" != "btrfs" ]]; then
    printf '[ERRO] A raiz (/) usa "%s", não Btrfs. Snapper Btrfs não pode ser configurado.\n' "$root_fs" >&2
    exit 1
fi

if ! command -v snapper >/dev/null 2>&1; then
    printf '[ERRO] Pacote "snapper" não instalado. Instale com: sudo pacman -S snapper snap-pac\n' >&2
    exit 1
fi

IS_LIVE_SYSTEMD=0
if [[ -d /run/systemd/system ]] && ! systemd-detect-virt --chroot >/dev/null 2>&1; then
    IS_LIVE_SYSTEMD=1
fi

SNAPPER_CMD=(snapper)
if (( IS_LIVE_SYSTEMD == 0 )); then
    SNAPPER_CMD=(snapper --no-dbus)
    printf '[INFO] Ambiente chroot/sem systemd detectado: usando `snapper --no-dbus`.\n'
fi

has_flat_snapshots_fstab=0
if [[ -r /etc/fstab ]] && grep -qE '^[[:space:]]*[^#[:space:]].*[[:space:]]/\.snapshots([[:space:]]|$)' /etc/fstab; then
    has_flat_snapshots_fstab=1
fi

snap_cfgs="$("${SNAPPER_CMD[@]}" list-configs 2>/dev/null || true)"
if ! grep -q '^root ' <<<"$snap_cfgs"; then
    if (( has_flat_snapshots_fstab == 1 )); then
        printf '[EasyArch] Detectado layout plano @snapshots em /etc/fstab (ArchWiki).\n'
        # Valida previamente se /etc/fstab consegue montar /.snapshots antes de criar/deletar
        if ! mountpoint -q /.snapshots 2>/dev/null; then
            mkdir -p /.snapshots
            if ! mount /.snapshots; then
                printf '[ERRO] Falha ao testar montagem de /.snapshots via /etc/fstab. Corrija o fstab antes de prosseguir.\n' >&2
                exit 1
            fi
        fi
        umount /.snapshots
        if [[ -d /.snapshots ]]; then
            if ! rmdir /.snapshots 2>/dev/null; then
                printf '[ERRO] /.snapshots não está vazio após desmontar. Revise manualmente antes de prosseguir.\n' >&2
                exit 1
            fi
        fi
        "${SNAPPER_CMD[@]}" -c root create-config /
        btrfs subvolume delete /.snapshots
        mkdir -p /.snapshots
        mount /.snapshots
        chmod 750 /.snapshots
        printf '[OK] Configuração Snapper "root" vinculada ao subvolume plano @snapshots.\n'
    elif mountpoint -q /.snapshots 2>/dev/null; then
        printf '[ERRO] /.snapshots está montado manualmente, mas NÃO consta no /etc/fstab.\n' >&2
        printf '       Adicione a entrada de @snapshots ao /etc/fstab antes de rodar este script.\n' >&2
        exit 1
    else
        printf '[EasyArch] Criando configuração Snapper "root" em / (subvolume aninhado)...\n'
        "${SNAPPER_CMD[@]}" -c root create-config /
        printf '[AVISO] /.snapshots não está no /etc/fstab como subvolume plano (@snapshots).\n'
        printf '        No rollback via Live ISO, os snapshots estarão dentro de /@/.snapshots.\n'
    fi
else
    printf '[INFO] Configuração Snapper "root" já existe.\n'
    if (( has_flat_snapshots_fstab == 1 )) && ! mountpoint -q /.snapshots 2>/dev/null; then
        printf '[INFO] /.snapshots consta no /etc/fstab mas estava desmontado; montando agora...\n'
        mkdir -p /.snapshots
        mount /.snapshots
        chmod 750 /.snapshots
    fi
fi

if [[ -f "${ROOT_DIR}/etc/snapper/configs/root.template" ]]; then
    snap_bk="/root/easyarch-snapper-backup-$(date '+%Y%m%d-%H%M%S')"
    mkdir -p "$snap_bk"
    cp -a /etc/snapper/configs/root "${snap_bk}/root"
    install -m 0640 "${ROOT_DIR}/etc/snapper/configs/root.template" /etc/snapper/configs/root
    if (( IS_LIVE_SYSTEMD == 1 )); then
        "${SNAPPER_CMD[@]}" -c root set-config SYNC_ACL=yes >/dev/null 2>&1 || true
    elif command -v setfacl >/dev/null 2>&1 && [[ -d /.snapshots ]]; then
        setfacl -m g:wheel:rx /.snapshots 2>/dev/null || true
    fi
    printf '[OK] Política de retenção EasyArch (SSD 240 GB + ACL wheel) aplicada em /etc/snapper/configs/root.\n'
fi

if (( IS_LIVE_SYSTEMD == 1 )); then
    systemctl enable --now snapper-cleanup.timer
else
    systemctl enable snapper-cleanup.timer
fi

printf '[EasyArch] Criando snapshot inicial de validação...\n'
snap_id="$("${SNAPPER_CMD[@]}" -c root create --cleanup-algorithm number --print-number --description "EasyArch Baseline Inicial")"
snap_list="$("${SNAPPER_CMD[@]}" --csvout -c root list --columns number 2>/dev/null || true)"
snap_nums="$(printf '%s
' "$snap_list" | tail -n +2 | tr -d ' *+-')"
if [[ -n "$snap_id" ]] && grep -qx "$snap_id" <<<"$snap_nums"; then
    printf '[SUCESSO] Snapshot #%s criado e confirmado em `snapper -c root list`.\n' "$snap_id"
else
    printf '[FALHA] Não foi possível confirmar a criação do snapshot no Snapper.\n' >&2
    exit 1
fi
