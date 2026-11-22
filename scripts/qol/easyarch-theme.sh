#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Seletor Instantâneo de Paleta HUD (SUPER + Shift + T)
# Destino: ~/.local/bin/easyarch-theme.sh
# Alterna ao vivo: glacial (ciano) | amber (âmbar) | emerald (esmeralda)
# ==============================================================================

set -euo pipefail

STATE_FILE="${HOME}/.local/state/easyarch-theme"
mkdir -p "$(dirname -- "$STATE_FILE")"

apply_theme() {
    local name="$1" hex="$2" hex_rgb="$3"
    local wall_svg="${HOME}/.local/share/easyarch/wallpapers/glacial-silver-1080p.svg"
    local rofi_cfg="${HOME}/.config/rofi/glacial-silver.rasi"
    local wb_css="${HOME}/.config/waybar/style.css"
    local nc_css="${HOME}/.config/swaync/style.css"
    local osd_css="${HOME}/.config/swayosd/style.css"

    if [[ -f "$rofi_cfg" ]]; then
        sed -i -E "s/accent:[[:space:]]*#[0-9a-fA-F]{6};/accent:      #${hex};/" "$rofi_cfg"
        sed -i -E "s/accent-soft:[[:space:]]*#[0-9a-fA-F]{8};/accent-soft: #${hex}26;/" "$rofi_cfg"
        sed -i -E "s/border-col:[[:space:]]*#[0-9a-fA-F]{8};/border-col:  #${hex}4d;/" "$rofi_cfg"
    fi
    local css_f
    for css_f in "$wb_css" "$nc_css" "$osd_css"; do
        if [[ -f "$css_f" ]]; then
            sed -i -E "s/rgba\((125, 211, 252|245, 158, 11|52, 211, 153),/rgba(${hex_rgb},/g" "$css_f"
            sed -i -E "s/#(7dd3fc|f59e0b|34d399)/#${hex}/g" "$css_f"
        fi
    done
    if [[ -f "$wall_svg" ]]; then
        sed -i -E "s/#(7DD3FC|F59E0B|34D399)/#${hex^^}/g" "$wall_svg"
    fi

    if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors >/dev/null 2>&1; then
        hyprctl keyword general:col.active_border "rgba(${hex}ee) rgba(c9d4e0cc) 45deg" >/dev/null 2>&1 || true
    fi
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        pkill -u "$(id -u)" -SIGUSR2 waybar 2>/dev/null || true
        command -v swaync-client >/dev/null 2>&1 && swaync-client --reload-css >/dev/null 2>&1 || true
        if [[ -f "$wall_svg" ]] && command -v swaybg >/dev/null 2>&1; then
            pkill -u "$(id -u)" -x swaybg 2>/dev/null || true
            nohup swaybg -i "$wall_svg" -m fill >/dev/null 2>&1 </dev/null &
        fi
    fi

    printf '%s\n' "$name" > "$STATE_FILE"
    [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v notify-send >/dev/null 2>&1 && notify-send "EasyArch HUD" "Paleta ativa: ${name}" || true
    printf '[OK] Paleta HUD aplicada: %s (#%s)\n' "$name" "$hex"
}

choice="${1:-}"
if [[ -z "$choice" ]]; then
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v rofi >/dev/null 2>&1; then
        choice="$(printf 'glacial\namber\nemerald\n' | rofi -dmenu -i -no-custom -p "Tema HUD")"
    else
        printf 'Paleta atual: %s\nUso: easyarch-theme.sh {glacial|amber|emerald|status}\n' "$(cat "$STATE_FILE" 2>/dev/null || echo glacial)"
        exit 0
    fi
fi
[[ -z "$choice" ]] && exit 0

case "$choice" in
    glacial) apply_theme "glacial" "7dd3fc" "125, 211, 252" ;;
    amber)   apply_theme "amber"   "f59e0b" "245, 158, 11" ;;
    emerald) apply_theme "emerald" "34d399" "52, 211, 153" ;;
    status)  printf 'Paleta HUD: %s\n' "$(cat "$STATE_FILE" 2>/dev/null || echo glacial)" ;;
    -h|--help) printf 'Uso: easyarch-theme.sh {glacial|amber|emerald|status}\n' ;;
    *) printf '[ERRO] Paleta desconhecida: %s (use: glacial, amber ou emerald)\n' "$choice" >&2; exit 1 ;;
esac
