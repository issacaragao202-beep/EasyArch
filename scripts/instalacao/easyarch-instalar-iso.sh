#!/usr/bin/env bash
# ==============================================================================
# Origem/Licença: incorpora fluxos modificados de classy-giraffe/easy-arch (Apache 2.0; ver LICENSE-APACHE-2.0 e NOTICE).
# EasyArch v5.5 — Instalador Unificado da Live ISO (`easyarch-instalar` / `easy-arch.sh`)
# Destino na ISO: /root/.local/bin/easyarch-instalar
#
# Fusão completa EasyArch v5.4 + easy-arch (com correções de bugs):
#   - Perfis: EasyArch Completo (Glacial HUD + AppArmor + nftables + DoT + earlyoom)
#             OU Arch Base Minimalista (estilo easy-arch, rede configurável)
#             OU Personalizado / Dual-Boot (archinstall oficial)
#   - Auto-detecção de microcode (AMD / Intel / genérico) e guest tools de VM
#     (KVM/QEMU, VMware, VirtualBox, Hyper-V) sem quebrar `set -e` em bare metal
#   - Seletor interativo de teclado, disco (com validação), kernel (linux/lts/zen/hardened),
#     bootloader (systemd-boot ou GRUB + grub-btrfs com inotify-tools), locale e fuso horário
#   - Layout Btrfs completo (@, @home, @root, @srv, @snapshots, @var_log NoCoW,
#     @var_cache_pacman_pkg) + LUKS2 opcional + 50-bootbackup.hook + btrfs-scrub@-.timer
# ==============================================================================

set -euo pipefail

# --- Funções auxiliares puras (testáveis via tests/run-tests.sh) --------------

detect_microcode() {
    local cpuinfo="${1:-/proc/cpuinfo}"
    if [[ -r "$cpuinfo" ]]; then
        if grep -q 'AuthenticAMD' "$cpuinfo" 2>/dev/null; then
            printf 'amd-ucode\n'
            return 0
        elif grep -q 'GenuineIntel' "$cpuinfo" 2>/dev/null; then
            printf 'intel-ucode\n'
            return 0
        fi
    fi
    printf '\n'
}

detect_hypervisor() {
    local hv=""
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        hv="$(systemd-detect-virt 2>/dev/null || true)"
    fi
    case "$hv" in
        kvm|qemu)  printf 'kvm\n' ;;
        vmware)    printf 'vmware\n' ;;
        oracle)    printf 'oracle\n' ;;
        microsoft) printf 'microsoft\n' ;;
        *)         printf 'none\n' ;;
    esac
}

validate_network_choice() {
    [[ "${1:-}" =~ ^[1-5]$ ]]
}

validate_kernel_choice() {
    case "${1:-}" in
        1|linux)          printf 'linux\n'; return 0 ;;
        2|linux-lts)      printf 'linux-lts\n'; return 0 ;;
        3|linux-zen)      printf 'linux-zen\n'; return 0 ;;
        4|linux-hardened) printf 'linux-hardened\n'; return 0 ;;
        *)                return 1 ;;
    esac
}

configure_pacman_eye_candy() {
    local conf="${1:-/mnt/etc/pacman.conf}"
    [[ -f "$conf" ]] || return 1
    local tmp
    tmp="$(mktemp)"
    awk '
        /^[[:space:]]*#?[[:space:]]*Color[[:space:]]*$/ {
            print "Color"
            next
        }
        /^[[:space:]]*#?[[:space:]]*ILoveCandy[[:space:]]*$/ {
            print "ILoveCandy"
            next
        }
        /^[[:space:]]*#?[[:space:]]*ParallelDownloads[[:space:]]*=/ {
            print "ParallelDownloads = 5"
            next
        }
        { print }
    ' "$conf" > "$tmp"
    if grep -q '^Color$' "$tmp" && ! grep -q '^ILoveCandy$' "$tmp"; then
        sed -i '/^Color$/a ILoveCandy' "$tmp"
    fi
    install -m 0644 "$tmp" "$conf"
    rm -f "$tmp"
}

append_grub_param() {
    local grub_file="$1"
    local var_name="$2"
    local extra_params="$3"
    [[ -f "$grub_file" && -n "$extra_params" ]] || return 0
    local tmp
    tmp="$(mktemp)"
    awk -v var="$var_name" -v extra="$extra_params" '
        BEGIN { pat = "^" var "=\"" }
        $0 ~ pat {
            sub(pat, "")
            # Separa valor até a primeira aspa dupla de fechamento preservando comentário à direita
            idx = index($0, "\"")
            if (idx > 0) {
                val = substr($0, 1, idx - 1)
                rest = substr($0, idx + 1)
                if (val == "") {
                    print var "=\"" extra "\"" rest
                } else {
                    print var "=\"" val " " extra "\"" rest
                }
                next
            }
        }
        { print }
    ' "$grub_file" > "$tmp"
    install -m 0644 "$tmp" "$grub_file"
    rm -f "$tmp"
}

install_vm_guest_tools() {
    local hv="$1"
    local root_mnt="${2:-/mnt}"
    case "$hv" in
        kvm)
            printf '[VM] KVM/QEMU detectado: instalando qemu-guest-agent...\n'
            pacstrap "$root_mnt" qemu-guest-agent
            systemctl enable qemu-guest-agent --root="$root_mnt" >/dev/null 2>&1 || true
            ;;
        vmware)
            printf '[VM] VMware detectado: instalando open-vm-tools...\n'
            pacstrap "$root_mnt" open-vm-tools
            systemctl enable vmtoolsd --root="$root_mnt" >/dev/null 2>&1 || true
            systemctl enable vmware-vmblock-fuse --root="$root_mnt" >/dev/null 2>&1 || true
            ;;
        oracle)
            printf '[VM] VirtualBox detectado: instalando virtualbox-guest-utils...\n'
            pacstrap "$root_mnt" virtualbox-guest-utils
            systemctl enable vboxservice --root="$root_mnt" >/dev/null 2>&1 || true
            ;;
        microsoft)
            printf '[VM] Hyper-V detectado: instalando hyperv...\n'
            pacstrap "$root_mnt" hyperv
            systemctl enable hv_fcopy_daemon --root="$root_mnt" >/dev/null 2>&1 || true
            systemctl enable hv_kvp_daemon --root="$root_mnt" >/dev/null 2>&1 || true
            systemctl enable hv_vss_daemon --root="$root_mnt" >/dev/null 2>&1 || true
            ;;
        *)
            ;;
    esac
}

# --- Parsing de argumentos ----------------------------------------------------

DRY_RUN=0
while [[ "${1:-}" == -* ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help)
            cat <<'EOF'
EasyArch v5.5 — Instalador Unificado da Live ISO (EasyArch + easy-arch)
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
printf '         EasyArch v5.5 — INSTALADOR UNIFICADO DA LIVE ISO\n'
printf '   EasyArch Glacial HUD + easy-arch · UEFI + Btrfs + Snapper + LUKS2\n'
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

# 3. Perfil de instalação
printf 'Escolha o modo de instalação:\n'
printf '  1) EasyArch Completo [padrão] (Base + Glacial HUD + AppArmor + nftables + DoT + Snapper)\n'
printf '  2) Arch Base Minimalista (estilo easy-arch: Btrfs + Snapper + ZRAM + rede livre, sem desktop)\n'
printf '  3) Personalizado / Dual-Boot com Windows (abre archinstall oficial)\n'
printf '  4) Cancelar\n'
read -r -p "Opção [1]: " mode_opt
INSTALL_PROFILE="completo"
case "${mode_opt:-1}" in
    1) INSTALL_PROFILE="completo" ;;
    2) INSTALL_PROFILE="minimal" ;;
    3)
        if command -v archinstall >/dev/null 2>&1; then
            exec archinstall
        else
            printf '[ERRO] Pacote archinstall não encontrado neste ambiente.\n' >&2
            exit 1
        fi
        ;;
    *) printf '[EasyArch] Instalação cancelada.\n'; exit 0 ;;
esac

# 4. Layout de teclado do console (com busca via '/')
KEYMAP_IN="br-abnt2"
while true; do
    read -r -p "Teclado no console [br-abnt2] (digite '/' para listar): " kb_ans
    case "${kb_ans:-}" in
        '')
            KEYMAP_IN="br-abnt2"
            break
            ;;
        '/')
            if command -v localectl >/dev/null 2>&1; then
                localectl list-keymaps | { command -v less >/dev/null 2>&1 && less -M || cat; } || true
            else
                printf '[INFO] localectl indisponível neste ambiente.\n'
            fi
            ;;
        *)
            if (( DRY_RUN == 1 )) || ! command -v localectl >/dev/null 2>&1 || localectl list-keymaps | grep -Fxq "$kb_ans"; then
                KEYMAP_IN="$kb_ans"
                (( DRY_RUN == 0 )) && command -v loadkeys >/dev/null 2>&1 && loadkeys "$KEYMAP_IN" 2>/dev/null || true
                break
            else
                printf '[AVISO] Keymap inexistente: "%s"\n' "$kb_ans"
            fi
            ;;
    esac
done

# 5. Seleção segura do disco (menu numerado validado)
printf '\n--- Discos detectados ---\n'
mapfile -t DISK_LIST < <(lsblk -dpno NAME,SIZE,MODEL,TRAN -e 7,11 2>/dev/null | grep -E '^/dev/(sd|nvme|vd|mmcblk)' || true)
DISK=""
if (( ${#DISK_LIST[@]} > 0 )); then
    PS3="Selecione o número do disco de destino (ex.: 1): "
    select ENTRY in "${DISK_LIST[@]}"; do
        if [[ -n "${ENTRY:-}" ]]; then
            DISK="$(awk '{print $1}' <<<"$ENTRY")"
            break
        fi
        printf '[AVISO] Seleção inválida. Digite um número da lista.\n'
    done
else
    if (( DRY_RUN == 1 )); then
        read -r -p "Nenhum disco físico listado (dry-run). Digite disco simulado [/dev/sda]: " DISK
        DISK="${DISK:-/dev/sda}"
    else
        printf '[ERRO] Nenhum disco de destino elegível encontrado via lsblk.\n' >&2
        exit 1
    fi
fi

if [[ -z "$DISK" ]]; then
    printf '[ERRO] Nenhum disco selecionado.
' >&2
    exit 1
fi
if (( DRY_RUN == 0 )) && [[ ! -b "$DISK" ]]; then
    printf '[ERRO] Dispositivo de bloco inválido: "%s"\n' "$DISK" >&2
    exit 1
fi
DISK_BASE="$(basename -- "$DISK")"

# 6. Seleção de kernel
printf '\n--- Kernel Linux ---\n'
printf '  1) linux          [padrão] (Estável oficial Arch — recomendado)\n'
printf '  2) linux-lts               (Suporte de longo prazo)\n'
printf '  3) linux-zen               (Otimizado para responsividade desktop/jogos)\n'
printf '  4) linux-hardened          (Foco em segurança; atenção: pode restringir bwrap/Waydroid)\n'
KERNEL=""
while true; do
    read -r -p "Kernel [1]: " k_opt
    if KERNEL="$(validate_kernel_choice "${k_opt:-1}")"; then
        break
    fi
    printf '[AVISO] Opção inválida. Escolha 1, 2, 3 ou 4.\n'
done

# 7. Seleção de bootloader
printf '\n--- Bootloader UEFI ---\n'
printf '  1) systemd-boot            [padrão] (Ultra-leve, rápido, nativo UEFI)\n'
printf '  2) GRUB + grub-btrfs                (Permite dar boot direto em snapshots Btrfs no menu)\n'
BOOTLOADER="systemd-boot"
while true; do
    read -r -p "Bootloader [1]: " bl_opt
    case "${bl_opt:-1}" in
        1) BOOTLOADER="systemd-boot"; break ;;
        2) BOOTLOADER="grub"; break ;;
        *) printf '[AVISO] Opção inválida. Escolha 1 ou 2.\n' ;;
    esac
done

# 8. Seleção de rede (apenas no modo Base Minimalista; EasyArch Completo usa NetworkManager + DoT)
NETWORK_CHOICE="2"
if [[ "$INSTALL_PROFILE" == "minimal" ]]; then
    printf '\n--- Utilitário de Rede (modo Minimalista) ---\n'
    printf '  1) iwd              (Wi-Fi leve da Intel com DHCP embutido)\n'
    printf '  2) NetworkManager   [padrão] (Wi-Fi + Ethernet universal)\n'
    printf '  3) wpa_supplicant + dhcpcd\n'
    printf '  4) dhcpcd           (Ethernet / VMs)\n'
    printf '  5) Manual           (configurar depois)\n'
    while true; do
        read -r -p "Rede [2]: " net_opt
        NETWORK_CHOICE="${net_opt:-2}"
        if validate_network_choice "$NETWORK_CHOICE"; then
            break
        fi
        printf '[AVISO] Opção inválida. Escolha de 1 a 5.\n'
    done
fi

# 9. Perguntas de usuário, senhas, hostname, idioma e fuso horário
printf '\n'
while true; do
    read -r -p "1/5) Nome do seu usuário (ex.: joao): " USERNAME
    if [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ && "$USERNAME" != "root" ]]; then
        break
    fi
    printf '[AVISO] Use apenas letras minúsculas, números, _ ou - (não pode ser root).\n'
done

while true; do
    read -r -s -p "2/5) Senha do usuário ${USERNAME} (também usada para sudo): " USER_PASS; printf '\n'
    read -r -s -p "     Confirme a senha: " USER_PASS2; printf '\n'
    if [[ -n "$USER_PASS" && "$USER_PASS" == "$USER_PASS2" ]]; then
        break
    fi
    printf '[AVISO] Senhas vazias ou diferentes. Tente novamente.\n'
done

ROOT_PASS="$USER_PASS"
read -r -p "     Definir senha de root diferente da senha do usuário? (s/N): " diff_root
if [[ "${diff_root,,}" == "s" || "${diff_root,,}" == "sim" ]]; then
    while true; do
        read -r -s -p "     Senha do root: " ROOT_PASS; printf '\n'
        read -r -s -p "     Confirme a senha do root: " ROOT_PASS2; printf '\n'
        if [[ -n "$ROOT_PASS" && "$ROOT_PASS" == "$ROOT_PASS2" ]]; then
            break
        fi
        printf '[AVISO] Senhas de root vazias ou diferentes.\n'
    done
fi

while true; do
    read -r -p "3/5) Nome do computador [easyarch]: " HOSTNAME_IN
    HOSTNAME_IN="${HOSTNAME_IN:-easyarch}"
    if [[ "$HOSTNAME_IN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]]; then
        break
    fi
    printf '[AVISO] Hostname inválido: "%s"\n' "$HOSTNAME_IN"
done

LOCALE_IN="pt_BR.UTF-8"
while true; do
    read -r -p "4/5) Idioma/Locale [pt_BR.UTF-8] (digite '/' para buscar): " loc_ans
    case "${loc_ans:-}" in
        '')
            LOCALE_IN="pt_BR.UTF-8"
            break
            ;;
        '/')
            if [[ -r /etc/locale.gen ]]; then
                sed -E '/^# +|^#$/d;s/^#| *$//g' /etc/locale.gen | { command -v less >/dev/null 2>&1 && less -M || cat; } || true
            else
                printf '[INFO] /etc/locale.gen indisponível neste ambiente.\n'
            fi
            ;;
        *)
            escaped_loc="$(sed 's/[][\\.^$*+?(){}|]/\\&/g' <<<"$loc_ans")"
            if (( DRY_RUN == 1 )) || [[ ! -r /etc/locale.gen ]] || grep -qE "^#?${escaped_loc}[[:space:]]" /etc/locale.gen; then
                LOCALE_IN="$loc_ans"
                break
            else
                printf '[AVISO] Locale não encontrado em /etc/locale.gen: "%s"\n' "$loc_ans"
            fi
            ;;
    esac
done

while true; do
    read -r -p "5/5) Fuso horário [America/Sao_Paulo] (ou 'auto' por IP): " TZ_IN
    TZ_IN="${TZ_IN:-America/Sao_Paulo}"
    if [[ "$TZ_IN" == "auto" ]]; then
        detected_tz=""
        if (( DRY_RUN == 0 )) && command -v curl >/dev/null 2>&1; then
            detected_tz="$(curl -fsS --max-time 3 https://ipapi.co/timezone 2>/dev/null | tr -d '\r\n' || true)"
        fi
        if [[ -n "$detected_tz" && "$detected_tz" != *".."* && -f "/usr/share/zoneinfo/${detected_tz}" ]]; then
            TZ_IN="$detected_tz"
            printf '[INFO] Fuso horário detectado: %s\n' "$TZ_IN"
            break
        else
            printf '[AVISO] Detecção automática indisponível; usando America/Sao_Paulo.\n'
            TZ_IN="America/Sao_Paulo"
            break
        fi
    fi
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

MICROCODE="$(detect_microcode)"
HYPERVISOR="$(detect_hypervisor)"

printf '\n====================================================================\n'
printf ' RESUMO DA INSTALAÇÃO (EasyArch v5.5 Unificado)\n'
printf '  Perfil:       %s\n' "$( [[ "$INSTALL_PROFILE" == "completo" ]] && echo 'EasyArch Completo (Base + Glacial HUD + Segurança)' || echo 'Arch Base Minimalista (estilo easy-arch)' )"
printf '  Disco:        %s (SERÁ COMPLETAMENTE APAGADO)\n' "$DISK"
printf '  Layout:       UEFI 1 GiB (FAT32) + Btrfs (@, @home, @root, @srv, @snapshots, @var_log NoCoW, @var_cache_pacman_pkg)\n'
printf '  Criptografia: %s\n' "$( (( USE_LUKS == 1 )) && echo 'LUKS2 ativada' || echo 'Não' )"
printf '  Kernel/CPU:   %s | Microcode: %s | VM: %s\n' "$KERNEL" "${MICROCODE:-nenhum}" "$HYPERVISOR"
printf '  Bootloader:   %s\n' "$( [[ "$BOOTLOADER" == "grub" ]] && echo 'GRUB + grub-btrfs (boot em snapshots)' || echo 'systemd-boot' )"
printf '  Usuário:      %s (admin/wheel) | PC: %s | Locale: %s | Teclado: %s | Fuso: %s\n' "$USERNAME" "$HOSTNAME_IN" "$LOCALE_IN" "$KEYMAP_IN" "$TZ_IN"
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

# 10. Particionamento GPT + EFI + Btrfs (com LUKS2 opcional)
printf '\n[1/6] Limpando assinaturas e particionando %s...\n' "$DISK"
umount -R /mnt 2>/dev/null || true
[[ -e /dev/mapper/cryptroot ]] && cryptsetup close cryptroot 2>/dev/null || true

wipefs -af "$DISK" >/dev/null 2>&1 || true
sgdisk --zap-all "$DISK"
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$DISK"
sgdisk -n 2:0:0   -t 2:8300 -c 2:"EASYARCH" "$DISK"
partprobe "$DISK"
udevadm settle 2>/dev/null || true
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
for sv in @ @home @root @srv @snapshots @var_log @var_cache_pacman_pkg; do
    btrfs subvolume create "/mnt/${sv}"
done
umount /mnt

BTRFS_OPTS="noatime,compress=zstd,space_cache=v2,discard=async"
mount -o "${BTRFS_OPTS},subvol=@" "$ROOT_DEV" /mnt
mkdir -p /mnt/boot /mnt/home /mnt/root /mnt/srv /mnt/.snapshots /mnt/var/log /mnt/var/cache/pacman/pkg
mount -o "${BTRFS_OPTS},subvol=@home" "$ROOT_DEV" /mnt/home
mount -o "${BTRFS_OPTS},subvol=@root" "$ROOT_DEV" /mnt/root
chmod 750 /mnt/root
mount -o "${BTRFS_OPTS},subvol=@srv" "$ROOT_DEV" /mnt/srv
mount -o "${BTRFS_OPTS},subvol=@snapshots" "$ROOT_DEV" /mnt/.snapshots
mount -o "${BTRFS_OPTS},subvol=@var_log" "$ROOT_DEV" /mnt/var/log
chattr +C /mnt/var/log 2>/dev/null || true
mount -o "${BTRFS_OPTS},subvol=@var_cache_pacman_pkg" "$ROOT_DEV" /mnt/var/cache/pacman/pkg
mount "$PART_EFI" /mnt/boot

# 11. Pacstrap (habilitando multilib na Live ISO no modo EasyArch Completo)
printf '\n[2/6] Instalando Arch Linux (%s, kernel %s)...\n' "$INSTALL_PROFILE" "$KERNEL"
if [[ "$INSTALL_PROFILE" == "completo" ]]; then
    if ! awk '/^\[multilib\][[:space:]]*$/{m=1;next} /^\[/{m=0} m && /^[[:space:]]*Include[[:space:]]*=/{f=1} END{exit !f}' /etc/pacman.conf 2>/dev/null; then
        tmp_pac="$(mktemp)"
        awk '
            /^[[:space:]]*#?[[:space:]]*\[multilib\][[:space:]]*$/ { print "[multilib]"; in_m=1; done_inc=0; next }
            in_m && /^[[:space:]]*#?[[:space:]]*\[/ { in_m=0 }
            in_m && !done_inc && /^[[:space:]]*#[[:space:]]*Include[[:space:]]*=/ { sub(/^[[:space:]]*#[[:space:]]*/, ""); done_inc=1; print; next }
            { print }
        ' /etc/pacman.conf > "$tmp_pac" && install -m 0644 "$tmp_pac" /etc/pacman.conf
        rm -f "$tmp_pac"
    fi
fi
pacman -Sy --noconfirm

PKGS=()
if [[ "$INSTALL_PROFILE" == "completo" ]]; then
    mapfile -t PKGS < <({
        grep -Ev '^\s*(#|$)' "${REPO_ROOT}/packages/fase1-base.txt"
        grep -Ev '^\s*(#|$)' "${REPO_ROOT}/packages/fase2-desktop-terminal.txt"
    } | grep -Ev '^(linux|linux-headers|amd-ucode|intel-ucode)$' | awk '!seen[$0]++')
    PKGS+=("$KERNEL" "${KERNEL}-headers")
    [[ -n "$MICROCODE" ]] && PKGS+=("$MICROCODE")
else
    PKGS=(base "$KERNEL" "${KERNEL}-headers" linux-firmware btrfs-progs dosfstools cryptsetup snapper snap-pac rsync reflector zram-generator earlyoom sudo)
    [[ -n "$MICROCODE" ]] && PKGS+=("$MICROCODE")
    case "$NETWORK_CHOICE" in
        1) PKGS+=(iwd) ;;
        2) PKGS+=(networkmanager) ;;
        3) PKGS+=(wpa_supplicant dhcpcd) ;;
        4) PKGS+=(dhcpcd) ;;
        5) ;;
    esac
fi

if [[ "$BOOTLOADER" == "grub" ]]; then
    PKGS+=(grub grub-btrfs efibootmgr inotify-tools)
fi

pacstrap -K /mnt "${PKGS[@]}"

# 12. VM guest tools automáticos (KVM/VMware/VirtualBox/Hyper-V)
install_vm_guest_tools "$HYPERVISOR" /mnt

# 13. fstab, locale, teclado, usuário, pacman eye-candy e sudo
printf '\n[3/6] Configurando sistema, idioma (%s), teclado (%s) e usuário %s...\n' "$LOCALE_IN" "$KEYMAP_IN" "$USERNAME"
genfstab -U /mnt >> /mnt/etc/fstab
printf '%s\n' "$HOSTNAME_IN" > /mnt/etc/hostname
printf 'KEYMAP=%s\n' "$KEYMAP_IN" > /mnt/etc/vconsole.conf
printf 'LANG=%s\n' "$LOCALE_IN" > /mnt/etc/locale.conf

escaped_loc_mnt="$(sed 's/[][\\.^$*+?(){}|]/\\&/g' <<<"$LOCALE_IN")"
sed -i -E "s|^#(${escaped_loc_mnt}[[:space:]])|\1|; s|^#(en_US\.UTF-8[[:space:]])|\1|" /mnt/etc/locale.gen
printf '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 %s.localdomain %s\n' "$HOSTNAME_IN" "$HOSTNAME_IN" > /mnt/etc/hosts

# Copia multilib habilitado (se completo) e aplica Color/ILoveCandy/ParallelDownloads
if [[ "$INSTALL_PROFILE" == "completo" ]]; then
    install -m 0644 /etc/pacman.conf /mnt/etc/pacman.conf
fi
configure_pacman_eye_candy /mnt/etc/pacman.conf

USER_SHELL="/usr/bin/bash"
[[ "$INSTALL_PROFILE" == "completo" ]] && USER_SHELL="/usr/bin/fish"

arch-chroot /mnt /usr/bin/env EASYARCH_USER="$USERNAME" EASYARCH_TZ="$TZ_IN" EASYARCH_SHELL="$USER_SHELL" /bin/bash -euo pipefail <<'CHROOT_EOF'
ln -sf "/usr/share/zoneinfo/${EASYARCH_TZ}" /etc/localtime
hwclock --systohc
locale-gen
useradd -m -G wheel -s "${EASYARCH_SHELL}" "${EASYARCH_USER}"
printf '%s\n' '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-easyarch-wheel
chmod 0440 /etc/sudoers.d/10-easyarch-wheel
CHROOT_EOF
# Alimenta chpasswd via stdin literal (imune a $, ", ` ou \ na senha)
printf '%s:%s\nroot:%s\n' "$USERNAME" "$USER_PASS" "$ROOT_PASS" | arch-chroot /mnt chpasswd

# 14. Initramfs + parâmetros do kernel
printf '\n[4/6] Configurando initramfs e bootloader (%s)...\n' "$BOOTLOADER"
if (( USE_LUKS == 1 )); then
    sed -i 's/^HOOKS=(.*)/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' /mnt/etc/mkinitcpio.conf
    arch-chroot /mnt mkinitcpio -P
    PART_UUID="$(blkid -s UUID -o value "$PART_ROOT")"
    ROOT_CMDLINE="cryptdevice=UUID=${PART_UUID}:cryptroot root=/dev/mapper/cryptroot"
else
    ROOT_UUID="$(blkid -s UUID -o value "$ROOT_DEV")"
    ROOT_CMDLINE="root=UUID=${ROOT_UUID}"
fi

EXTRA_KPARAMS="zswap.enabled=0"
if [[ "$INSTALL_PROFILE" == "completo" ]]; then
    EXTRA_KPARAMS="lsm=landlock,lockdown,yama,integrity,apparmor,bpf zswap.enabled=0"
fi

# 15. Copia repositório EasyArch e aplica /etc + Snapper + Dotfiles (ou base minimalista)
printf '\n[5/6] Aplicando configurações de sistema, backup /boot e Snapper...\n'
mkdir -p /mnt/etc/pacman.d/hooks
install -m 0644 "${REPO_ROOT}/etc/pacman.d/hooks/50-bootbackup.hook" /mnt/etc/pacman.d/hooks/50-bootbackup.hook

mkdir -p "/mnt/home/${USERNAME}/easyarch"
tar --exclude='.git' -C "$REPO_ROOT" -cf - . | tar -C "/mnt/home/${USERNAME}/easyarch" -xf -
arch-chroot /mnt chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/easyarch"

if [[ "$INSTALL_PROFILE" == "completo" ]]; then
    arch-chroot /mnt "/home/${USERNAME}/easyarch/scripts/instalacao/easyarch-aplicar-etc.sh" --yes
    arch-chroot /mnt "/home/${USERNAME}/easyarch/scripts/instalacao/easyarch-configurar-snapper.sh"
    arch-chroot /mnt su - "${USERNAME}" -c "bash /home/${USERNAME}/easyarch/scripts/instalacao/02-instalar-configs-fase2.sh"
else
    install -m 0644 "${REPO_ROOT}/etc/systemd/zram-generator.conf" /mnt/etc/systemd/zram-generator.conf
    install -m 0644 "${REPO_ROOT}/etc/default/earlyoom" /mnt/etc/default/earlyoom
    arch-chroot /mnt "/home/${USERNAME}/easyarch/scripts/instalacao/easyarch-configurar-snapper.sh"
    case "$NETWORK_CHOICE" in
        1) systemctl enable iwd.service --root=/mnt >/dev/null 2>&1 || true ;;
        2) systemctl enable NetworkManager.service --root=/mnt >/dev/null 2>&1 || true ;;
        3)
            systemctl enable wpa_supplicant.service --root=/mnt >/dev/null 2>&1 || true
            systemctl enable dhcpcd.service --root=/mnt >/dev/null 2>&1 || true
            ;;
        4) systemctl enable dhcpcd.service --root=/mnt >/dev/null 2>&1 || true ;;
        5) ;;
    esac
    for svc in earlyoom.service reflector.timer fstrim.timer btrfs-scrub@-.timer; do
        systemctl enable "$svc" --root=/mnt >/dev/null 2>&1 || true
    done
fi

# 16. Instala bootloader após Snapper estar pronto (para grub-btrfs detectar snapshots)
if [[ "$BOOTLOADER" == "systemd-boot" ]]; then
    arch-chroot /mnt bootctl install
    cat > /mnt/boot/loader/loader.conf <<'EOF'
default easyarch.conf
timeout 3
console-mode max
editor no
EOF

    {
        printf 'title   EasyArch v5.5 (%s)\n' "$KERNEL"
        printf 'linux   /vmlinuz-%s\n' "$KERNEL"
        [[ -n "$MICROCODE" ]] && printf 'initrd  /%s.img\n' "$MICROCODE"
        printf 'initrd  /initramfs-%s.img\n' "$KERNEL"
        printf 'options %s rootflags=subvol=@ rw quiet %s\n' "$ROOT_CMDLINE" "$EXTRA_KPARAMS"
    } > /mnt/boot/loader/entries/easyarch.conf

    {
        printf 'title   EasyArch v5.5 (Recuperação — %s)\n' "$KERNEL"
        printf 'linux   /vmlinuz-%s\n' "$KERNEL"
        [[ -n "$MICROCODE" ]] && printf 'initrd  /%s.img\n' "$MICROCODE"
        printf 'initrd  /initramfs-%s-fallback.img\n' "$KERNEL"
        printf 'options %s rootflags=subvol=@ rw\n' "$ROOT_CMDLINE"
    } > /mnt/boot/loader/entries/easyarch-fallback.conf
else
    if (( USE_LUKS == 1 )); then
        append_grub_param /mnt/etc/default/grub GRUB_CMDLINE_LINUX "cryptdevice=UUID=${PART_UUID}:cryptroot root=/dev/mapper/cryptroot"
    fi
    append_grub_param /mnt/etc/default/grub GRUB_CMDLINE_LINUX_DEFAULT "$EXTRA_KPARAMS"
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=EasyArch
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    systemctl enable grub-btrfsd.service --root=/mnt >/dev/null 2>&1 || true
fi

printf '\n[6/6] Finalizando...\n'
unset USER_PASS USER_PASS2 ROOT_PASS ROOT_PASS2 LUKS_PASS LUKS_PASS2
printf '\n====================================================================\n'
printf ' [SUCESSO] EasyArch v5.5 instalado com segurança!\n'
printf ' Remova o pendrive e reinicie com: reboot\n'
if [[ "$INSTALL_PROFILE" == "completo" ]]; then
    printf ' No primeiro login, o Hyprland Glacial HUD abrirá automaticamente.\n'
    printf ' Para instalar Wine/Steam/Dev depois, rode: ~/easyarch/scripts/instalacao/easyarch-setup.sh\n'
else
    printf ' Modo Base Minimalista instalado. Você pode aplicar o Glacial HUD depois com:\n'
    printf '   ~/easyarch/scripts/instalacao/easyarch-setup.sh\n'
fi
printf '====================================================================\n'
