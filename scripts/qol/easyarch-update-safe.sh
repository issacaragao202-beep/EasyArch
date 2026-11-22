#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Atualização Segura com Verificação Efetiva de Snapshot Btrfs
# Destino: ~/.local/bin/easyarch-update-safe.sh
#
# Correções v4.4:
#   - Verifica trava /var/lib/pacman/db.lck antes de iniciar.
#   - Autentica `sudo -v` explicitamente antes de consultar Snapper (evita falso
#     negativo silencioso quando a senha do sudo é cancelada ou digitada errada).
#   - Atualiza Flatpaks tanto em escopo `--user` quanto `--system` (se presentes).
# ==============================================================================

set -euo pipefail

get_installed_kernels() {
    pacman -Q linux linux-zen linux-lts linux-hardened 2>/dev/null | sort || true
}

printf '============================================================\n'
printf ' EasyArch v5.4 — ATUALIZAÇÃO SEGURA DO SISTEMA\n'
printf '============================================================\n\n'

if [[ -e /var/lib/pacman/db.lck ]]; then
    printf '[BLOQUEADO] Trava /var/lib/pacman/db.lck detectada (outro pacman em execução ou interrompido).\n' >&2
    exit 1
fi

free_mb="$(df -m --output=avail / | tail -n 1 | tr -d ' ')"
printf '[INFO] Espaço livre na raiz (/): %d MiB\n' "$free_mb"
if (( free_mb < 3072 )); then
    printf '[BLOQUEADO] Menos de 3 GiB livres no SSD. Rode `easyarch limpar` antes de atualizar.\n' >&2
    exit 1
fi

if ! sudo -v; then
    printf '[ERRO] Autenticação sudo cancelada ou inválida. Abortando.\n' >&2
    exit 1
fi

root_fs="$(findmnt -n -o FSTYPE / 2>/dev/null || echo desconhecido)"
snap_ready=0
has_snap_pac=0
if [[ "$root_fs" == "btrfs" ]] && command -v snapper >/dev/null 2>&1 && grep -q '^root ' <<<"$(sudo snapper list-configs 2>/dev/null || true)"; then
    snap_ready=1
    if pacman -Q snap-pac >/dev/null 2>&1; then
        has_snap_pac=1
        printf '[OK]    Snapper Btrfs ("root") + snap-pac ativos (par pre/post automático no pacman).\n'
    else
        printf '[OK]    Snapper Btrfs ("root") ativo (será criado snapshot manual pré-atualização).\n'
    fi
else
    printf '[AVISO] Snapper Btrfs NÃO está configurado/ativo nesta raiz (%s).\n' "$root_fs"
    printf '        Você NÃO terá rollback automático se algo falhar!\n'
    printf '        Para configurar antes, rode: sudo ./scripts/instalacao/easyarch-configurar-snapper.sh\n'
fi

old_kernels="$(get_installed_kernels)"
printf '\nKernel(s) instalado(s):\n%s\n' "${old_kernels:-desconhecido}"
read -r -p "Deseja prosseguir com a atualização (pacman + flatpak)? (s/N): " ans
if [[ "${ans,,}" != "s" && "${ans,,}" != "sim" ]]; then
    printf '[EasyArch] Atualização cancelada.\n'
    exit 0
fi

if (( snap_ready == 1 && has_snap_pac == 0 )); then
    snap_id="$(sudo snapper -c root create --cleanup-algorithm number --print-number --description "EasyArch Pre-Update $(date '+%Y-%m-%d %H:%M')")"
    if [[ -n "$snap_id" ]]; then
        printf '[OK]    Snapshot pré-atualização #%s confirmado.\n' "$snap_id"
    else
        printf '[ERRO]  Falha ao criar snapshot pré-atualização. Abortando por segurança.\n' >&2
        exit 1
    fi
fi

sudo pacman -Syu

if command -v flatpak >/dev/null 2>&1; then
    printf '\n[INFO] Verificando atualizações Flatpak...\n'
    flatpak update --user -y || true
    if [[ -n "$(flatpak list --system 2>/dev/null || true)" ]]; then
        flatpak update --system -y || true
    fi
fi

new_kernels="$(get_installed_kernels)"
if [[ "$old_kernels" != "$new_kernels" ]]; then
    printf '\n[ATENÇÃO] Kernel atualizado. Reinicie o computador para carregar a nova versão.\n'
else
    printf '\n[OK] Atualização concluída.\n'
fi
