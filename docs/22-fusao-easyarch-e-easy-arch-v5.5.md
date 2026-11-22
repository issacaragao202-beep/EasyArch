# EasyArch v5.5 — Fusão Unificada (EasyArch v5.4 + `easy-arch`) e Auditoria de Bugs

## 1. Arquitetura da Fusão
Os dois projetos foram consolidados em um único repositório (`easyarch/`) com entrada única via `scripts/instalacao/easyarch-instalar-iso.sh` e atalho raiz `./easy-arch.sh`.

O instalador unificado oferece três modos:
1. **EasyArch Completo (padrão):** Base + Desktop Glacial HUD (Hyprland/Waybar/Rofi/SwayNC/SwayOSD) + segurança `/etc` (`AppArmor`, `nftables`, `systemd-resolved` DoT, `earlyoom`, `zram-generator` zstd) + Snapper.
2. **Arch Base Minimalista (estilo `easy-arch`):** Apenas sistema base + Btrfs + Snapper + ZRAM + `earlyoom` + escolha livre de utilitário de rede (`iwd`, `NetworkManager`, `wpa_supplicant + dhcpcd`, `dhcpcd` ou manual), sem instalar desktop nem sobrescrever a escolha de rede.
3. **Personalizado / Dual-Boot:** Abre o `archinstall` oficial.

## 2. Funcionalidades Incorporadas do `easy-arch`
- **Auto-detecção de microcode (`detect_microcode`):** detecta `amd-ucode` (`AuthenticAMD`) ou `intel-ucode` (`GenuineIntel`) e omite a linha `initrd` de microcode se não houver suporte, eliminando o hardcode de `amd-ucode`.
- **Auto-detecção de VM (`detect_hypervisor` + `install_vm_guest_tools`):** instala e habilita guest tools automaticamente para KVM/QEMU (`qemu-guest-agent`), VMware (`open-vm-tools`), VirtualBox (`virtualbox-guest-utils`) e Hyper-V (`hyperv`).
- **Seletores interativos com padrões rápidos:** teclado (`br-abnt2` padrão, `/` lista via `localectl`), disco (`select` numerado), kernel (`linux`, `linux-lts`, `linux-zen`, `linux-hardened`), bootloader (`systemd-boot` ou `GRUB + grub-btrfs`), locale (`pt_BR.UTF-8` padrão, `/` pesquisa em `/etc/locale.gen`), fuso horário (`America/Sao_Paulo` padrão ou `auto` por HTTPS) e senha de root separada opcional.
- **Layout Btrfs completo:** `@`, `@home`, `@root` (`chmod 750`), `@srv`, `@snapshots`, `@var_log` (`chattr +C` NoCoW), `@var_cache_pacman_pkg` com `discard=async,compress=zstd,space_cache=v2,noatime`.
- **Proteção de `/boot` em rollbacks:** `/etc/pacman.d/hooks/50-bootbackup.hook` (`rsync -a --delete /boot /.bootbackup`) instalado tanto pelo instalador quanto por `easyarch-aplicar-etc.sh`, com `rsync` adicionado em `packages/fase1-base.txt`.
- **Pacman eye-candy idempotente:** `Color`, `ILoveCandy` e `ParallelDownloads = 5`.

## 3. Bugs Corrigidos Durante a Fusão
1. **Crash em bare metal sob `set -e` (`easy-arch.sh`):** `systemd-detect-virt` retorna código `1` quando imprime `none` em hardware físico, abortando o script inteiro. Corrigido com `$(systemd-detect-virt 2>/dev/null || true)`.
2. **Validação de rede sempre verdadeira (`easy-arch.sh`):** `((1 <= network_choice <= 5))` não é comparação encadeada em Bash; avalia `(1 <= x) <= 5`, aceitando qualquer valor (`0`, `99`, texto). Substituído por `[[ "${1:-}" =~ ^[1-5]$ ]]`.
3. **Symlink quebrado em `/etc/localtime` (`easy-arch.sh`):** `curl -s http://ip-api.com/...` dentro do chroot (sem HTTPS, sem timeout, sem `curl` garantido e sem validar retorno) criava link quebrado para o diretório `/usr/share/zoneinfo/`. Corrigido com `curl -fsS --max-time 3 https://ipapi.co/timezone` no host + validação `[[ -f "/usr/share/zoneinfo/${detected_tz}" ]]` + fallback seguro.
4. **Falha do `grub-btrfsd.service` (`easy-arch.sh`):** `grub-btrfsd` exige `inotify-tools`, que não era instalado no `pacstrap`. Adicionado `inotify-tools` ao modo GRUB.
5. **Concorrência de 4 `btrfs-scrub` no mesmo filesystem (`easy-arch.sh`):** habilitar `btrfs-scrub` em `/`, `/home`, `/var/log` e `/.snapshots` dispara 4 scrubs simultâneos no mesmo volume Btrfs. Reduzido ao timer único `btrfs-scrub@-.timer`.
6. **Sobrescrita destrutiva de `/etc/mkinitcpio.conf` (`easy-arch.sh`):** substituía o arquivo inteiro removendo `MODULES`, `microcode` e padrões do Arch. Preservado com `sed` cirúrgico na linha `HOOKS=`.
7. **Conflito `systemd-oomd` vs `earlyoom` e conflito de gerenciadores de rede:** mantido apenas `earlyoom` (calibrado para ~6 GB RAM) e mantida a escolha livre de rede apenas no perfil Minimalista, sem conflitar com `easyarch-aplicar-etc.sh`.
8. **Outras correções de robustez:** `printf '%s'` em vez de `echo -n` para LUKS2 (imune a senhas começando com `-e`/`-n`), `mkdir -p` para hooks do pacman, `wipefs -af` + `udevadm settle` no particionamento, validação de seleção vazia no `select` de discos e `compress=zstd` em vez de `compress-force=zstd:3`.
