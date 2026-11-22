#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Guia Rápido de Atalhos para Iniciantes (SUPER + F1)
# Destino: ~/.local/bin/easyarch-cheatsheet.sh
# ==============================================================================

set -uo pipefail

SHORTCUTS=(
    "SUPER (toque) / +Space| Abrir Cápsula Central Translúcida (Apps, Arquivos, Cmd)"
    "Alt + Tab             | Alternar rapidamente entre janelas abertas"
    "SUPER + Z             | Modo Hyperfocus / Zen (oculta barra/dock/bordas)"
    "SUPER + S / Shift + S | Camada HUD flutuante (scratchpad sobre qualquer app)"
    "SUPER + C             | Calculadora HUD instantânea (copia resultado)"
    "SUPER + N             | Central de Notificações e Controles (SwayNC)"
    "SUPER + Esc           | Monitor futurista de sistema em tempo real (btop)"
    "SUPER + Shift + T     | Trocar paleta HUD ao vivo (glacial / amber / emerald)"
    "SUPER + G / + Tab     | Agrupar janelas em abas futuristas (zero RAM extra)"
    "SUPER + Scroll / + 0  | Zoom dinâmico na tela (e reset com SUPER + 0)"
    "SUPER + Enter         | Abrir Terminal Inteligente (Foot + Fish)"
    "SUPER + E             | Abrir Gerenciador de Arquivos (Thunar)"
    "SUPER + H             | Abrir Central QoL do EasyArch (Menu Fácil)"
    "SUPER + F1            | Mostrar esta cola rápida de atalhos"
    "SUPER + L             | Bloquear tela (Hyprlock Glacial Silver)"
    "SUPER + Shift + L     | Alternar Modo Ultra-Leve (pausa dock/animações)"
    "SUPER + Shift + V     | Histórico da Área de Transferência (Ctrl+C)"
    "SUPER + M / BackSpace | Menu de Energia (Bloquear/Suspender/Desligar)"
    "SUPER + Q             | Fechar janela atual"
    "SUPER + F             | Tela cheia (Fullscreen)"
    "SUPER + V             | Alternar janela flutuante / ladrilhada"
    "SUPER + 1..6          | Trocar de área de trabalho (Workspace 1 a 6)"
    "SUPER + Shift + 1..6  | Mover janela atual para o Workspace 1 a 6"
    "SUPER + Setas         | Mudar foco entre janelas"
    "SUPER + Shift + M     | Captura rápida de memória / benchmark"
    "SUPER + Shift + P     | Ver perfil de desempenho atual"
    "Print                 | Capturar área da tela para área de transferência"
    "Ctrl + R (no Terminal)| Buscar comando antigo interativamente (FZF)"
    "ajuda <cmd> (Terminal)| Ver exemplos práticos do comando (Tealdeer)"
    "easyarch-ai explicar ... | Explicar comando e verificar se é seguro ou destrutivo"
    "Ctrl + Alt + F3       | Emergência: abrir terminal texto fora do Hyprland"
)

if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v rofi >/dev/null 2>&1; then
    printf '%s\n' "${SHORTCUTS[@]}" | rofi -dmenu -i -no-custom -p "Atalhos EasyArch" >/dev/null
else
    printf '=== ATALHOS ESSENCIAIS — EasyArch v5.4 ===\n'
    printf '  %s\n' "${SHORTCUTS[@]}"
fi
