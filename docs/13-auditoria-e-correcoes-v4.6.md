# Auditoria e Correções — EasyArch v4.6

> **Escopo:** 12 achados da revisão pós-v4.5 (5 bugs confirmados por execução e 7 lacunas de projeto), mais a primeira suíte de testes do repositório.

## 1. Bugs confirmados
1. **`easyarch instalar` (`scripts/easyarch.sh`):** `pacman -Ss ... | head -n 20 || printf 'Nenhum resultado.'` sob `pipefail` imprimia "Nenhum resultado." depois de listas longas (SIGPIPE do `head`). Novo helper `show_first_lines` captura a saída e só avisa quando ela é vazia. O script agora pode ser carregado com `source` nos testes.
2. **Multilib na etapa 3/4 (`easyarch-setup.sh`):** a Fase 4 inclui `lib32-mangohud`, mas só as etapas 1 e 2 habilitavam `[multilib]`. A etapa 3 agora chama `ensure_multilib`.
3. **Firewall sem rollback (`easyarch-aplicar-etc.sh`):** se `nft -c` falhasse, a config inválida ficava instalada e o `nftables.service` era reiniciado. Agora o arquivo anterior é restaurado do backup (ou removido, se não existia) e o restart é pulado.
4. **Parâmetros de kernel não configurados:** novo `scripts/instalacao/easyarch-kernel-params.sh` (idempotente, com backup, `--dry-run`) adiciona `lsm=landlock,lockdown,yama,integrity,apparmor,bpf` e `zswap.enabled=0` em systemd-boot (`loader/entries`, ignorando fallback), `/etc/kernel/cmdline` e GRUB. Integrado à etapa 0/4 do setup.
5. **Classificador de risco (`easyarch-ai-assistant.sh`):** agora marcam DESTRUTIVO `tee /dev/sdX` após pipe, `bash <(curl ..)`, `sh -c "$(curl ..)"`, `eval "$(curl ..)"`, `git clean -f`, `git reset --hard`, `git push --force`, `truncate -s0`, `mv /etc ...`, `iptables -F`, `nft flush ruleset`, `kill -9 -1`, redirecionamento (`>`) para `/etc`, `/boot` e dotfiles, `chown/chmod -R` em diretórios do sistema, `chmod 000 /etc`, `pacman -Rdd` e remoção de `base`/`glibc`/`linux`/`systemd` etc.

## 2. Lacunas de projeto
6. **Testes:** `tests/run-tests.sh` (162 verificações) e `.github/workflows/ci.yml`. Cobre sintaxe, permissões, shellcheck, JSON do Waybar, 29 casos do classificador (inclui falsos positivos como `git status`, `mv /tmp/a /tmp/b`, `echo >> arquivo`), `show_first_lines`, `easyarch-kernel-params.sh` e flags `-h`/`--no-net`.
7. **Início do Hyprland:** bloco de autostart no tty1 em `config.fish` e em `~/.bash_profile` (instalado por `02-instalar-configs-fase2.sh`, uma única vez). Usa `start-hyprland` quando existir, senão `Hyprland`. Desativar: `touch ~/.config/easyarch/no-autostart`.
8. **Pacotes:** Fase 1 ganhou `reflector`, `exfatprogs`, `ntfs-3g`, `xdg-user-dirs`; Fase 2 ganhou `pavucontrol`, `network-manager-applet` (ambos já tinham `windowrule`), `playerctl`, `xdg-utils`. Novo `etc/xdg/reflector/reflector.conf` (Brasil, Chile, Argentina; `reflector.timer` habilitado pelo aplicador de `/etc`).
9. **earlyoom:** `--avoid` inclui `Xwayland`, `NetworkManager`, `dbus-daemon`, `dbus-broker`; `-r 0` desliga o relatório a cada 60 s no journal.
10. **Sandbox de AppImage:** o HOME isolado usa hash do caminho (antes, do conteúdo: cada atualização perdia as configurações). Nova flag `--no-net` (`--unshare-net`).
11. **Hyprland:** `Print` salva o recorte em `Imagens/Capturas`, copia para o clipboard e notifica; `SHIFT+Print` captura a tela inteira; teclas de mídia via `playerctl`.
12. **`easyarch-update-safe.sh`:** `grep -q` sobre `snapper list-configs` não roda mais em pipe sob `pipefail`. Cabeçalhos de versão unificados em v4.6.

## 3. Verificação executada
- `bash -n` e `shellcheck -S warning` em todos os `.sh`: limpos. `tests/run-tests.sh`: 162 passaram, 0 falharam.
- Os 29 casos do classificador: 16 falhavam na v4.5 e passam na v4.6.
- Rollback do nftables exercitado em contêiner descartável com `nft` e `systemctl` falsos, no ramo chroot.
- Ainda não verificado: boot em VM, `mkarchiso`, ramo "sistema ativo" do rollback (`systemctl restart`), existência dos novos pacotes nos repositórios atuais, o nome do wrapper `start-hyprland` na versão instalada do Hyprland e a lista de países do `reflector`.
