# Auditoria e Correções — EasyArch v5.4

> **Escopo:** Correção dos 6 bugs identificados na revisão pós-v5.3 (incluindo o bug crítico de senhas com caracteres especiais no `arch-chroot`).

## Correções Aplicadas
1. **Senhas com `$`, `"`, `` ` `` e `\` no instalador ISO (`easyarch-instalar-iso.sh`):** heredoc convertido para citado (`<<'CHROOT_EOF'`), `USERNAME`/`TZ_IN` passados via `env` com validação de `/usr/share/zoneinfo/${TZ_IN}` e `chpasswd` alimentado diretamente via stdin literal (`printf ... | arch-chroot /mnt chpasswd`).
2. **Sufixo de partição genérico (`easyarch-instalar-iso.sh`):** `[[ "$DISK" =~ [0-9]$ ]]` cobre NVMe, MMC, `loop` e `nbd`.
3. **Botão `HUD` na Waybar sem `which` (`config/waybar/config.jsonc`):** `exec-if` alterado para `command -v swaync-client`.
4. **Zoom dinâmico na Fase 2 / ISO (`packages/fase2-desktop-terminal.txt`, `config/hypr/hyprland.conf`):** `jq` movido da Fase 3 para a Fase 2 e atalhos `SUPER + Scroll` encapsulados em `bash -lc`.
5. **Modo 1 clique em `ensure_multilib` (`easyarch-setup.sh`):** respeita `auto_yes=1` sem travar em `ask_yes`.
6. **Saída limpa na calculadora (`easyarch-calc.sh`):** `try/except` no Python substitui `Traceback` por mensagem curta `[ERRO]`.
