# Evolução Visual e Usabilidade — EasyArch v5.0 (Glacial HUD)

> **Escopo:** Transformação visual e ergonômica sem alterar a camada crítica já validada (kernel, nftables, snapper, zram e earlyoom).

## Novidades da v5.0
1. **Cápsula Central Translúcida ao tocar `Super`:** `bindr = SUPER, SUPER_L` (além de `SUPER + Space`) abre o Rofi no centro da tela com bordas de 28 px, barra de pesquisa em pílula (`999px`), vidro translúcido e ícones maiores (`28px`).
2. **Vidro Fosco Real (1 passagem leve na Vega 11) + `layerrule` 0.53+:** `blur` otimizado (`passes = 1`, `size = 4`, `xray = true`) aplicado sobre `rofi`, `waybar` e `notifications` via sintaxe de bloco do Hyprland 0.53+; desligado automaticamente pelo Modo Ultra-Leve (`SUPER + Shift + L`).
3. **Waybar em Ilhas Flutuantes Translúcidas:** módulos em pílulas de vidro flutuantes no topo com clique direito no volume para `pavucontrol`, clique na RAM para relatório instantâneo e clique na segurança para diagnóstico detalhado.
4. **Navegação Fluida (`Alt + Tab` + animações HUD):** curva `hudOut` com `popin 84%` e `slidefade 15%`, mais `Alt + Tab` / `Alt + Shift + Tab`.
5. **Central `SUPER + H` Completa e Lockscreen/Wallpaper HUD:** Loja de Apps, Wi-Fi e Limpeza de Cache direto no topo do menu `SUPER + H`; campo de senha em cápsula (`rounding = -1`) no `hyprlock` e wallpaper SVG vetorial com anéis HUD concêntricos.
