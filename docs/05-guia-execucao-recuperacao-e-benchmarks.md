# Projeto Linux Forge — Guia Mestre de Execução, Recuperação e Benchmarks (Ryzen 5 3400G)

> **Resumo:** Este guia consolida a ordem exata para aplicar os arquivos das **Fases 1 a 4** no seu computador (Ryzen 5 3400G · Vega 11 · ~6 GB RAM úteis · Kingston A400 240 GB · 1080p @ 75 Hz) respeitando o ritmo de **blocos mínimos de 2 horas a cada 3 etapas**, além dos procedimentos oficiais de recuperação em caso de falha.

---

## 1. Ordem Segura de Aplicação (Com Checkpoints)

### Bloco 1 — Diagnóstico, Base e Memória (≥ 2h)
1. **Diagnóstico sem risco (AGORA):** No Arch Live ISO (ou Linux atual), rode:
   `./scripts/diagnostico/01-diagnostico-hardware-disco.sh`
   Envie o `relatorio-hardware-disco-*.txt` para gerar o plano exato de particionamento (Btrfs + UEFI + LUKS2 opcional) sem risco de apagar partições existentes.
2. **Instalação Base + Pacotes da Fase 1:** Após particionar com o plano aprovado, instale `packages/fase1-base.txt`, aplique os arquivos de `etc/` (`zram-generator.conf`, `earlyoom`, `sysctl.d/*`, `nftables.conf`, `resolved.conf.d/*`, `modules-load.d/ntsync.conf`) e habilite `fstrim.timer`.
3. **Checkpoint 1:** Reinicie no sistema instalado, execute `./scripts/diagnostico/02-validar-fase1.sh` e `./scripts/manutencao/01-relatorio-memoria.sh boot-base`. Só avance quando todas as verificações críticas retornarem `[OK]`.

### Bloco 2 — Interface Glacial Silver e Terminal (≥ 2h)
4. **Pacotes e Dotfiles da Fase 2:** Instale `packages/fase2-desktop-terminal.txt` e execute `./scripts/instalacao/02-instalar-configs-fase2.sh`.
5. **Bases locais do terminal:** Execute `sudo pkgfile --update && tldr --update`.
6. **Checkpoint 2:** Inicie o Hyprland, rode `./scripts/diagnostico/03-validar-fase2.sh` e registre a RAM ociosa real (`05-suite-benchmarks.sh 02-desktop-ocioso`) comparando contra a meta de **500–700 MB** (e a meta experimental de **400 MB**).

### Bloco 3 — Compatibilidade Híbrida, Dev e Mobile (≥ 2h)
7. **Fase 3 (Linux/Flatpak, Windows e Android):** Instale `packages/fase3-hibrido.txt`, os Flatpaks (`Bottles`, `Flatseal`, `ProtonUp-Qt`), rode `./scripts/instalacao/03-instalar-fase3.sh` e valide com `./scripts/diagnostico/04-validar-fase3.sh` + `easyarch-ntsync-check.sh`.
8. **Fase 4 (Toolchain, ArcForge Java 17, Agentes CLI e Smartphone):** Instale `packages/fase4-dev-mobile.txt` e rode `./scripts/instalacao/04-instalar-fase4.sh`.
9. **Checkpoint 3:** Teste separadamente uma compilação Java 17/Gradle (ArcForge), um app Windows em prefixo isolado, um app Android no Waydroid (verificando o encerramento automático ao fechar) e `easyarch-phone.sh status`.

### Bloco 4 — Benchmarks Reais e Ajuste Fino
10. **Execução dos 7 Cenários (Seção 12):** Rode `05-suite-benchmarks.sh` em cada cenário e **também após encerrar cada carga** (`pos-navegador`, `pos-gradle`, `pos-wine`, `pos-waydroid`). Envie o arquivo `~/easyarch-benchmarks/resumo-benchmarks.csv` para compararmos:
    - `vm.swappiness=60` vs. `100` vs. `150` na ZRAM;
    - Kernel `linux` estável vs. `linux-zen` (somente com números reais).

---

## 2. Manual de Recuperação em Caso de Falha

### A. Sistema não dá boot após atualizar kernel ou parâmetros
1. No menu do `systemd-boot`, selecione a entrada do Arch Linux e pressione **`e`** para editar temporariamente os parâmetros do kernel (não altera nada em disco).
2. **Se suspeitar do AppArmor:** adicione `apparmor=0` ao final da linha e pressione Enter ([ArchWiki AppArmor](https://wiki.archlinux.org/title/AppArmor)).
3. **Se precisar cair em shell de emergência:** adicione `systemd.unit=rescue.target`.

### B. Reverter uma atualização quebrada usando Snapshot Btrfs (via Arch Live ISO)
Conforme o procedimento oficial do [ArchWiki Snapper](https://wiki.archlinux.org/title/Snapper_(Portugu%C3%AAs)):
1. Inicie pelo pendrive do Arch Live ISO.
2. *(Se usar LUKS2)* Desbloqueie o volume criptografado com `cryptsetup open /dev/<particao-real> cryptroot`.
3. Monte o topo do Btrfs (`subvolid=5`) em `/mnt`:
   `mount -o subvolid=5 /dev/<dispositivo-btrfs> /mnt`
4. Liste os snapshots disponíveis em `/mnt/@snapshots/` e identifique o número `<N>` do snapshot anterior à falha (`cat /mnt/@snapshots/<N>/info.xml`).
5. Mova o subvolume quebrado para segurança: `mv /mnt/@ /mnt/@.quebrado`
6. Crie um novo subvolume `@` gravável a partir do snapshot bom:
   `btrfs subvolume snapshot /mnt/@snapshots/<N>/snapshot /mnt/@`
7. Desmonte (`/mnt`) e reinicie. Após confirmar que voltou ao normal, remova `@.quebrado` com `btrfs subvolume delete`.

### C. Hyprland não abre ou tela preta
1. Pressione `Ctrl + Alt + F3` para acessar um TTY texto.
2. Inspecione o log recente em `$XDG_RUNTIME_DIR/hypr/` ou `journalctl --user -b -p err`.
3. Restaure suas configurações anteriores a partir do backup automático criado pelo instalador em `~/.config-backup-*`.
