# Central HUD, OSD Translúcido e Monitor em Tempo Real — EasyArch v5.2

> **Orçamento de RAM:** ~30–40 MB adicionais em memória residente (dentro do teto de +50 MB), usando apenas pacotes oficiais do repositório `extra` do Arch Linux.

## Novidades da v5.2
1. **Central de Controle e Notificações (`swaync`, `SUPER + N`):** substitui o `mako` (~20–25 MB líquidos), adicionando painel deslizante de vidro translúcido com histórico de notificações, Não Perturbe, player de mídia MPRIS e controle de volume, além do indicador `HUD` clicável na Waybar.
2. **OSD Translúcido de Volume e Teclas (`swayosd`, ~10–15 MB):** cápsula de vidro flutuante ao ajustar volume ou alternar mudo, com fallback automático para `wpctl`.
3. **Monitor Futurista em Tempo Real (`btop`, 0 MB residente):** abre ao clicar no módulo `CPU` da Waybar ou pressionar `SUPER + Esc`.
4. **Sincronia de Paleta ao Vivo:** `easyarch-theme.sh` (`SUPER + Shift + T`) agora tinge também o `swaync` e o `swayosd` em tempo real entre `glacial`, `amber` e `emerald`.
