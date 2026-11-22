#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Instalador Guiado da Live ISO (`easyarch-instalar`)
# Destino na ISO: /root/.local/bin/easyarch-instalar
#
# Instala o EasyArch completo (UEFI + Btrfs @/@home/@snapshots + LUKS2 opcional
# + systemd-boot + AppArmor + ZRAM + Hyprland Glacial HUD) com 4 perguntas simples.
# Para dual-boot ou particionamento manual, oferece o `archinstall` oficial.
# ==============================================================================

set -euo pipefail

DRY_RUN=0
while [[ "${1:-}" == -* ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help)
            cat <<'EOF'
EasyArch v5.4 — Instalador Guiado da Live ISO
Uso:
  easyarch-instalar            Inicia o assistente guiado interativo (UEFI + Btrfs)
  easyarch-instalar --dry-run  Simula o plano de instalação sem alterar nenhum disco
EOF
            exit 0
            ;;
        *) printf '[ERRO] Opção desconhecida: %s\n' "$1" >&2; exit 1 ;;
    esac
done

if (( DRY_RUN == 0 )) && [[ "$(id -u)" -ne 0 ]]; then
    printf '[ERRO] Execute como root na Live ISO (ou com sudo).\n' >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d /root/easyarch/packages ]]; then
    REPO_ROOT="/root/easyarch"
else
    REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fi

printf '====================================================================\n'
printf '         EasyArch v5.4 — INSTALADOR GUIADO DA LIVE ISO\n'
printf '   Mais simples que Windows · UEFI + Btrfs + Snapper + Glacial HUD\n'
printf '====================================================================\n\n'

# 1. Verificação UEFI
if (( DRY_RUN == 0 )) && [[ ! -d /sys/firmware/efi/efivars ]]; then
    printf '[ERRO] Modo UEFI não detectado. Ative UEFI na BIOS/VM antes de instalar.\n' >&2
    exit 1
fi

# 2. Verificação de internet (com abertura automática do nmtui se offline)
if (( DRY_RUN == 0 )); then
    if ! ping -c 1 -W 3 archlinux.org >/dev/null 2>&1; then
        printf '[INFO] Sem conexão com a internet. Abrindo seletor de Wi-Fi (nmtui)...\n'
        command -v nmtui >/dev/null 2>&1 && nmtui || true
        if ! ping -c 1 -W 3 archlinux.org >/dev/null 2>&1; then
            printf '[ERRO] Ainda sem internet. Conecte a rede e rode `easyarch-instalar` novamente.\n' >&2
            exit 1
        fi
    fi
    timedatectl set-ntp true >/dev/null 2>&1 || true
fi

printf 'Escolha o modo de instalação:\n'
printf '  1) Automático Guiado (disco inteiro -> Btrfs + Snapper + Glacial HUD pronto)\n'
printf '  2) Personalizado / Dual-Boot com Windows (abre archinstall oficial)\n'
printf '  3) Cancelar\n'
read -r -p "Opção (1/2/3): " mode_opt
case "$mode_opt" in
    1) ;;
    2)
        if command -v archinstall >/dev/null 2>&1; then
            exec archinstall
        else
            printf '[ERRO] Pacote archinstall não encontrado neste ambiente.\n' >&2
            exit 1
        fi
        ;;
    *) printf '[EasyArch] Instalação cancelada.\n'; exit 0 ;;
esac

# 3. Seleção segura do disco
printf '\n--- Discos detectados ---\n'
lsblk -d -p -e 7,11 -o NAME,SIZE,MODEL,TRAN 2>/dev/null || lsblk -d -p -o NAME,SIZE,MODEL
printf '\n'
read -r -p "Digite o disco de destino (ex.: /dev/sda ou /dev/nvme0n1): " DISK
if (( DRY_RUN == 0 )) && [[ ! -b "$DISK" ]]; then
    printf '[ERRO] Dispositivo de bloco inválido: "%s"\n' "$DISK" >&2
    exit 1
fi
DISK_BASE="$(basename -- "$DISK")"

# 4. Quatro perguntas simples com padrões prontos
while true; do
    read -r -p "1/4) Nome do seu usuário (ex.: joao): " USERNAME
    if [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ && "$USERNAME" != "root" ]]; then
        break
    fi
    printf '[AVISO] Use apenas letras minúsculas, números, _ ou - (não pode ser root).\n'
done

while true; do
    read -r -s -p "2/4) Senha do usuário ${USERNAME} (também usada para sudo): " USER_PASS; printf '\n'
    read -r -s -p "     Confirme a senha: " USER_PASS2; printf '\n'
    if [[ -n "$USER_PASS" && "$USER_PASS" == "$USER_PASS2" ]]; then
        break
    fi
    printf '[AVISO] Senhas vazias ou diferentes. Tente novamente.\n'
done

read -r -p "3/4) Nome do computador [easyarch]: " HOSTNAME_IN
HOSTNAME_IN="${HOSTNAME_IN:-easyarch}"
if ! [[ "$HOSTNAME_IN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]]; then
    printf '[ERRO] Hostname inválido: "%s"\n' "$HOSTNAME_IN" >&2
    exit 1
fi

while true; do
    read -r -p "4/4) Fuso horário [America/Sao_Paulo]: " TZ_IN
    TZ_IN="${TZ_IN:-America/Sao_Paulo}"
    if [[ "$TZ_IN" != *".."* && "$TZ_IN" =~ ^[A-Za-z0-9_/+.-]+$ ]] && { (( DRY_RUN == 1 )) || [[ -f "/usr/share/zoneinfo/${TZ_IN}" ]]; }; then
        break
    fi
    printf '[AVISO] Fuso horário inválido ou inexistente em /usr/share/zoneinfo: "%s"\n' "$TZ_IN"
done

read -r -p "     Criptografar o disco com senha LUKS2? (s/N): " enc_ans
USE_LUKS=0
LUKS_PASS=""
if [[ "${enc_ans,,}" == "s" || "${enc_ans,,}" == "sim" ]]; then
    USE_LUKS=1
    while true; do
        read -r -s -p "     Senha de criptografia LUKS2 (pedida ao ligar o PC): " LUKS_PASS; printf '\n'
        read -r -s -p "     Confirme a senha LUKS2: " LUKS_PASS2; printf '\n'
        if [[ -n "$LUKS_PASS" && "$LUKS_PASS" == "$LUKS_PASS2" ]]; then
            break
        fi
        printf '[AVISO] Senhas LUKS2 vazias ou diferentes.\n'
    done
fi

printf '\n====================================================================\n'
printf ' RESUMO DA INSTALAÇÃO\n'
printf '  Disco:        %s (SERÁ COMPLETAMENTE APAGADO)\n' "$DISK"
printf '  Layout:       UEFI 1 GiB (FAT32) + Btrfs (@, @home, @snapshots)\n'
printf '  Criptografia: %s\n' "$( (( USE_LUKS == 1 )) && echo 'LUKS2 ativada' || echo 'Não' )"
printf '  Usuário:      %s (admin/wheel) | PC: %s | Fuso: %s\n' "$USERNAME" "$HOSTNAME_IN" "$TZ_IN"
printf '  Sistema:      EasyArch v5.4 (Base + Desktop Glacial HUD + Snapper)\n'
printf '====================================================================\n'

if (( DRY_RUN == 1 )); then
    printf '\n[DRY-RUN] Simulação concluída. Nenhum disco foi tocado.\n'
    exit 0
fi

read -r -p "Para confirmar e apagar ${DISK}, digite exatamente APAGAR ${DISK_BASE}: " confirm_wipe
if [[ "$confirm_wipe" != "APAGAR ${DISK_BASE}" ]]; then
    printf '[EasyArch] Confirmação incorreta. Instalação cancelada sem alterar o disco.\n'
    exit 0
fi

# 5. Particionamento GPT + EFI + Btrfs (com LUKS2 opcional)
printf '\n[1/6] Particionando %s...\n' "$DISK"
umount -R /mnt 2>/dev/null || true
[[ -e /dev/mapper/cryptroot ]] && cryptsetup close cryptroot 2>/dev/null || true

sgdisk --zap-all "$DISK"
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$DISK"
sgdisk -n 2:0:0   -t 2:8300 -c 2:"EASYARCH" "$DISK"
partprobe "$DISK"
sleep 2

if [[ "$DISK" =~ [0-9]$ ]]; then
    PART_EFI="${DISK}p1"
    PART_ROOT="${DISK}p2"
else
    PART_EFI="${DISK}1"
    PART_ROOT="${DISK}2"
fi

mkfs.fat -F 32 -n EFI "$PART_EFI"

ROOT_DEV="$PART_ROOT"
if (( USE_LUKS == 1 )); then
    printf '%s' "$LUKS_PASS" | cryptsetup luksFormat --type luks2 --batch-mode "$PART_ROOT" -
    printf '%s' "$LUKS_PASS" | cryptsetup open "$PART_ROOT" cryptroot -
    ROOT_DEV="/dev/mapper/cryptroot"
fi

mkfs.btrfs -f -L EASYARCH "$ROOT_DEV"
mount "$ROOT_DEV" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache_pacman_pkg
umount /mnt

BTRFS_OPTS="noatime,compress=zstd,space_cache=v2"
mount -o "${BTRFS_OPTS},subvol=@" "$ROOT_DEV" /mnt
mkdir -p /mnt/boot /mnt/home /mnt/.snapshots /mnt/var/log /mnt/var/cache/pacman/pkg
mount -o "${BTRFS_OPTS},subvol=@home" "$ROOT_DEV" /mnt/home
mount -o "${BTRFS_OPTS},subvol=@snapshots" "$ROOT_DEV" /mnt/.snapshots
mount -o "${BTRFS_OPTS},subvol=@var_log" "$ROOT_DEV" /mnt/var/log
mount -o "${BTRFS_OPTS},subvol=@var_cache_pacman_pkg" "$ROOT_DEV" /mnt/var/cache/pacman/pkg
mount "$PART_EFI" /mnt/boot

# 6. Pacstrap com Fases 1 + 2 (habilitando multilib na Live ISO se preciso)
printf '\n[2/6] Instalando Arch Linux + EasyArch Base e Desktop Glacial HUD...\n'
if ! awk '/^\[multilib\][[:space:]]*$/{m=1;next} /^\[/{m=0} m && /^[[:space:]]*Include[[:space:]]*=/{f=1} END{exit !f}' /etc/pacman.conf 2>/dev/null; then
    awk '
        /^[[:space:]]*#?[[:space:]]*\[multilib\][[:space:]]*$/ { print "[multilib]"; in_m=1; done_inc=0; next }
        in_m && /^[[:space:]]*#?[[:space:]]*\[/ { in_m=0 }
        in_m && !done_inc && /^[[:space:]]*#[[:space:]]*Include[[:space:]]*=/ { sub(/^[[:space:]]*#[[:space:]]*/, ""); done_inc=1; print; next }
        { print }
    ' /etc/pacman.conf > /tmp/pacman.conf.multilib && install -m 0644 /tmp/pacman.conf.multilib /etc/pacman.conf
fi
pacman -Sy --noconfirm

mapfile -t PKGS < <({
    grep -Ev '^\s*(#|$)' "${REPO_ROOT}/packages/fase1-base.txt"
    grep -Ev '^\s*(#|$)' "${REPO_ROOT}/packages/fase2-desktop-terminal.txt"
} | awk '!seen[$0]++')
pacstrap -K /mnt "${PKGS[@]}"

# 7. fstab, locale, teclado, usuário e sudo
printf '\n[3/6] Configurando sistema, idioma pt_BR, ABNT2 e usuário %s...\n' "$USERNAME"
genfstab -U /mnt >> /mnt/etc/fstab
printf '%s\n' "$HOSTNAME_IN" > /mnt/etc/hostname
printf 'KEYMAP=br-abnt2\n' > /mnt/etc/vconsole.conf
printf 'LANG=pt_BR.UTF-8\n' > /mnt/etc/locale.conf
sed -i 's/^#pt_BR\.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/; s/^#en_US\.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen
printf '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 %s.localdomain %s\n' "$HOSTNAME_IN" "$HOSTNAME_IN" > /mnt/etc/hosts

# Copia multilib habilitado para o novo sistema
install -m 0644 /etc/pacman.conf /mnt/etc/pacman.conf

arch-chroot /mnt /usr/bin/env EASYARCH_USER="$USERNAME" EASYARCH_TZ="$TZ_IN" /bin/bash -euo pipefail <<'CHROOT_EOF'
ln -sf "/usr/share/zoneinfo/${EASYARCH_TZ}" /etc/localtime
hwclock --systohc
locale-gen
useradd -m -G wheel -s /usr/bin/fish "${EASYARCH_USER}"
printf '%s
' '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-easyarch-wheel
chmod 0440 /etc/sudoers.d/10-easyarch-wheel
CHROOT_EOF
# Alimenta chpasswd via stdin literal (imune a $, ", ` ou \ na senha)
printf '%s:%s\nroot:%s\n' "$USERNAME" "$USER_PASS" "$USER_PASS" | arch-chroot /mnt chpasswd

# 8. Bootloader systemd-boot + parâmetros EasyArch (AppArmor + zswap=0 + LUKS2 se ativo)
printf '\n[4/6] Configurando bootloader UEFI (systemd-boot)...\n'
if (( USE_LUKS == 1 )); then
    sed -i 's/^HOOKS=(.*)/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' /mnt/etc/mkinitcpio.conf
    arch-chroot /mnt mkinitcpio -P
    PART_UUID="$(blkid -s UUID -o value "$PART_ROOT")"
    ROOT_CMDLINE="cryptdevice=UUID=${PART_UUID}:cryptroot root=/dev/mapper/cryptroot"
else
    ROOT_UUID="$(blkid -s UUID -o value "$ROOT_DEV")"
    ROOT_CMDLINE="root=UUID=${ROOT_UUID}"
fi

arch-chroot /mnt bootctl install
cat > /mnt/boot/loader/loader.conf <<'EOF'
default easyarch.conf
timeout 3
console-mode max
editor no
EOF

cat > /mnt/boot/loader/entries/easyarch.conf <<EOF
title   EasyArch v5.4 (Arch Linux)
linux   /vmlinuz-linux
initrd  /amd-ucode.img
initrd  /initramfs-linux.img
options ${ROOT_CMDLINE} rootflags=subvol=@ rw quiet lsm=landlock,lockdown,yama,integrity,apparmor,bpf zswap.enabled=0
EOF

cat > /mnt/boot/loader/entries/easyarch-fallback.conf <<EOF
title   EasyArch v5.4 (Recuperação)
linux   /vmlinuz-linux
initrd  /amd-ucode.img
initrd  /initramfs-linux-fallback.img
options ${ROOT_CMDLINE} rootflags=subvol=@ rw
EOF

# 9. Copia repositório EasyArch e aplica /etc + Snapper + Dotfiles Glacial HUD automaticamente!
printf '\n[5/6] Aplicando segurança (/etc), Snapper e Desktop Glacial HUD...\n'
mkdir -p "/mnt/home/${USERNAME}/easyarch"
tar --exclude='.git' -C "$REPO_ROOT" -cf - . | tar -C "/mnt/home/${USERNAME}/easyarch" -xf -
arch-chroot /mnt chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/easyarch"
arch-chroot /mnt "/home/${USERNAME}/easyarch/scripts/instalacao/easyarch-aplicar-etc.sh" --yes
arch-chroot /mnt "/home/${USERNAME}/easyarch/scripts/instalacao/easyarch-configurar-snapper.sh"
arch-chroot /mnt su - "${USERNAME}" -c "bash /home/${USERNAME}/easyarch/scripts/instalacao/02-instalar-configs-fase2.sh"

printf '\n[6/6] Finalizando...\n'
unset USER_PASS USER_PASS2 LUKS_PASS LUKS_PASS2
printf '\n====================================================================\n'
printf ' [SUCESSO] EasyArch v5.4 instalado com segurança!\n'
printf ' Remova o pendrive e reinicie com: reboot\n'
printf ' No primeiro login, o Hyprland Glacial HUD abrirá automaticamente.\n'
printf ' Para instalar Wine/Steam/Dev depois, rode: ~/easyarch/scripts/instalacao/easyarch-setup.sh\n'
printf '====================================================================\n'
