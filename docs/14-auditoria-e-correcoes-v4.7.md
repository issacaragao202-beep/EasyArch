# Auditoria e Correções — EasyArch v4.7

> **Escopo:** Correção integral dos 24 bugs confirmados (5 críticos, 9 altos, 6 médios e 4 baixos) identificados na auditoria estática, dinâmica e de fuzzing sobre a v4.6, com expansão da suíte `tests/run-tests.sh`.

## 1. Correções Críticas (5)
1. **`easyarch-kernel-params.sh` (globbing e escapes `awk -v`):** substituído `for tok in $current` por tokenizador com preservação de aspas (sem expansão de `*`) e substituído `awk -v` por `ENVIRON[...]` (imune a escapes como `\amd-ucode.img`).
2. **`easyarch-kernel-params.sh` (comentários em `/etc/default/grub`):** parser dedicado preserva aspas e comentários à direita na linha `GRUB_CMDLINE_LINUX_DEFAULT`.
3. **`easyarch-ai-assistant.sh` (20+ bypasses no classificador):** adicionada detecção de `rm -r ~/\$HOME/home`, `rm -r -- /etc`, `bash <<< "$(curl ...)"`, `1>/etc/passwd`, `>|/etc/passwd`, `truncate --size=0`, `kill -s KILL -1`, `kill -9 1`, `/dev/mmcblk*`, `/dev/mapper/*`, `curl | node/php/lua/awk`, `chown -R --no-dereference`, `pacman -R --nodeps --nodeps` e `find -exec rm`.
4. **`easyarch-win-run.sh` (bypass de `--mount-dir`):** `is_broad_user_dir` agora resolve symlinks de `$HOME` e bloqueia árvores inteiras (`/*`) de `.config`, `.local`, `.ssh`, `.gnupg`, `.password-store`, `.aws`, `.kube`, `/etc`, `/usr`, `/var`, `/boot`, `/sys`, `/proc` e `/root`.
5. **SIGPIPE sob `set -o pipefail` (6 pontos em 5 scripts):** eliminados pipes `| grep -q` em `03-validar-fase2.sh`, `easyarch-configurar-snapper.sh`, `easyarch-waydroid.sh`, `easyarch-ntsync-check.sh` e `02-validar-fase1.sh`.

## 2. Correções Altas (9)
6. **`packages/fase2-desktop-terminal.txt`:** substituído `libayatana-appindicator` por `libappindicator` (dependência opcional oficial do `udiskie --appindicator` no Arch Linux).
7. **ZRAM ativa em tempo real:** `easyarch-aplicar-etc.sh` inicia `dev-zram0.swap` e `02-validar-fase1.sh` valida via `swapon`.
8. **`config/fish/config.fish`:** proteção de `(tty 2>/dev/null)` com aspas em `set -l cur_tty` (evita erro de sintaxe em SSH/cron sem TTY).
9. **`02-instalar-configs-fase2.sh`:** ao criar `~/.bash_profile` do zero, preserva `[[ -f ~/.bashrc ]] && . ~/.bashrc` e adiciona `~/.local/bin` ao `PATH`.
10. **`readlink -f --`:** adicionado `--` em `easyarch-appimage-sandbox.sh`, `easyarch-win-run.sh` e `easyarch-waydroid.sh`.
11. **`easyarch-setup.sh` (`ensure_multilib`):** valida `Include =` ativo dentro de `[multilib]` e aceita espaços após `#`.
12. **`easyarch-kernel-params.sh` (`*fallback*`):** testa apenas `$(basename -- "$f")`.
13. **`easyarch-aplicar-etc.sh`:** rollback do nftables restaura também `00-base.nft`; `reflector.timer` checa existência do unit em chroot e exibe `[OK]` no modo live.
14. **`06-construir-iso-archiso.sh` e `security-status.sh`:** ISO embute `reflector.conf`; parser de `resolvectl status` isola a seção `Global` e distingue `DoT-OPT` (`opportunistic`) de `DoT-OFF`.

## 3. Correções Médias e Baixas (10)
15. **`config/foot/foot.ini`:** `[colors]` atualizado para `[colors-dark]` (Foot 1.26+ no Arch Linux).
16. **`easyarch-configurar-snapper.sh`:** backup movido para `/root/easyarch-snapper-backup-*` (fora de `/etc/snapper/configs/`).
17. **Códigos de saída CLI:** subcomandos desconhecidos agora retornam `exit 1` em `easyarch-ai-assistant.sh`, `easyarch-waydroid.sh`, `easyarch-agents.sh` e `easyarch-phone.sh`.
18. **`easyarch-kernel-params.sh`:** remove espaço inicial quando `GRUB_CMDLINE_LINUX_DEFAULT=""`, detecta bootloaders antes de perguntar confirmação e procura `grub` em `$BOOT_DIRS`.
19. **`01-diagnostico-hardware-disco.sh`:** checa `command -v lspci` explicitamente e usa `/tmp` como fallback se `$PWD` for somente leitura.
20. **`extract_base_bin` (`easyarch-ai-assistant.sh`):** trata `;`, `&&`, `||`, `|`, escapes e `env -S`.
21. **QoL (`easyarch-hub.sh`, `easyarch-power.sh`, `easyarch-lite-mode.sh`):** fallback `bash` quando `fish` ausente, checagem de `hyprlock`/`hyprctl` e guarda `WAYLAND_DISPLAY` antes de subir o dock.
22. **`easyarch-appimage-sandbox.sh`:** `--no-net` unificado em todas as mensagens de uso.
23. **`easyarch-loja.sh` e `easyarch-phone.sh`:** aviso de `[multilib]` para `steam` e validação numérica de portas (`1..65535`) em `forward`.
24. **Isolamento de CWD no Wine e instaladores de diagnóstico:** `easyarch-win-run.sh` faz `cd` para o diretório de execução; `03-validar-fase2.sh` e `04-validar-fase3.sh` agora são instalados em `~/.local/bin/`.
