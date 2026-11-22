# Auditoria e Correções — EasyArch v4.2

> **Escopo:** Correção completa dos bugs de execução, rede, build de ISO, sandbox, Hyprland/Hyprlock e consistência identificados nas auditorias da v4.1 e v4.2.

## Correções Aplicadas na v4.2

1. **DNS-over-TLS + NetworkManager (`etc/systemd/resolved.conf.d/10-easyarch-dot.conf`):** Adicionado `Domains=~.` para evitar falha de DNS quando o roteador DHCP não suporta DoT (TCP 853).
2. **Construtor de ISO (`scripts/iso/06-construir-iso-archiso.sh`):** Movido `BUILD_BASE` para fora do repositório (`/tmp/build-easyarch-iso`) evitando cópia recursiva; corrigido layout de `/etc/skel` (`.config`, `.local/bin`, `.local/share`, `.gradle`, wallpaper); removido `20-waydroid.nft` da Live ISO; removidos symlinks conflitantes de `systemd-networkd`/`iwd` do `releng` antes de habilitar `NetworkManager`, `systemd-resolved`, `nftables` e `earlyoom`.
3. **Menus interativos (`easyarch-hub.sh`, `easyarch-loja.sh`, `easyarch-power.sh`, `easyarch-rede.sh`):** Menus de fallback no terminal enviados para `stderr` (`>&2`), validação estrita de índice numérico, `-no-custom` + `printf '%q'` no `rofi -dmenu`, checagem de scripts opcionais e fallback de `footclient` para `foot`.
4. **Aplicação de `/etc` (`easyarch-aplicar-etc.sh`):** Serviços já em execução agora são reiniciados (incluindo `systemd-journald`) para aplicar configs imediatamente.
5. **Setup guiado (`easyarch-setup.sh`):** Substituído arquivo fixo em `/tmp` por `mktemp`, `pacman -Sy` por `pacman -Syu` e `xargs` por `mapfile` para preservar TTY nos prompts do `pacman`.
6. **Benchmarks e Memória (`05-suite-benchmarks.sh`, `01-relatorio-memoria.sh`, `easyarch.sh`):** Corrigido `pgrep -fc` (evita `0\n0` no CSV), filtrado `/proc/*/smaps_rollup` legíveis sem `sudo`, relatórios salvos em `~/.local/state/easyarch/relatorios/` e opção `--show` exibida em `easyarch memoria`.
7. **Sandbox AppImage (`easyarch-appimage-sandbox.sh`):** Adicionados `APPIMAGE_EXTRACT_AND_RUN=1`, `--dev-bind-try /dev/fuse /dev/fuse` e `--ro-bind-try /run/systemd/resolve /run/systemd/resolve`.
8. **Agentes CLI (`easyarch-agents.sh`):** Só usa `secret-tool` se `org.freedesktop.secrets` estiver ativo no D-Bus; caso contrário usa `pass`.
9. **Waydroid (`easyarch-waydroid.sh`):** Modo `watch` usa `sudo -n` com notificação clara se exigir `NOPASSWD` e verifica timeout de 20s na inicialização da sessão.
10. **ArcForge no Fish (`easyarch-arcforge-env.fish` + `04-instalar-fase4.sh`):** Adicionado script nativo para Fish shell.
11. **Snapshots (`easyarch-update-safe.sh`):** Adicionado `--cleanup-algorithm number` para evitar acúmulo infinito no SSD de 240 GB.
12. **Hyprland / Hyprlock (`config/hypr/hyprland.conf`, `config/hypr/hyprlock.conf`):** Atualizadas `windowrule` para sintaxe moderna (`match:class`), removido `grace = 2` descontinuado do Hyprlock, trocado `SUPER + M` para abrir menu de confirmação (`easyarch-power.sh`) e adicionado fallback de terminal/scripts nos atalhos `SUPER + Shift + M/P`.
13. **Validações, Wine, Perfis e Docs:** Verificação ponta a ponta de `/etc/resolv.conf` na Fase 1, suporte a sockets PipeWire na Fase 2, validação `.exe`/`.msi`, `mkdir -p dosdevices` e suporte a DLLs irmãs via `E:` no Wine, fallback de governador para `amd-pstate-epp` em `easyarch-profile.sh`, e unificação de cabeçalhos/documentação para `EasyArch v4.2`.
