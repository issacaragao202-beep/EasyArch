# PROJECT_STATE — EasyArch v5.5 (Fusão Unificada EasyArch v5.4 + easy-arch)

> **Versão única do repositório:** `EasyArch v5.5` · **Data:** 2026-11-22
> **Hardware-alvo principal:** AMD Ryzen 5 3400G (4C/8T · Zen+) · Radeon Vega 11 · 8 GB DDR4 single-channel 2667 MHz (~6 GB utilizáveis) · Mancer B450M-DA V2SC · SSD SATA Kingston A400 240 GB · Monitor 1920×1080 @ 75 Hz · UEFI — agora também com suporte automático a CPUs Intel e VMs (KVM/QEMU, VMware, VirtualBox, Hyper-V).

---

## 1. Pacote Atual
- **Arquivo:** `easyarch-v5.5.zip` (repositório limpo e unificado sob `easyarch/`, com atalho raiz `easy-arch.sh` e instalador ISO `scripts/instalacao/easyarch-instalar-iso.sh`).
- **Relatórios de Auditoria e Evolução:** `docs/08-auditoria-e-correcoes-estruturais-v4.1.md` até `docs/22-fusao-easyarch-e-easy-arch-v5.5.md`.

## 2. Estado Real das Validações (Sem Resultados Fictícios)
- **Sintaxe Bash (`bash -n`) e permissões `0755`:** Aprovadas em todos os scripts `.sh` (incluindo `easy-arch.sh`, `scripts/` e `tests/run-tests.sh`).
- **Suíte `tests/run-tests.sh`:** 260 verificações automatizadas (incluindo regressões v5.5 para `detect_microcode`, `detect_hypervisor`, `validate_network_choice`, `validate_kernel_choice`, `configure_pacman_eye_candy`, `append_grub_param`, `50-bootbackup.hook`, `rsync`, `inotify-tools`, timer único `btrfs-scrub@-.timer` e `--dry-run`).
- **Pendentes em ambiente real (Arch Linux VM UEFI e hardware Ryzen 5 3400G):** `mkarchiso`, execução real do `easyarch-instalar` / `easy-arch.sh`, `nft -c`, `cpupower frequency-info`, boot UEFI (`systemd-boot` e `GRUB + grub-btrfs`) + AppArmor + Hyprland + Waydroid.
