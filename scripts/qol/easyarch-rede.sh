#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Seletor Fácil de Rede Wi-Fi (Clique na Waybar ou `easyarch wifi`)
# Destino: ~/.local/bin/easyarch-rede.sh
# ==============================================================================

set -uo pipefail

if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v nmtui >/dev/null 2>&1; then
    if command -v footclient >/dev/null 2>&1 && pgrep -u "$(id -u)" -f '(^|/)foot([[:space:]]|$).*--server' >/dev/null 2>&1; then
        exec footclient --title="EasyArch — Conectar Rede / Wi-Fi" -e nmtui
    elif command -v foot >/dev/null 2>&1; then
        exec foot --title="EasyArch — Conectar Rede / Wi-Fi" -e nmtui
    else
        exec nmtui
    fi
elif command -v nmtui >/dev/null 2>&1; then
    exec nmtui
else
    printf '[EasyArch] Instale networkmanager (nmtui) para gerenciar redes facilmente.\n'
    nmcli device status 2>/dev/null || true
fi
