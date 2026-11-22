#!/usr/bin/env bash
# ==============================================================================
# EasyArch — Lançador Unificado estilo Spotlight (Sem Indexador Residente)
# Destino: ~/.local/bin/easyarch-launcher.sh
#
# Modos:
#   - drun: aplicativos Linux nativos, Flatpak, Windows registrados e Android (.desktop)
#   - run: comandos diretos
#   - filebrowser: navegação rápida de pastas e arquivos sob demanda
# ==============================================================================

set -euo pipefail

if pgrep -x rofi >/dev/null 2>&1; then
    pkill -x rofi
    exit 0
fi

exec rofi -show drun -modi "drun,run,filebrowser"
