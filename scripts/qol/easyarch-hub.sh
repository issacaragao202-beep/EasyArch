#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Central QoL para Iniciantes (`easyarch-hub`)
# Destino: ~/.local/bin/easyarch-hub.sh (Atalho no Hyprland: SUPER + H)
# ==============================================================================

set -uo pipefail

BIN_DIR="${HOME}/.local/bin"

notify_missing() {
    local bin_name="$1"
    local fase_hint="$2"
    local msg="Recurso '${bin_name}' ainda não instalado. Rode easyarch-setup.sh e marque: ${fase_hint}"
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v notify-send >/dev/null 2>&1; then
        notify-send "EasyArch" "$msg" || true
    fi
    printf '[EasyArch] %s\n' "$msg" >&2
}

require_bin() {
    local bin_name="$1"
    local fase_hint="$2"
    if [[ ! -x "${BIN_DIR}/${bin_name}" ]]; then
        notify_missing "$bin_name" "$fase_hint"
        return 1
    fi
    return 0
}

pick_foot() {
    if command -v footclient >/dev/null 2>&1 && pgrep -u "$(id -u)" -f '(^|/)foot([[:space:]]|$).*--server' >/dev/null 2>&1; then
        printf 'footclient'
    elif command -v foot >/dev/null 2>&1; then
        printf 'foot'
    else
        printf ''
    fi
}

run_in_term() {
    local title="$1"
    local cmd="$2"
    local term=""
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        term="$(pick_foot)"
    fi
    if [[ -n "$term" ]]; then
        "$term" --title="EasyArch — ${title}" -e bash -lc "${cmd}; echo ''; read -n 1 -r -p 'Pressione qualquer tecla para fechar...'"
    else
        bash -lc "$cmd"
    fi
}

MENU_ITEMS=(
    "1. Loja de Apps em 1 Clique (Instalar Programas)"
    "2. Conectar Wi-Fi e Redes (nmtui)"
    "3. Atualizar o Sistema com Segurança (Snapshot + Pacman + Flatpak)"
    "4. Alternar Modo Ultra-Leve (Pausar Vidro/Dock/Animações p/ Jogos)"
    "5. Ver Uso Real de Memória e ZRAM"
    "6. Trocar Perfil de Desempenho (Econômico / Equilibrado / Jogos / Dev)"
    "7. Verificar Camadas de Segurança (AppArmor, Firewall, DoT)"
    "8. Limpar Cache e Liberar Espaço no SSD"
    "9. Gerenciar Android (Waydroid Sob Demanda)"
    "10. Ativar Ambiente ArcForge (Java 17 / Minecraft 1.20.1)"
    "11. Integrar Smartphone via USB (ADB / scrcpy)"
    "12. Rodar Manutenção Segura e Ver Snapshots"
    "13. Ver Atalhos do Teclado (Guia Rápido)"
    "14. Bloquear Tela (Hyprlock Glacial HUD)"
    "15. Modo SOS — Como Recuperar se Algo Quebrar"
)

choose_option() {
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v rofi >/dev/null 2>&1; then
        printf '%s\n' "${MENU_ITEMS[@]}" | rofi -dmenu -i -no-custom -p "EasyArch v5.4"
    else
        printf '=== EasyArch v5.4 — CENTRAL QoL ===\n' >&2
        local i
        for i in "${MENU_ITEMS[@]}"; do printf '  %s\n' "$i" >&2; done
        read -r -p "Digite o número da opção (1-${#MENU_ITEMS[@]}, ou Enter para sair): " num
        if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#MENU_ITEMS[@]} )); then
            printf '%s\n' "${MENU_ITEMS[$((num - 1))]}"
        fi
    fi
}

choice="$(choose_option)"
[[ -z "$choice" ]] && exit 0

case "$choice" in
    1.*)  require_bin "easyarch-loja.sh" "Etapa 1/4 (Desktop)" && "${BIN_DIR}/easyarch-loja.sh" ;;
    2.*)  require_bin "easyarch-rede.sh" "Etapa 1/4 (Desktop)" && "${BIN_DIR}/easyarch-rede.sh" ;;
    3.*)  require_bin "easyarch-update-safe.sh" "Etapa 1/4 (Desktop)" && run_in_term "Atualização Segura" '$HOME/.local/bin/easyarch-update-safe.sh' ;;
    4.*)  require_bin "easyarch-lite-mode.sh" "Etapa 1/4 (Desktop)" && "${BIN_DIR}/easyarch-lite-mode.sh" toggle ;;
    5.*)  require_bin "01-relatorio-memoria.sh" "Etapa 1/4" && run_in_term "Memória e ZRAM" '$HOME/.local/bin/01-relatorio-memoria.sh --show painel-qol' ;;
    6.*)
        require_bin "easyarch-profile.sh" "Etapa 3/4 (Dev/Perfis)" || exit 1
        if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v rofi >/dev/null 2>&1; then
            prof="$(printf 'equilibrado\neconomico\njogos\ndev\nstatus\n' | rofi -dmenu -i -no-custom -p "Escolha o Perfil")"
            [[ -n "$prof" ]] && run_in_term "Perfil ${prof}" "\$HOME/.local/bin/easyarch-profile.sh $(printf '%q' "$prof")"
        else
            run_in_term "Perfis" '$HOME/.local/bin/easyarch-profile.sh status'
        fi
        ;;
    7.*)  require_bin "security-status.sh" "Etapa 1/4" && require_bin "02-validar-fase1.sh" "Etapa 1/4" && run_in_term "Segurança" '$HOME/.local/bin/security-status.sh --human; echo ""; $HOME/.local/bin/02-validar-fase1.sh || true' ;;
    8.*)  require_bin "easyarch" "Etapa 1/4 (Desktop)" && run_in_term "Limpeza de Cache" '$HOME/.local/bin/easyarch limpar' ;;
    9.*)
        require_bin "easyarch-waydroid.sh" "Etapa 2/4 (Híbrido)" || exit 1
        if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v rofi >/dev/null 2>&1; then
            wact="$(printf 'status\nstart\nstop\n' | rofi -dmenu -i -no-custom -p "Waydroid (Android)")"
            [[ -n "$wact" ]] && run_in_term "Waydroid" "\$HOME/.local/bin/easyarch-waydroid.sh $(printf '%q' "$wact")"
        else
            run_in_term "Waydroid" '$HOME/.local/bin/easyarch-waydroid.sh status'
        fi
        ;;
    10.*)
        require_bin "easyarch-arcforge-env.sh" "Etapa 3/4 (Dev)" || exit 1
        run_in_term "ArcForge Java 17" 'source $HOME/.local/bin/easyarch-arcforge-env.sh && if command -v fish >/dev/null 2>&1; then exec fish; else exec bash; fi'
        ;;
    11.*)
        require_bin "easyarch-phone.sh" "Etapa 3/4 (Dev/Mobile)" || exit 1
        if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v rofi >/dev/null 2>&1; then
            pact="$(printf 'status\nmirror\n' | rofi -dmenu -i -no-custom -p "Smartphone USB")"
            [[ -n "$pact" ]] && run_in_term "Smartphone" "\$HOME/.local/bin/easyarch-phone.sh $(printf '%q' "$pact")"
        else
            run_in_term "Smartphone" '$HOME/.local/bin/easyarch-phone.sh status'
        fi
        ;;
    12.*) require_bin "02-manutencao-rotina.sh" "Etapa 3/4 (Dev/Manutenção)" && run_in_term "Manutenção" '$HOME/.local/bin/02-manutencao-rotina.sh' ;;
    13.*) require_bin "easyarch-cheatsheet.sh" "Etapa 1/4 (Desktop)" && "${BIN_DIR}/easyarch-cheatsheet.sh" ;;
    14.*)
        if command -v hyprlock >/dev/null 2>&1; then
            hyprlock
        else
            notify_missing "hyprlock" "Etapa 1/4 (Desktop)"
        fi
        ;;
    15.*) require_bin "easyarch-sos.sh" "Etapa 1/4 (Desktop)" && run_in_term "SOS — Recuperação" '$HOME/.local/bin/easyarch-sos.sh' ;;
esac
