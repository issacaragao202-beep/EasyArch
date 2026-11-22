#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Menu Visual de Energia e Sessão (Botão ⏻ na Waybar / SUPER+Backspace)
# Destino: ~/.local/bin/easyarch-power.sh
# ==============================================================================

set -uo pipefail

OPTIONS=(
    "Bloquear Tela (Hyprlock)"
    "Suspender Computador"
    "Reiniciar Computador"
    "Desligar Computador"
    "Encerrar Sessão (Sair do Hyprland)"
)

choose() {
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v rofi >/dev/null 2>&1; then
        printf '%s\n' "${OPTIONS[@]}" | rofi -dmenu -i -no-custom -p "Energia EasyArch"
    else
        printf '=== Energia EasyArch ===\n' >&2
        local i=1 o
        for o in "${OPTIONS[@]}"; do printf '  %d) %s\n' "$i" "$o" >&2; i=$((i+1)); done
        read -r -p "Opção (1-${#OPTIONS[@]}, ou Enter para cancelar): " n
        if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#OPTIONS[@]} )); then
            printf '%s\n' "${OPTIONS[$((n - 1))]}"
        fi
    fi
}

confirm() {
    local msg="$1"
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v rofi >/dev/null 2>&1; then
        [[ "$(printf 'Não\nSim\n' | rofi -dmenu -i -no-custom -p "$msg")" == "Sim" ]]
    else
        read -r -p "${msg} (s/N): " a
        [[ "${a,,}" == "s" || "${a,,}" == "sim" ]]
    fi
}

sel="$(choose)"
[[ -z "$sel" ]] && exit 0

case "$sel" in
    Bloquear*)  command -v hyprlock >/dev/null 2>&1 && hyprlock || printf '[ERRO] hyprlock não instalado.\n' >&2 ;;
    Suspender*) confirm "Suspender agora?" && systemctl suspend ;;
    Reiniciar*) confirm "Reiniciar o computador?" && systemctl reboot ;;
    Desligar*)  confirm "Desligar o computador?" && systemctl poweroff ;;
    Encerrar*)  confirm "Sair da sessão Hyprland?" && { command -v hyprctl >/dev/null 2>&1 && hyprctl dispatch exit || printf '[ERRO] hyprctl indisponível.\n' >&2; } ;;
esac
