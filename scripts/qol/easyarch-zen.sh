#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Modo Hyperfocus / Zen (SUPER + Z · Zero RAM Residente)
# Destino: ~/.local/bin/easyarch-zen.sh
# Esconde Waybar, Dock e zera bordas/gaps para foco total; segundo toque restaura.
# ==============================================================================

set -euo pipefail

STATE_FILE="${HOME}/.local/state/easyarch-zen-mode"
LITE_STATE_FILE="${HOME}/.local/state/easyarch-lite-mode"
mkdir -p "$(dirname -- "$STATE_FILE")"

mode="${1:-toggle}"

zen_on() {
    pkill -u "$(id -u)" -x waybar 2>/dev/null || true
    pkill -u "$(id -u)" -f '(^|/)nwg-dock-hyprland([[:space:]]|$)' 2>/dev/null || true
    if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors >/dev/null 2>&1; then
        hyprctl --batch "keyword general:gaps_in 0; keyword general:gaps_out 0; keyword general:border_size 1; keyword decoration:rounding 0" >/dev/null 2>&1 || true
    fi
    printf 'on\n' > "$STATE_FILE"
    [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v notify-send >/dev/null 2>&1 && notify-send "EasyArch Zen" "Modo Hyperfocus ATIVADO (SUPER + Z para restaurar)." || true
    printf '[OK] Modo Zen ATIVADO.\n'
}

zen_off() {
    if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors >/dev/null 2>&1; then
        hyprctl --batch "keyword general:gaps_in 4; keyword general:gaps_out 8; keyword general:border_size 2; keyword decoration:rounding 14" >/dev/null 2>&1 || true
    fi
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        if ! pgrep -u "$(id -u)" -x waybar >/dev/null 2>&1 && command -v waybar >/dev/null 2>&1; then
            nohup waybar >/dev/null 2>&1 </dev/null &
        fi
        local lite_cur
        lite_cur="$(cat "$LITE_STATE_FILE" 2>/dev/null || echo off)"
        if [[ "$lite_cur" != "on" ]] && ! pgrep -u "$(id -u)" -f '(^|/)nwg-dock-hyprland([[:space:]]|$)' >/dev/null 2>&1 && command -v nwg-dock-hyprland >/dev/null 2>&1; then
            nohup nwg-dock-hyprland -d -i 36 -mb 8 -c "$HOME/.local/bin/easyarch-launcher.sh" >/dev/null 2>&1 </dev/null &
        fi
    fi
    printf 'off\n' > "$STATE_FILE"
    [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v notify-send >/dev/null 2>&1 && notify-send "EasyArch Zen" "Modo Hyperfocus DESATIVADO." || true
    printf '[OK] Modo Zen DESATIVADO.\n'
}

case "$mode" in
    on)  zen_on ;;
    off) zen_off ;;
    status)
        printf 'Modo Zen: %s\n' "$(cat "$STATE_FILE" 2>/dev/null || echo off)"
        ;;
    toggle)
        cur="$(cat "$STATE_FILE" 2>/dev/null || echo off)"
        if [[ "$cur" == "on" ]]; then zen_off; else zen_on; fi
        ;;
    *)
        printf 'Uso: easyarch-zen.sh {on|off|toggle|status}\n' >&2
        exit 1
        ;;
esac
