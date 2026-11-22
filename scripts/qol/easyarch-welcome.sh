#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Boas-Vindas do Primeiro Login (Executa 1x sem incomodar)
# Destino: ~/.local/bin/easyarch-welcome.sh
# ==============================================================================

set -uo pipefail

FLAG="${HOME}/.local/state/easyarch-welcome-done"
mkdir -p "$(dirname "$FLAG")"

if [[ "${1:-}" != "--force" && -f "$FLAG" ]]; then
    exit 0
fi

cat <<'EOF'
========================================================================
          BEM-VINDO AO EasyArch v5.4 — GLACIAL SILVER
   Ryzen 5 3400G · Vega 11 · ~6 GB RAM Úteis · Segurança em Camadas
========================================================================

 5 ATALHOS QUE RESOLVEM 90% DO DIA A DIA (SEM DECORAR ARCH):
   • SUPER (toque)  -> Cápsula Central Translúcida (Apps, Arquivos, Comandos)
   • SUPER + H      -> Central EasyArch (Loja 1 Clique, Wi-Fi, Atualizar, RAM)
   • Alt + Tab      -> Alternar janelas  |  SUPER + E -> Arquivos  |  SUPER + Q -> Fechar
   • SUPER + F1     -> Cola rápida de todos os atalhos na tela
   • SUPER + L      -> Bloquear tela (Hyprlock Glacial HUD)

 DICAS DE OURO PARA 6 GB DE RAM:
   • Use SUPER + H -> Modo Ultra-Leve antes de jogar ou compilar ArcForge.
   • Feche apps Android (Waydroid) quando terminar: o container fecha sozinho.
   • Use `ajuda <comando>` no terminal para ver exemplos práticos curtos.
   • Em caso de emergência, rode `easyarch sos` para o guia de recuperação.

========================================================================
EOF

touch "$FLAG"
if [[ "${1:-}" == "--interactive" ]]; then
    read -n 1 -r -p "Pressione qualquer tecla para começar a usar o EasyArch..."
fi
