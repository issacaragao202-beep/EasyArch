#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Gerador de Wallpaper Glacial HUD (1920x1080 SVG Vetorial)
# Destino: ~/.local/bin/easyarch-wallpaper-glacial.sh
# ==============================================================================

set -euo pipefail

OUT_DIR="${HOME}/.local/share/easyarch/wallpapers"
mkdir -p "$OUT_DIR"
SVG_FILE="${OUT_DIR}/glacial-silver-1080p.svg"

cat > "$SVG_FILE" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#05080D"/>
      <stop offset="50%" stop-color="#0A111B"/>
      <stop offset="100%" stop-color="#0F1926"/>
    </linearGradient>
    <radialGradient id="core" cx="50%" cy="50%" r="42%">
      <stop offset="0%" stop-color="#7DD3FC" stop-opacity="0.16"/>
      <stop offset="55%" stop-color="#38BDF8" stop-opacity="0.05"/>
      <stop offset="100%" stop-color="#05080D" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="accent2" cx="80%" cy="20%" r="35%">
      <stop offset="0%" stop-color="#A5F3FC" stop-opacity="0.10"/>
      <stop offset="100%" stop-color="#05080D" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="arc" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#C9D4E0" stop-opacity="0.02"/>
      <stop offset="50%" stop-color="#7DD3FC" stop-opacity="0.28"/>
      <stop offset="100%" stop-color="#EDF4FA" stop-opacity="0.02"/>
    </linearGradient>
  </defs>
  <rect width="1920" height="1080" fill="url(#bg)"/>
  <rect width="1920" height="1080" fill="url(#core)"/>
  <rect width="1920" height="1080" fill="url(#accent2)"/>
  <circle cx="960" cy="540" r="190" fill="none" stroke="#7DD3FC" stroke-opacity="0.14" stroke-width="1.2"/>
  <circle cx="960" cy="540" r="300" fill="none" stroke="#C9D4E0" stroke-opacity="0.09" stroke-width="1" stroke-dasharray="10 14"/>
  <circle cx="960" cy="540" r="430" fill="none" stroke="#7DD3FC" stroke-opacity="0.07" stroke-width="1"/>
  <path d="M-100,760 C420,560 980,880 2020,420" fill="none" stroke="url(#arc)" stroke-width="1.8"/>
  <path d="M-100,820 C480,620 1060,920 2020,490" fill="none" stroke="url(#arc)" stroke-width="1"/>
</svg>
EOF

printf '[OK] Wallpaper Glacial HUD criado em: %s\n' "$SVG_FILE"
