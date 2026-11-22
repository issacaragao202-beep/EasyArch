# Auditoria e Correções Estruturais — EasyArch v4.5

> **Escopo:** Correção integral dos 17 problemas técnicos (4 críticos, 7 altos e 6 médios) identificados na auditoria profunda da v4.4, com bateria de testes anti-regressão.

## 1. Correções Críticas (P0)
1. **Loja Curada sob `footclient` (`scripts/qol/easyarch-loja.sh`):** Substituída passagem via env vars + `eval` por argumentos posicionais (`argv`) para `bash -lc`, corrigindo falha silenciosa de instalação no IPC do `foot --server`.
2. **Limite de 15 bytes de `/proc/<pid>/comm` (`scripts/qol/easyarch-lite-mode.sh`, `scripts/diagnostico/03-validar-fase2.sh`):** Substituído `pgrep/pkill -x nwg-dock-hyprland` (17 chars) por `pgrep/pkill -u "$(id -u)" -f '(^|/)nwg-dock-hyprland([[:space:]]|$)'`, evitando falha ao fechar o dock e empilhamento de instâncias.
3. **Classificador e parser do `easyarch-ai-assistant.sh`:** Ampliado prefixo para aspas/subshells (`bash -c "rm -rf /"`), cobertos `rm -r /`, `chmod 777 -R /`, `cp ... /dev/sdX` e `curl/wget | python3/perl/ruby`; corrigido `extract_base_bin` para `basename --`, caminhos absolutos (`/usr/bin/sudo`, `/usr/bin/env`), flags de `command`/`exec` e valores com espaços entre aspas.
4. **Snapper `@snapshots` e ACL em chroot (`scripts/instalacao/easyarch-configurar-snapper.sh`):** Valida montagem via `/etc/fstab` antes de remover subvolume aninhado, remonta `/.snapshots` mesmo com config `root` já existente e aplica `setfacl -m g:wheel:rx /.snapshots` fora de systemd ativo.

## 2. Correções Altas e Médias (P1–P2)
5. **Benchmark Wine 64-bit (`05-suite-benchmarks.sh`):** Ajustado `wine64-preloader` -> `wine64-preloade` (15 chars) no `pgrep -xc`.
6. **Bubblewrap (`easyarch-appimage-sandbox.sh`):** Propaga `$XAUTHORITY` em `--x11`, usa `--dev-bind-try /dev/dri`, adiciona hash curto SHA-256 em `SANDBOX_HOME`, valida `bwrap` e corrige `-h`.
7. **Waydroid (`easyarch-waydroid.sh`):** Tolera falhas transitórias de `hyprctl`/`jq` (até 6 ciclos) antes de encerrar `watch_loop` e adiciona `</dev/null` nos `nohup`.
8. **Agentes CLI (`easyarch-agents.sh`):** `fetch_secret` agora faz fallback para `pass` se `secret-tool lookup` retornar vazio.
9. **Aplicador `/etc` (`easyarch-aplicar-etc.sh`, `10-easyarch-resolv.conf`):** Desabilita `systemd-networkd`/`iwd`/`dhcpcd` conflitantes, habilita `auditd.service`, protege symlinks no backup e instala `10-easyarch-resolv.conf` apenas em chroot.
10. **Setup (`easyarch-setup.sh`):** Garante `-Syu` na primeira instalação mesmo pulando Etapa 0/4, oferece instalação do `Bottles` na Etapa 2/4, completa Etapa 4/4 com `security-status.sh` e `easyarch-hub.sh` e checa EOF no `awk getline`.
11. **Wine (`easyarch-win-run.sh`):** Verifica `wine` antes de criar prefixo, corrige `-h` e endurece `is_broad_user_dir()` com `xdg-user-dir`, `readlink -f`, `~/.ssh`, `~/.gnupg`, `~/.config` e `/etc`.
12. **Perfis, ISO, CLI, Foot e Phone (`easyarch-profile.sh`, `06-construir-iso-archiso.sh`, `easyarch.sh`, `hyprland.conf`, `easyarch-phone.sh`):** Suporte seguro a VMs sem `cpufreq`, sincronia `lite-mode` vs perfil `jogos`, busca de `.iso` sem `ls | head` sob `pipefail`, exclusão de `.git` na ISO, confirmação real em `easyarch limpar`, `pgrep -u "$(id -u)" -f` para `foot --server` e checagem de `adb`/`scrcpy`.
