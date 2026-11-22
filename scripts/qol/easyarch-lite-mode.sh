#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Modo Ultra-Leve Sob Demanda (`easyarch-lite-mode.sh`)
# Destino: ~/.local/bin/easyarch-lite-mode.sh
#
# Correções v4.5:
#   - Corrige limite de 15 bytes de /proc/<pid>/comm para `nwg-dock-hyprland`
#     (17 chars) usando `pkill/pgrep -u "$(id -u)" -f`.
#   - Respeita `~/.local/state/easyarch-profile` (se `jogos`, mantém animações
#     desligadas ao sair do Modo Ultra-Leve).
# ==============================================================================

set -euo pipefail

STATE_FILE="${HOME}/.local/state/easyarch-lite-mode"
PROFILE_STATE_FILE="${HOME}/.local/state/easyarch-profile"
mkdir -p "$(dirname "$STATE_FILE")"

mode="${1:-toggle}"

dock_running() {
    pgrep -u "$(id -u)" -f '(^|/)nwg-dock-hyprland([[:space:]]|$)' >/dev/null 2>&1
}

enable_lite() {
    pkill -u "$(id -u)" -f '(^|/)nwg-dock-hyprland([[:space:]]|$)' 2>/dev/null || true
    if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors >/dev/null 2>&1; then
        hyprctl keyword animations:enabled 0 >/dev/null 2>&1 || true
        hyprctl keyword decoration:blur:enabled 0 >/dev/null 2>&1 || true
        hyprctl keyword decoration:inactive_opacity 1.0 >/dev/null 2>&1 || true
    fi
    printf 'on\n' > "$STATE_FILE"
    [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v notify-send >/dev/null 2>&1 && notify-send "EasyArch" "Modo Ultra-Leve ATIVADO (dock e animações pausados para liberar RAM)." || true
    printf '[OK] Modo Ultra-Leve ATIVADO.\n'
}

disable_lite() {
    local cur_profile
    cur_profile="$(cat "$PROFILE_STATE_FILE" 2>/dev/null || echo equilibrado)"
    if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors >/dev/null 2>&1; then
        if [[ "$cur_profile" == "jogos" ]]; then
            printf '[INFO] Perfil "jogos" ativo: animações mantidas desligadas.\n'
        else
            hyprctl keyword animations:enabled 1 >/dev/null 2>&1 || true
            hyprctl keyword decoration:blur:enabled 1 >/dev/null 2>&1 || true
        fi
        hyprctl keyword decoration:inactive_opacity 0.95 >/dev/null 2>&1 || true
    fi
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && ! dock_running && command -v nwg-dock-hyprland >/dev/null 2>&1; then
        nohup nwg-dock-hyprland -d -i 36 -mb 8 -c "$HOME/.local/bin/easyarch-launcher.sh" >/dev/null 2>&1 </dev/null &
    fi
    printf 'off\n' > "$STATE_FILE"
    [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v notify-send >/dev/null 2>&1 && notify-send "EasyArch" "Modo Ultra-Leve DESATIVADO (visual Glacial Silver restaurado)." || true
    printf '[OK] Modo Ultra-Leve DESATIVADO.\n'
}

case "$mode" in
    on)  enable_lite ;;
    off) disable_lite ;;
    status)
        printf 'Modo Ultra-Leve: %s\n' "$(cat "$STATE_FILE" 2>/dev/null || echo off)"
        ;;
    toggle)
        cur="$(cat "$STATE_FILE" 2>/dev/null || echo off)"
        if [[ "$cur" == "on" ]]; then disable_lite; else enable_lite; fi
        ;;
    *)
        printf 'Uso: easyarch-lite-mode.sh {on|off|toggle|status}\n' >&2
        exit 1
        ;;
esac
