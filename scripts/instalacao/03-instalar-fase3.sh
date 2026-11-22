#!/usr/bin/env bash
# ==============================================================================
# EasyArch — Instalador Não Destrutivo de Integrações da Fase 3 (Usuário)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

mkdir -p "${HOME}/.local/bin" \
         "${HOME}/.local/share/applications" \
         "${HOME}/.local/share/easyarch/wine-prefixes" \
         "${HOME}/.local/share/easyarch/appimage-homes"

install -m 0755 "${ROOT_DIR}/scripts/windows/easyarch-win-run.sh" "${HOME}/.local/bin/easyarch-win-run.sh"
install -m 0755 "${ROOT_DIR}/scripts/windows/easyarch-ntsync-check.sh" "${HOME}/.local/bin/easyarch-ntsync-check.sh"
install -m 0755 "${ROOT_DIR}/scripts/android/easyarch-waydroid.sh" "${HOME}/.local/bin/easyarch-waydroid.sh"
install -m 0755 "${ROOT_DIR}/scripts/sandbox/easyarch-appimage-sandbox.sh" "${HOME}/.local/bin/easyarch-appimage-sandbox.sh"
install -m 0755 "${ROOT_DIR}/scripts/diagnostico/04-validar-fase3.sh" "${HOME}/.local/bin/04-validar-fase3.sh"
install -m 0644 "${ROOT_DIR}/config/applications/easyarch-windows-safe.desktop" "${HOME}/.local/share/applications/easyarch-windows-safe.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true
fi

printf '[EasyArch] Integrações de usuário da Fase 3 instaladas com sucesso.\n'
if [[ ! -f /etc/nftables.d/20-waydroid.nft ]]; then
    printf '[EasyArch] Lembrete: rode sudo ./scripts/instalacao/easyarch-aplicar-etc.sh para instalar /etc/nftables.d/20-waydroid.nft.\n'
fi
