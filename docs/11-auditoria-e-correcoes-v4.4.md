# Auditoria e Correções Estruturais — EasyArch v4.4

> **Escopo:** Correção integral dos 19 problemas técnicos (5 críticos, 7 altos, 5 médios e 2 de consistência) identificados na auditoria profunda da v4.3, com bateria de testes anti-regressão.

## 1. Correções Críticas (P0)
1. **DNS em `arch-chroot` (`scripts/instalacao/easyarch-aplicar-etc.sh`, `etc/tmpfiles.d/10-easyarch-resolv.conf`):** Preserva `/etc/resolv.conf` durante chroot e instala drop-in `tmpfiles.d` para criar o symlink no primeiro boot; em sistema ativo, só altera `/etc/resolv.conf` após `systemd-resolved.service` iniciar com sucesso, validando o retorno de `ln -sf`.
2. **Snapper em chroot e segurança de `/.snapshots` (`scripts/instalacao/easyarch-configurar-snapper.sh`):** Usa `snapper --no-dbus` fora de systemd ativo, só entra no fluxo plano quando `/.snapshots` consta em `/etc/fstab` (impedindo deleção de subvolume sem remontagem) e valida snapshot via `--csvout --columns number`.
3. **Live ISO `PATH`, `networkd` e `[multilib]` (`scripts/iso/06-construir-iso-archiso.sh`):** Adiciona `/etc/profile.d/easyarch-path.sh` e `/root/.zprofile` para Zsh, remove `dbus-org.freedesktop.network1.service` e `/etc/systemd/network`, valida `[multilib]` após `awk` e inclui `easyarch-sos.sh`.
4. **Hardening do Bubblewrap (`scripts/sandbox/easyarch-appimage-sandbox.sh`):** Adiciona `--chmod 0700 "$RUNTIME_DIR"`, `--cap-drop ALL`, `--unshare-cgroup-try`, `--setenv ARGV0 /app.AppImage` e `--unsetenv DISPLAY` por padrão com opt-in explícito `--x11`.
5. **Isolamento do Wine (`scripts/windows/easyarch-win-run.sh`):** Copia o executável para `C:\easyarch_run\` por padrão (exige `--mount-dir` para `E:` e recusa diretórios amplos como `~/Downloads`), varre todos os symlinks em `drive_c/users/$USER` via `find -type l` (PT-BR/EN) e controla versão do Wine para rodar `wineboot -u` antes de remover `z:`.

## 2. Correções Altas, Médias e de Consistência (P1–P3)
6. **Classificador `easyarch-ai-assistant.sh`:** Cobre caminhos absolutos (`/bin/rm`), `dd` com `of=` em qualquer ordem, `curl/wget | sudo -E bash`, `chmod --recursive`, `find -delete`, `tee /dev/...`, `mv ... /dev/null`, além de corrigir `--` e flags de `env` em `extract_base_bin`.
7. **Segredos em `easyarch-agents.sh`:** Substituído `env VAR=val` por `export` + `exec` (evita exposição em `/proc/<pid>/cmdline`) e adicionada validação de inicialização do cofre `pass`.
8. **Waydroid (`easyarch-waydroid.sh`):** Validação de binário `waydroid`, retorno `-1` em falha transitória do `hyprctl`/`jq` e alerta para `net.ipv4.ip_forward=0`.
9. **Pacotes (`packages/fase1-base.txt` / `fase4-dev-mobile.txt`):** `pacman-contrib` (`paccache`) movido para a Fase 1.
10. **Perfis CPU (`easyarch-profile.sh`):** Ajuste de `energy_performance_preference` para `amd-pstate-epp` e sincronização com `~/.local/state/easyarch-lite-mode`.
11. **Modo SOS real (`scripts/qol/easyarch-sos.sh`):** Criado guia dedicado de recuperação (TTY, `apparmor=0`, rollback Btrfs `@snapshots`, DoT) e conectado a `easyarch sos` e Hub #12.
12. **Smartphone (`easyarch-phone.sh`):** Removido `u0_a0` fixo e adicionada limpeza automática de `adb forward` via `trap EXIT`.
13. **Waybar, Benchmarks, Atualizador, Setup e DoT:** Fallback de sensor térmico em VMs (`02-instalar-configs-fase2.sh`), fechamento de FD no `awk` + `pgrep -x` + `Package id 0:` (`05-suite-benchmarks.sh` / `01-relatorio-memoria.sh`), checagem de `db.lck` + `sudo -v` + Flatpak `--system` (`easyarch-update-safe.sh`), `trap EXIT` + `pacman -Syu --needed` (`easyarch-setup.sh`), verificação estrita de DoT (`security-status.sh` / `02-validar-fase1.sh`), `return 1` em `easyarch-arcforge-env.fish`, `monitor = , highrr, auto, 1` + `DISPLAY` no D-Bus (`hyprland.conf`), `mpv` na loja e unificação de versão para `EasyArch v4.4`.
