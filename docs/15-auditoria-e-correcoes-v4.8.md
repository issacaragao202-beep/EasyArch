# Auditoria e Correções — EasyArch v4.8

> **Escopo:** Correção integral dos 9 achados de lógica, integração e consistência identificados na revisão manual pós-v4.7.

## Correções Aplicadas
1. **Rede do Waydroid (`easyarch-aplicar-etc.sh` e `03-instalar-fase3.sh`):** `etc/nftables.d/20-waydroid.nft` agora é instalado automaticamente pelo `easyarch-aplicar-etc.sh`, validado com `nft -c` e coberto pelo rollback.
2. **Recarga do `nftables.service` sem flush global (`easyarch-aplicar-etc.sh`):** quando `nftables.service` já está ativo, usa `systemctl reload` em vez de `restart`, evitando `ExecStop=nft flush ruleset` da unit oficial do Arch e preservando tabelas de terceiros (Waydroid/Docker/libvirt).
3. **Build da ISO fora de tmpfs (`06-construir-iso-archiso.sh`):** padrão de `BUILD_BASE` alterado de `/tmp/build-easyarch-iso` para `/var/tmp/build-easyarch-iso` (em disco), evitando estouro dos ~3 GiB de tmpfs em sistemas com 6 GiB úteis.
4. **Perfis de CPU no Ryzen 5 3400G (`easyarch-profile.sh`):** detecta ausência de EPP (`acpi-cpufreq` no Zen+); no perfil `economico`, prefere `conservative` (ou `schedutil`) em vez de travar frequência mínima em `powersave`, e no perfil `dev` usa `ondemand` quando não há EPP.
5. **Classificador de risco (`easyarch-ai-assistant.sh` + `tests/classifier-cases.txt`):** adicionados 11 padrões destrutivos de disco, LUKS2, Btrfs, cache e SysRq (`mkfs -t`, `mkswap`, `blkdiscard`, `hdparm --security-erase`, `cryptsetup luksFormat/luksErase`, `nvme format`, `btrfs device remove`, `btrfs subvolume delete`, `pacman -Scc`, `> /proc/sysrq-trigger`). Total de 63 casos no classificador.
6. **Validação de 75 Hz no Hyprland (`03-validar-fase2.sh`):** regex atualizada para `1920x1080@7[45]\.` (aceita `74.97300 Hz` e `75.00000 Hz`).
7. **Detecção de `/etc/fstab` no Snapper (`easyarch-configurar-snapper.sh`):** regex corrigida para `^[[:space:]]*[^#[:space:]]`, ignorando linhas comentadas com espaços iniciais antes de `#`.
8. **Host key SSH por aparelho no `offload` (`easyarch-phone.sh`):** adicionado `-o HostKeyAlias=termux-<serial>` para evitar recusa de chave ao trocar de smartphone ou reinstalar o Termux.
9. **Versões e contagens unificadas:** banners unificados em `EasyArch v4.8` em todo o repositório e contagem exata de scripts documentada em `PROJECT_STATE.md` (37 scripts em `scripts/` + `tests/run-tests.sh` = 38 scripts `.sh`).
