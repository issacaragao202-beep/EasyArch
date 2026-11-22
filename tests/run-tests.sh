#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.5 — Suíte de testes anti-regressão (sem root, sem pacman)
# Uso: ./tests/run-tests.sh
# Cobre: sintaxe e permissões, classificador de risco (52 casos) + extract_base_bin,
#        show_first_lines, easyarch-kernel-params.sh (glob, awk \a, GRUB #, fallback),
#        is_broad_user_dir (--mount-dir), flags -h/--no-net e -- em readlink,
#        exit 1 em subcomandos inválidos, SIGPIPE sob pipefail e pacotes/configs Arch.
# ==============================================================================

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); printf '[FALHOU] %s\n' "$1" >&2; }
check() { # check "descricao" comando...
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then pass; else fail "$desc"; fi
}

# ---------------------------------------------------------------- 1. sintaxe/permissões
while IFS= read -r -d '' f; do
    check "bash -n $f" bash -n "$f"
    mode="$(stat -c '%a' "$f" 2>/dev/null || echo 000)"
    [[ -x "$f" || "$mode" == *7* || "$mode" == *5* ]] && pass || fail "sem +x: $f (mode=$mode)"
done < <(find "$ROOT/easy-arch.sh" "$ROOT/scripts" "$ROOT/tests" -name '*.sh' -print0)

if command -v shellcheck >/dev/null 2>&1; then
    while IFS= read -r -d '' f; do
        check "shellcheck $f" shellcheck -S warning "$f"
    done < <(find "$ROOT/easy-arch.sh" "$ROOT/scripts" "$ROOT/tests" -name '*.sh' -print0)
fi

if command -v python3 >/dev/null 2>&1; then
    check "waybar config.jsonc é JSON válido" python3 -c "import json; json.load(open('$ROOT/config/waybar/config.jsonc'))"
fi

# ---------------------------------------------------------------- 2. classificador + extract_base_bin
AI="$ROOT/scripts/terminal/easyarch-ai-assistant.sh"
while IFS='|' read -r expected cmd; do
    [[ -z "${expected}" || "${expected}" == \#* ]] && continue
    got="$(bash "$AI" checar "$cmd" | sed -n 2p | sed 's/.*: //')"
    [[ "$got" == "$expected" ]] && pass || fail "classificador: '$cmd' esperado=$expected obtido=$got"
done < "$ROOT/tests/classifier-cases.txt"

eb_semi="$(bash -c 'source <(sed -n "/^extract_base_bin()/,/^}/p" "'"$AI"'"); extract_base_bin "ls; rm -rf /"')"
[[ "$eb_semi" == "ls" ]] && pass || fail "extract_base_bin com ';': obtido='$eb_semi'"

eb_envs="$(bash -c 'source <(sed -n "/^extract_base_bin()/,/^}/p" "'"$AI"'"); extract_base_bin "env -S \"python3 -u\" script.py"')"
[[ "$eb_envs" == "python3" ]] && pass || fail "extract_base_bin com env -S: obtido='$eb_envs'"

# ---------------------------------------------------------------- 3. show_first_lines (SIGPIPE + head)
# shellcheck disable=SC1091
source "$ROOT/scripts/easyarch.sh"
gen_many() { seq 1 5000; }
gen_none() { return 1; }
out="$(show_first_lines 20 gen_many)"
[[ "$(printf '%s\n' "$out" | wc -l)" -eq 20 ]] && pass || fail "show_first_lines deve limitar a 20 linhas"
[[ "$out" != *"Nenhum resultado"* ]] && pass || fail "show_first_lines: falso 'Nenhum resultado' com saída longa"
[[ "$(show_first_lines 20 gen_none)" == "Nenhum resultado." ]] && pass || fail "show_first_lines: saída vazia deve avisar"

# ---------------------------------------------------------------- 4. kernel params (caminho feliz + bordas v4.7)
KP="$ROOT/scripts/instalacao/easyarch-kernel-params.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/boot/loader/entries" "$T/etc/default" "$T/etc/kernel" "$T/cwd"
printf 'title Arch\noptions root=UUID=abc rw quiet lsm=capability zswap.enabled=1\n' > "$T/boot/loader/entries/arch.conf"
printf 'title Arch fb\noptions root=UUID=abc rw\n' > "$T/boot/loader/entries/arch-fallback.conf"
printf 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash" # comentario\n' > "$T/etc/default/grub"
printf 'root=UUID=abc rw\n' > "$T/etc/kernel/cmdline"
export EASYARCH_SKIP_ROOT_CHECK=1 EASYARCH_BOOT_DIRS="$T/boot" EASYARCH_ETC_DIR="$T/etc" EASYARCH_BACKUP_DIR="$T/bk"

before="$(cat "$T/boot/loader/entries/arch.conf")"
bash "$KP" --dry-run >/dev/null 2>&1
[[ "$(cat "$T/boot/loader/entries/arch.conf")" == "$before" ]] && pass || fail "kernel-params --dry-run não pode alterar arquivos"

bash "$KP" --yes >/dev/null 2>&1
grep -q '^options root=UUID=abc rw quiet lsm=landlock,lockdown,yama,integrity,apparmor,bpf zswap.enabled=0$' "$T/boot/loader/entries/arch.conf" && pass || fail "kernel-params: entrada systemd-boot incorreta"
! grep -q 'lsm=capability\|zswap.enabled=1' "$T/boot/loader/entries/arch.conf" && pass || fail "kernel-params: valores antigos devem ser substituídos"
grep -q '^options root=UUID=abc rw$' "$T/boot/loader/entries/arch-fallback.conf" && pass || fail "kernel-params: entrada fallback deve ser ignorada"
grep -q 'lsm=landlock' "$T/etc/kernel/cmdline" && pass || fail "kernel-params: /etc/kernel/cmdline"
grep -q '^GRUB_CMDLINE_LINUX_DEFAULT="quiet splash lsm=landlock,lockdown,yama,integrity,apparmor,bpf zswap.enabled=0" # comentario$' "$T/etc/default/grub" && pass || fail "kernel-params: GRUB deve preservar comentário e aspas"
[[ -f "$T/bk$T/boot/loader/entries/arch.conf" ]] && pass || fail "kernel-params: backup ausente"

snap="$(cat "$T/boot/loader/entries/arch.conf")"
bash "$KP" --yes >/dev/null 2>&1
[[ "$(cat "$T/boot/loader/entries/arch.conf")" == "$snap" ]] && pass || fail "kernel-params deve ser idempotente"
[[ "$(grep -o 'zswap.enabled=0' "$T/boot/loader/entries/arch.conf" | wc -l)" -eq 1 ]] && pass || fail "kernel-params: parâmetro duplicado"

# 4b. Bordas v4.7: glob *, barra invertida \a, GRUB vazio, pasta pai com 'fallback'
mkdir -p "$T/fallback-env/boot/loader/entries" "$T/fallback-env/etc/default" "$T/fallback-env/bk"
touch "$T/cwd/INJETADO_1" "$T/cwd/INJETADO_2"
printf 'title Arch\noptions root=UUID=abc dyndbg="file * +p" initrd=\\amd-ucode.img\n' > "$T/fallback-env/boot/loader/entries/arch.conf"
printf 'GRUB_CMDLINE_LINUX_DEFAULT=""\n' > "$T/fallback-env/etc/default/grub"
(cd "$T/cwd" && EASYARCH_BOOT_DIRS="$T/fallback-env/boot" EASYARCH_ETC_DIR="$T/fallback-env/etc" EASYARCH_BACKUP_DIR="$T/fallback-env/bk" bash "$KP" --yes >/dev/null 2>&1)
grep -qF 'dyndbg="file * +p" initrd=\amd-ucode.img' "$T/fallback-env/boot/loader/entries/arch.conf" && pass || fail "kernel-params: corrompeu glob * ou \\amd-ucode.img ou pulou pasta pai 'fallback'"
grep -q '^GRUB_CMDLINE_LINUX_DEFAULT="lsm=landlock' "$T/fallback-env/etc/default/grub" && pass || fail "kernel-params: GRUB vazio não deve ter espaço inicial"

EASYARCH_BOOT_DIRS="$T/vazio" EASYARCH_ETC_DIR="$T/vazio" bash "$KP" --yes >/dev/null 2>&1
[[ $? -ne 0 ]] && pass || fail "kernel-params deve falhar sem bootloader detectado"

# ---------------------------------------------------------------- 5. flags -h / --no-net / exit 1 subcomando inválido
for s in scripts/sandbox/easyarch-appimage-sandbox.sh scripts/windows/easyarch-win-run.sh; do
    bash "$ROOT/$s" -h 2>&1 | grep -q 'Uso:' && pass || fail "-h em $s"
done
bash "$ROOT/scripts/sandbox/easyarch-appimage-sandbox.sh" -h 2>&1 | grep -q -- '--no-net' && pass || fail "--no-net ausente na ajuda do sandbox"
[[ "$(grep -c -- '--no-net' "$ROOT/scripts/sandbox/easyarch-appimage-sandbox.sh")" -ge 4 ]] && pass || fail "--no-net inconsistente nas mensagens de uso do sandbox"

for s in scripts/terminal/easyarch-ai-assistant.sh scripts/android/easyarch-waydroid.sh scripts/dev/easyarch-agents.sh scripts/mobile/easyarch-phone.sh scripts/easyarch.sh; do
    bash "$ROOT/$s" __subcomando_invalido__ >/dev/null 2>&1
    [[ $? -ne 0 ]] && pass || fail "$s retornou exit 0 para subcomando inválido"
done

# ---------------------------------------------------------------- 6. is_broad_user_dir (Wine --mount-dir)
mkdir -p "$T/h/.config/google-chrome" "$T/h/.local/share/keyrings" "$T/h/.password-store" "$T/h/.aws" "$T/h/app-ok"
for sens in "$T/h/.config/google-chrome" "$T/h/.local/share/keyrings" "$T/h/.password-store" "$T/h/.aws"; do
    HOME="$T/h" bash -c 'source <(sed -n "/^is_broad_user_dir()/,/^}/p" "'"$ROOT"'/scripts/windows/easyarch-win-run.sh"); is_broad_user_dir "'"$sens"'"' \
        && pass || fail "is_broad_user_dir deve bloquear $sens"
done
HOME="$T/h" bash -c 'source <(sed -n "/^is_broad_user_dir()/,/^}/p" "'"$ROOT"'/scripts/windows/easyarch-win-run.sh"); ! is_broad_user_dir "'"$T/h/app-ok"'"' \
    && pass || fail "is_broad_user_dir não deve bloquear subpasta dedicada app-ok"

# ---------------------------------------------------------------- 7. pacotes e configs Arch v4.7
grep -q '^pavucontrol$' "$ROOT/packages/fase2-desktop-terminal.txt" && pass || fail "pavucontrol deve estar na Fase 2"
grep -q '^libappindicator$' "$ROOT/packages/fase2-desktop-terminal.txt" && pass || fail "libappindicator deve estar na Fase 2 (udiskie --appindicator)"
grep -q '^reflector$' "$ROOT/packages/fase1-base.txt" && pass || fail "reflector deve estar na Fase 1"
grep -q '^\[colors-dark\]$' "$ROOT/config/foot/foot.ini" && pass || fail "foot.ini deve usar [colors-dark] (Foot 1.26+)"
grep -q 'set -l cur_tty' "$ROOT/config/fish/config.fish" && pass || fail "config.fish deve proteger tty sem TTY"

# ---------------------------------------------------------------- 8. regressões v4.8
# 8a. 20-waydroid.nft aplicado pelo easyarch-aplicar-etc.sh e reload sem flush global
grep -q 'etc/nftables.d/20-waydroid.nft' "$ROOT/scripts/instalacao/easyarch-aplicar-etc.sh" && pass || fail "easyarch-aplicar-etc.sh deve instalar 20-waydroid.nft"
grep -q 'systemctl reload "\$svc"' "$ROOT/scripts/instalacao/easyarch-aplicar-etc.sh" && pass || fail "easyarch-aplicar-etc.sh deve usar reload para nftables.service"

# 8b. BUILD_BASE em /var/tmp (não /tmp tmpfs)
grep -q '/var/tmp/build-easyarch-iso' "$ROOT/scripts/iso/06-construir-iso-archiso.sh" && pass || fail "06-construir-iso-archiso.sh deve usar /var/tmp por padrão"

# 8c. fstab comentado com espaços antes de '#' não pode casar como ativo no Snapper
printf '  # UUID=abc /.snapshots btrfs subvol=@snapshots 0 0\n' > "$T/fstab_comm"
! grep -qE '^[[:space:]]*[^#[:space:]].*[[:space:]]/\.snapshots([[:space:]]|$)' "$T/fstab_comm" && pass || fail "regex fstab do Snapper casou linha comentada com espaço inicial"
printf 'UUID=abc /.snapshots btrfs subvol=@snapshots 0 0\n' > "$T/fstab_ok"
grep -qE '^[[:space:]]*[^#[:space:]].*[[:space:]]/\.snapshots([[:space:]]|$)' "$T/fstab_ok" && pass || fail "regex fstab do Snapper falhou em linha ativa"

# 8d. 03-validar-fase2.sh aceita 74.97300 Hz e 75.00000 Hz
grep -qE '1920x1080@7\[45\]\\\.' "$ROOT/scripts/diagnostico/03-validar-fase2.sh" && pass || fail "03-validar-fase2.sh deve aceitar 74.97Hz e 75.00Hz"

# 8e. easyarch-phone.sh usa HostKeyAlias por serial
grep -q 'HostKeyAlias=termux-' "$ROOT/scripts/mobile/easyarch-phone.sh" && pass || fail "easyarch-phone.sh deve usar HostKeyAlias por serial"

# ---------------------------------------------------------------- 9. regressões v4.9
# 9a. cleanup_tmp de easyarch-setup.sh deve sair com 0 quando TMP_FILES está vazio
bash -c 'set -euo pipefail; TMP_FILES=(); source <(sed -n "/^cleanup_tmp()/,/^}/p" "'"$ROOT"'/scripts/instalacao/easyarch-setup.sh"); trap cleanup_tmp EXIT'     && pass || fail "cleanup_tmp retornou erro com TMP_FILES vazio"

# 9b. ensure_multilib awk com comentário intermediário entre #[multilib] e #Include
printf '#[multilib]\n# comentario extra\n#Include = /etc/pacman.d/mirrorlist\n' > "$T/pac_comm.conf"
awk '
    /^[[:space:]]*#?[[:space:]]*\[multilib\][[:space:]]*$/ { print "[multilib]"; in_m=1; done_inc=0; next }
    in_m && /^[[:space:]]*#?[[:space:]]*\[/ { in_m=0 }
    in_m && !done_inc && /^[[:space:]]*#[[:space:]]*Include[[:space:]]*=/ { sub(/^[[:space:]]*#[[:space:]]*/, ""); done_inc=1; print; next }
    { print }
' "$T/pac_comm.conf" > "$T/pac_comm.out"
grep -q '^Include = /etc/pacman.d/mirrorlist$' "$T/pac_comm.out" && grep -q '^# comentario extra$' "$T/pac_comm.out"     && pass || fail "awk multilib deve descomentar Include e preservar comentário intermediário"

# 9c. kernel-params deve limpar lsm= duplicado/conflitante mesmo se o lsm alvo já estiver presente
mkdir -p "$T/dup/boot/loader/entries" "$T/dup/bk"
printf 'title Arch\noptions root=UUID=abc lsm=capability lsm=landlock,lockdown,yama,integrity,apparmor,bpf zswap.enabled=0\n' > "$T/dup/boot/loader/entries/arch.conf"
EASYARCH_BOOT_DIRS="$T/dup/boot" EASYARCH_ETC_DIR="$T/vazio" EASYARCH_BACKUP_DIR="$T/dup/bk" bash "$KP" --yes >/dev/null 2>&1
! grep -q 'lsm=capability' "$T/dup/boot/loader/entries/arch.conf" && [[ "$(grep -o 'lsm=' "$T/dup/boot/loader/entries/arch.conf" | wc -l)" -eq 1 ]]     && pass || fail "kernel-params deve remover lsm= duplicado/conflitante"

# ---------------------------------------------------------------- 10. verificações v5.0 (Glacial HUD)
grep -q 'bindr = SUPER, SUPER_L' "$ROOT/config/hypr/hyprland.conf" && pass || fail "hyprland.conf deve abrir lançador ao tocar Super"
grep -q 'bind = ALT, Tab, cyclenext' "$ROOT/config/hypr/hyprland.conf" && pass || fail "hyprland.conf deve suportar Alt+Tab"
grep -q 'match:namespace = \^(rofi|waybar|swaync-control-center|swaync-notification-window|swayosd)\$' "$ROOT/config/hypr/hyprland.conf" && pass || fail "hyprland.conf deve usar layerrule bloco 0.53+"
grep -q 'pavucontrol' "$ROOT/config/waybar/config.jsonc" && pass || fail "waybar deve abrir pavucontrol no clique direito do volume"
grep -q 'easyarch-loja.sh' "$ROOT/scripts/qol/easyarch-hub.sh" && grep -q 'easyarch-rede.sh' "$ROOT/scripts/qol/easyarch-hub.sh"     && pass || fail "easyarch-hub.sh deve expor Loja e Wi-Fi no menu SUPER+H"
HOME="$T/wall_home" bash "$ROOT/scripts/qol/easyarch-wallpaper-glacial.sh" >/dev/null 2>&1     && python3 -c "import xml.etree.ElementTree as ET; ET.parse('$T/wall_home/.local/share/easyarch/wallpapers/glacial-silver-1080p.svg')"     && pass || fail "wallpaper SVG v5.0 inválido"

# ---------------------------------------------------------------- 11. verificações v5.1 (HUD sob demanda, 0 MB residente)
[[ "$(bash "$ROOT/scripts/qol/easyarch-calc.sh" --eval '2 + 3 * 4')" == "14" ]] && pass || fail "easyarch-calc.sh: 2 + 3 * 4 deve retornar 14"
[[ "$(bash "$ROOT/scripts/qol/easyarch-calc.sh" --eval 'sqrt(144)')" == "12" ]] && pass || fail "easyarch-calc.sh: sqrt(144) deve retornar 12"
! bash "$ROOT/scripts/qol/easyarch-calc.sh" --eval '__import__("os").system("id")' >/dev/null 2>&1 && pass || fail "easyarch-calc.sh deve bloquear execução arbitrária"

HOME="$T/zen_home" WAYLAND_DISPLAY="" bash "$ROOT/scripts/qol/easyarch-zen.sh" on >/dev/null 2>&1     && [[ "$(HOME="$T/zen_home" bash "$ROOT/scripts/qol/easyarch-zen.sh" status)" == "Modo Zen: on" ]]     && HOME="$T/zen_home" WAYLAND_DISPLAY="" bash "$ROOT/scripts/qol/easyarch-zen.sh" off >/dev/null 2>&1     && pass || fail "easyarch-zen.sh falhou no ciclo on/status/off"

mkdir -p "$T/th_home/.config/rofi" "$T/th_home/.config/waybar" "$T/th_home/.local/share/easyarch/wallpapers"
cp "$ROOT/config/rofi/glacial-silver.rasi" "$T/th_home/.config/rofi/"
cp "$ROOT/config/waybar/style.css" "$T/th_home/.config/waybar/"
HOME="$T/th_home" bash "$ROOT/scripts/qol/easyarch-wallpaper-glacial.sh" >/dev/null 2>&1
HOME="$T/th_home" WAYLAND_DISPLAY="" bash "$ROOT/scripts/qol/easyarch-theme.sh" amber >/dev/null 2>&1     && grep -q '#f59e0b' "$T/th_home/.config/rofi/glacial-silver.rasi"     && grep -q '245, 158, 11' "$T/th_home/.config/waybar/style.css"     && pass || fail "easyarch-theme.sh falhou ao aplicar paleta amber"
HOME="$T/th_home" bash "$ROOT/scripts/qol/easyarch-theme.sh" __invalida__ >/dev/null 2>&1
[[ $? -ne 0 ]] && pass || fail "easyarch-theme.sh deve retornar exit 1 para paleta inválida"

grep -q 'togglespecialworkspace, hud' "$ROOT/config/hypr/hyprland.conf" && pass || fail "hyprland.conf deve ter scratchpad HUD (SUPER+S)"
grep -q 'togglegroup' "$ROOT/config/hypr/hyprland.conf" && pass || fail "hyprland.conf deve ter grupos em abas (SUPER+G)"

# ---------------------------------------------------------------- 12. verificações v5.2 (SwayNC + SwayOSD + btop)
if command -v python3 >/dev/null 2>&1; then
    check "swaync config.json é JSON válido" python3 -c "import json; json.load(open('$ROOT/config/swaync/config.json'))"
fi
for pkg in swaync swayosd btop; do
    grep -q "^${pkg}$" "$ROOT/packages/fase2-desktop-terminal.txt" && pass || fail "pacote ${pkg} ausente na Fase 2"
done
grep -q 'swaync-client -t -sw' "$ROOT/config/hypr/hyprland.conf" && pass || fail "hyprland.conf deve ter atalho SUPER+N para SwayNC"
grep -q 'swayosd-server' "$ROOT/config/hypr/hyprland.conf" && pass || fail "hyprland.conf deve iniciar swayosd-server"

# ---------------------------------------------------------------- 13. verificações v5.3 (Instalador ISO + Pós-instalação 1 clique)
bash "$ROOT/scripts/instalacao/easyarch-instalar-iso.sh" -h 2>&1 | grep -q 'easyarch-instalar' && pass || fail "easyarch-instalar-iso.sh -h"
bash "$ROOT/scripts/instalacao/easyarch-setup.sh" -h 2>&1 | grep -q -- '--auto' && pass || fail "easyarch-setup.sh deve suportar --auto"
bash "$ROOT/scripts/instalacao/easyarch-aplicar-etc.sh" -h 2>&1 | grep -q -- '--yes' && pass || fail "easyarch-aplicar-etc.sh deve suportar --yes"
grep -q 'easyarch-instalar' "$ROOT/scripts/iso/06-construir-iso-archiso.sh" && pass || fail "ISO deve embutir comando easyarch-instalar"

# ---------------------------------------------------------------- 14. verificações v5.4
grep -q "<<'CHROOT_EOF'" "$ROOT/scripts/instalacao/easyarch-instalar-iso.sh" && pass || fail "easyarch-instalar-iso.sh deve usar heredoc citado <<'CHROOT_EOF'"
grep -q 'arch-chroot /mnt chpasswd' "$ROOT/scripts/instalacao/easyarch-instalar-iso.sh" && pass || fail "easyarch-instalar-iso.sh deve alimentar chpasswd via stdin literal"
! grep -q '"which swaync-client"' "$ROOT/config/waybar/config.jsonc" && grep -q '"command -v swaync-client"' "$ROOT/config/waybar/config.jsonc"     && pass || fail "waybar deve usar command -v swaync-client (sem depender de which)"
grep -q '^jq$' "$ROOT/packages/fase2-desktop-terminal.txt" && pass || fail "jq deve estar na Fase 2 (usado pelo zoom do Hyprland)"
grep -q 'auto_yes:-0' "$ROOT/scripts/instalacao/easyarch-setup.sh" && pass || fail "ensure_multilib deve respeitar auto_yes no modo 1 clique"
! bash "$ROOT/scripts/qol/easyarch-calc.sh" --eval '1/0' 2>&1 | grep -q 'Traceback' && pass || fail "easyarch-calc.sh --eval não deve expor Traceback"


# ---------------------------------------------------------------- 15. verificações v5.5 (Fusão EasyArch + easy-arch)
INST="$ROOT/scripts/instalacao/easyarch-instalar-iso.sh"
bash "$ROOT/easy-arch.sh" -h 2>&1 | grep -q 'easyarch-instalar' && pass || fail "easy-arch.sh -h deve delegar para easyarch-instalar"

printf 'vendor_id\t: AuthenticAMD\n' > "$T/cpu_amd"
printf 'vendor_id\t: GenuineIntel\n' > "$T/cpu_intel"
printf 'Hardware\t: Generic ARM\n' > "$T/cpu_arm"
[[ "$(bash -c 'source <(sed -n "/^detect_microcode()/,/^}/p" "'"$INST"'"); detect_microcode "'"$T/cpu_amd"'"')" == "amd-ucode" ]] && pass || fail "detect_microcode AMD"
[[ "$(bash -c 'source <(sed -n "/^detect_microcode()/,/^}/p" "'"$INST"'"); detect_microcode "'"$T/cpu_intel"'"')" == "intel-ucode" ]] && pass || fail "detect_microcode Intel"
[[ -z "$(bash -c 'source <(sed -n "/^detect_microcode()/,/^}/p" "'"$INST"'"); detect_microcode "'"$T/cpu_arm"'"')" ]] && pass || fail "detect_microcode genérico deve retornar vazio"

# detect_hypervisor não pode derrubar set -euo pipefail quando systemd-detect-virt retorna exit 1 (bare metal)
mkdir -p "$T/fakebin"
printf '#!/usr/bin/env bash\necho none\nexit 1\n' > "$T/fakebin/systemd-detect-virt"
chmod +x "$T/fakebin/systemd-detect-virt"
[[ "$(PATH="$T/fakebin:$PATH" bash -c 'set -euo pipefail; source <(sed -n "/^detect_hypervisor()/,/^}/p" "'"$INST"'"); detect_hypervisor')" == "none" ]] && pass || fail "detect_hypervisor falhou em bare metal (exit 1)"

# validate_network_choice corrige bug ((1 <= x <= 5)) do easy-arch
for ok_net in 1 2 3 4 5; do
    bash -c 'source <(sed -n "/^validate_network_choice()/,/^}/p" "'"$INST"'"); validate_network_choice "'"$ok_net"'"' && pass || fail "validate_network_choice deve aceitar $ok_net"
done
for bad_net in 0 6 99 abc ""; do
    ! bash -c 'source <(sed -n "/^validate_network_choice()/,/^}/p" "'"$INST"'"); validate_network_choice "'"$bad_net"'"' && pass || fail "validate_network_choice deve rejeitar '$bad_net'"
done

# validate_kernel_choice
[[ "$(bash -c 'source <(sed -n "/^validate_kernel_choice()/,/^}/p" "'"$INST"'"); validate_kernel_choice 3')" == "linux-zen" ]] && pass || fail "validate_kernel_choice 3 -> linux-zen"
! bash -c 'source <(sed -n "/^validate_kernel_choice()/,/^}/p" "'"$INST"'"); validate_kernel_choice 9' >/dev/null 2>&1 && pass || fail "validate_kernel_choice deve rejeitar 9"

# configure_pacman_eye_candy idempotente
printf '[options]\n#Color\n#ParallelDownloads = 5\n' > "$T/pacman.conf"
bash -c 'source <(sed -n "/^configure_pacman_eye_candy()/,/^}/p" "'"$INST"'"); configure_pacman_eye_candy "'"$T/pacman.conf"'"'
bash -c 'source <(sed -n "/^configure_pacman_eye_candy()/,/^}/p" "'"$INST"'"); configure_pacman_eye_candy "'"$T/pacman.conf"'"'
[[ "$(grep -c '^Color$' "$T/pacman.conf")" -eq 1 && "$(grep -c '^ILoveCandy$' "$T/pacman.conf")" -eq 1 && "$(grep -c '^ParallelDownloads = 5$' "$T/pacman.conf")" -eq 1 ]] && pass || fail "configure_pacman_eye_candy deve ser idempotente"

# append_grub_param preserva comentários e funciona com valor vazio ou preenchido
printf 'GRUB_CMDLINE_LINUX="" # vazio\nGRUB_CMDLINE_LINUX_DEFAULT="quiet" # padrao\n' > "$T/grub"
bash -c 'source <(sed -n "/^append_grub_param()/,/^}/p" "'"$INST"'"); append_grub_param "'"$T/grub"'" GRUB_CMDLINE_LINUX "cryptdevice=UUID=123:cryptroot"'
bash -c 'source <(sed -n "/^append_grub_param()/,/^}/p" "'"$INST"'"); append_grub_param "'"$T/grub"'" GRUB_CMDLINE_LINUX_DEFAULT "zswap.enabled=0"'
grep -q '^GRUB_CMDLINE_LINUX="cryptdevice=UUID=123:cryptroot" # vazio$' "$T/grub" && pass || fail "append_grub_param falhou em variável vazia"
grep -q '^GRUB_CMDLINE_LINUX_DEFAULT="quiet zswap.enabled=0" # padrao$' "$T/grub" && pass || fail "append_grub_param falhou em variável preenchida"

# Hook 50-bootbackup.hook, rsync, inotify-tools e btrfs-scrub único
[[ -f "$ROOT/etc/pacman.d/hooks/50-bootbackup.hook" ]] && pass || fail "50-bootbackup.hook ausente"
grep -q '^rsync$' "$ROOT/packages/fase1-base.txt" && pass || fail "rsync ausente em fase1-base.txt"
grep -q 'etc/pacman.d/hooks/50-bootbackup.hook' "$ROOT/scripts/instalacao/easyarch-aplicar-etc.sh" && pass || fail "easyarch-aplicar-etc.sh deve instalar 50-bootbackup.hook"
grep -q 'inotify-tools' "$INST" && pass || fail "modo GRUB deve instalar inotify-tools para grub-btrfsd"
! grep -q 'btrfs-scrub@home.timer' "$INST" && grep -q 'btrfs-scrub@-.timer' "$INST" && pass || fail "deve habilitar apenas btrfs-scrub@-.timer (sem scrubs concorrentes)"

# Teste end-to-end do --dry-run (determinístico com lsblk simulado: perfil completo e minimalista)
printf '#!/usr/bin/env bash\necho "/dev/sda 240G Kingston_A400 sata"\n' > "$T/fakebin/lsblk"
chmod +x "$T/fakebin/lsblk"
dry_out="$(PATH="$T/fakebin:$PATH" printf '1\n\n1\n1\n1\nusuario\nsenha123\nsenha123\nn\n\n\n\nn\n' | PATH="$T/fakebin:$PATH" bash "$INST" --dry-run 2>&1)"
grep -q '\[DRY-RUN\] Simulação concluída' <<<"$dry_out" && pass || fail "easyarch-instalar-iso.sh --dry-run (completo) falhou"
dry_min="$(printf '2\n\n1\n3\n2\n1\nusuario\nsenha123\nsenha123\nn\n\n\n\nn\n' | PATH="$T/fakebin:$PATH" bash "$INST" --dry-run 2>&1)"
grep -q 'GRUB + grub-btrfs' <<<"$dry_min" && grep -q 'linux-zen' <<<"$dry_min" && grep -q '\[DRY-RUN\] Simulação concluída' <<<"$dry_min" && pass || fail "easyarch-instalar-iso.sh --dry-run (minimal + GRUB + zen) falhou"


# Conformidade Apache 2.0 (easy-arch) e consistência LUKS (encrypt + cryptdevice=, sem misturar sd-encrypt)
[[ -f "$ROOT/LICENSE-APACHE-2.0" && -f "$ROOT/NOTICE" ]] && pass || fail "LICENSE-APACHE-2.0 e NOTICE obrigatórios"
grep -q 'classy-giraffe/easy-arch' "$ROOT/NOTICE" && pass || fail "NOTICE deve atribuir classy-giraffe/easy-arch"
grep -q 'block encrypt filesystems' "$INST" && grep -q 'cryptdevice=UUID=' "$INST" && ! grep -qE 'sd-encrypt|rd\.luks\.name' "$INST" && pass || fail "LUKS deve usar apenas encrypt + cryptdevice= sem misturar sd-encrypt/rd.luks.name"

printf '\nTestes: %d passaram, %d falharam.\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
