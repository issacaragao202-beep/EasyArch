#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Construtor Oficial de Imagem .ISO Bootável (via archiso)
# Destino: scripts/iso/06-construir-iso-archiso.sh
#
# Pré-requisitos (executar em um Arch Linux com acesso à internet):
#   sudo pacman -S --needed archiso
#
# Correções v4.4:
#   - Garante ~/.local/bin no PATH em Zsh (autologin root do releng), Bash e Fish
#     via /etc/profile.d/easyarch-path.sh e /root/.zprofile.
#   - Remove alias D-Bus dbus-org.freedesktop.network1.service e configs de
#     /etc/systemd/network do releng para evitar reativação do systemd-networkd.
#   - Valida explicitamente se [multilib] foi habilitado no pacman.conf da ISO.
#   - Inclui easyarch-sos.sh em /etc/skel/.local/bin e /root/.local/bin.
# ==============================================================================

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    printf '[ERRO] Execute com sudo: sudo %s\n' "$0" >&2
    exit 1
fi

if ! command -v mkarchiso >/dev/null 2>&1; then
    printf '[ERRO] Pacote "archiso" não instalado. Instale com: sudo pacman -S --needed archiso\n' >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_BASE="${EASYARCH_ISO_BUILD_DIR:-/var/tmp/build-easyarch-iso}"
PROFILE_DIR="${BUILD_BASE}/profile"
WORK_DIR="${BUILD_BASE}/work"
OUT_DIR="${BUILD_BASE}/out"

case "$(readlink -f -- "$BUILD_BASE" 2>/dev/null || echo "$BUILD_BASE")" in
    "${REPO_ROOT}"|"${REPO_ROOT}"/*)
        printf '[ERRO] EASYARCH_ISO_BUILD_DIR não pode ficar dentro do repositório (%s).\n' "$REPO_ROOT" >&2
        exit 1
        ;;
esac

printf '[EasyArch ISO] Preparando perfil baseado no releng oficial...\n'
rm -rf "$PROFILE_DIR" "$WORK_DIR"
mkdir -p "$BUILD_BASE" "$OUT_DIR"
cp -r /usr/share/archiso/configs/releng "$PROFILE_DIR"

# 1. Personaliza metadados da ISO em profiledef.sh
sed -i 's/^iso_name=.*/iso_name="easyarch"/' "${PROFILE_DIR}/profiledef.sh"
sed -i 's/^iso_label=.*/iso_label="EASYARCH_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"/' "${PROFILE_DIR}/profiledef.sh"
sed -i 's/^iso_publisher=.*/iso_publisher="EasyArch Project"/' "${PROFILE_DIR}/profiledef.sh"
sed -i 's/^iso_application=.*/iso_application="EasyArch v5.4 Live\/Install ISO (Ryzen 3400G \/ Vega 11)"/' "${PROFILE_DIR}/profiledef.sh"

# 2. Habilita e valida [multilib] no pacman.conf da ISO
awk '
    /^#\[multilib\]/ { sub(/^#/, ""); print; if (getline > 0) { sub(/^#/, ""); print } next }
    { print }
' "${PROFILE_DIR}/pacman.conf" > "${PROFILE_DIR}/pacman.conf.tmp"
if ! grep -qE '^\[multilib\]' "${PROFILE_DIR}/pacman.conf.tmp"; then
    printf '[ERRO] Falha ao habilitar [multilib] em %s/pacman.conf.\n' "$PROFILE_DIR" >&2
    exit 1
fi
mv "${PROFILE_DIR}/pacman.conf.tmp" "${PROFILE_DIR}/pacman.conf"

# 3. Adiciona pacotes essenciais do EasyArch (Fases 1 e 2) sem duplicatas
{
    cat "${PROFILE_DIR}/packages.x86_64"
    grep -Ev '^\s*(#|$)' "${REPO_ROOT}/packages/fase1-base.txt"
    grep -Ev '^\s*(#|$)' "${REPO_ROOT}/packages/fase2-desktop-terminal.txt"
} | awk '!seen[$0]++' > "${PROFILE_DIR}/packages.x86_64.tmp"
mv "${PROFILE_DIR}/packages.x86_64.tmp" "${PROFILE_DIR}/packages.x86_64"

# 4. Embute teclado ABNT2, PATH global para ~/.local/bin e repositório em /root/easyarch
mkdir -p "${PROFILE_DIR}/airootfs/etc/profile.d" "${PROFILE_DIR}/airootfs/root/easyarch"
printf 'KEYMAP=br-abnt2\n' > "${PROFILE_DIR}/airootfs/etc/vconsole.conf"
cat > "${PROFILE_DIR}/airootfs/etc/profile.d/easyarch-path.sh" <<'EOF'
case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) export PATH="${HOME}/.local/bin:${PATH}" ;;
esac
EOF
chmod 0644 "${PROFILE_DIR}/airootfs/etc/profile.d/easyarch-path.sh"
tar --exclude='.git' --exclude='relatorio-hardware-disco-*.txt' -C "${REPO_ROOT}" -cf - . | tar -C "${PROFILE_DIR}/airootfs/root/easyarch" -xf -

# 5. Embute configs de sistema EasyArch na Live ISO
mkdir -p "${PROFILE_DIR}/airootfs/etc/systemd/resolved.conf.d" \
         "${PROFILE_DIR}/airootfs/etc/systemd/journald.conf.d" \
         "${PROFILE_DIR}/airootfs/etc/systemd/coredump.conf.d" \
         "${PROFILE_DIR}/airootfs/etc/NetworkManager/conf.d" \
         "${PROFILE_DIR}/airootfs/etc/default" \
         "${PROFILE_DIR}/airootfs/etc/nftables.d" \
         "${PROFILE_DIR}/airootfs/etc/sysctl.d" \
         "${PROFILE_DIR}/airootfs/etc/modules-load.d" \
         "${PROFILE_DIR}/airootfs/etc/xdg/reflector" \
         "${PROFILE_DIR}/airootfs/etc/systemd/system/sysinit.target.wants" \
         "${PROFILE_DIR}/airootfs/etc/systemd/system/multi-user.target.wants"

cp -a "${REPO_ROOT}/etc/systemd/zram-generator.conf" "${PROFILE_DIR}/airootfs/etc/systemd/zram-generator.conf"
cp -a "${REPO_ROOT}/etc/default/earlyoom" "${PROFILE_DIR}/airootfs/etc/default/earlyoom"
cp -a "${REPO_ROOT}/etc/nftables.conf" "${PROFILE_DIR}/airootfs/etc/nftables.conf"
cp -a "${REPO_ROOT}/etc/nftables.d/00-base.nft" "${PROFILE_DIR}/airootfs/etc/nftables.d/00-base.nft"
cp -a "${REPO_ROOT}/etc/systemd/resolved.conf.d/." "${PROFILE_DIR}/airootfs/etc/systemd/resolved.conf.d/"
# Na Live ISO usa DoT opportunistic para não quebrar DNS em redes com portal cativo/bloqueio 853
sed -i 's/^DNSOverTLS=yes$/DNSOverTLS=opportunistic/' "${PROFILE_DIR}/airootfs/etc/systemd/resolved.conf.d/10-easyarch-dot.conf"
cp -a "${REPO_ROOT}/etc/systemd/journald.conf.d/." "${PROFILE_DIR}/airootfs/etc/systemd/journald.conf.d/"
cp -a "${REPO_ROOT}/etc/systemd/coredump.conf.d/." "${PROFILE_DIR}/airootfs/etc/systemd/coredump.conf.d/"
cp -a "${REPO_ROOT}/etc/NetworkManager/conf.d/." "${PROFILE_DIR}/airootfs/etc/NetworkManager/conf.d/"
cp -a "${REPO_ROOT}/etc/sysctl.d/." "${PROFILE_DIR}/airootfs/etc/sysctl.d/"
cp -a "${REPO_ROOT}/etc/modules-load.d/." "${PROFILE_DIR}/airootfs/etc/modules-load.d/"
cp -a "${REPO_ROOT}/etc/xdg/reflector/reflector.conf" "${PROFILE_DIR}/airootfs/etc/xdg/reflector/reflector.conf"
ln -sf /run/systemd/resolve/stub-resolv.conf "${PROFILE_DIR}/airootfs/etc/resolv.conf"

# Mantém SSH acessível na Live ISO (releng habilita sshd por padrão para instalação remota)
cat > "${PROFILE_DIR}/airootfs/etc/nftables.d/10-live-ssh.nft" <<'EOF'
table inet easyarch_filter {
    chain input {
        tcp dport 22 accept comment "releng live ssh"
    }
}
EOF

# Evita conflito entre NetworkManager e systemd-networkd/iwd herdados do releng (incluindo ativação D-Bus)
rm -f "${PROFILE_DIR}/airootfs/etc/systemd/system/multi-user.target.wants/systemd-networkd.service" \
      "${PROFILE_DIR}/airootfs/etc/systemd/system/multi-user.target.wants/iwd.service" \
      "${PROFILE_DIR}/airootfs/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service" \
      "${PROFILE_DIR}/airootfs/etc/systemd/system/sockets.target.wants/systemd-networkd.socket" \
      "${PROFILE_DIR}/airootfs/etc/systemd/system/dbus-org.freedesktop.network1.service"
rm -rf "${PROFILE_DIR}/airootfs/etc/systemd/network"

ln -sf /usr/lib/systemd/system/systemd-resolved.service \
    "${PROFILE_DIR}/airootfs/etc/systemd/system/sysinit.target.wants/systemd-resolved.service"
ln -sf /usr/lib/systemd/system/systemd-resolved.service \
    "${PROFILE_DIR}/airootfs/etc/systemd/system/dbus-org.freedesktop.resolve1.service"
ln -sf /usr/lib/systemd/system/NetworkManager-dispatcher.service \
    "${PROFILE_DIR}/airootfs/etc/systemd/system/dbus-org.freedesktop.nm-dispatcher.service"

for svc in NetworkManager.service nftables.service earlyoom.service; do
    ln -sf "/usr/lib/systemd/system/${svc}" "${PROFILE_DIR}/airootfs/etc/systemd/system/multi-user.target.wants/${svc}"
done

# 6. Monta /etc/skel completo (dotfiles + scripts ~/.local/bin + wallpaper) e replica em /root
SKEL="${PROFILE_DIR}/airootfs/etc/skel"
mkdir -p "${SKEL}/.config" "${SKEL}/.local/bin" "${SKEL}/.gradle"
for dir in hypr waybar nwg-dock-hyprland rofi swaync swayosd foot fish gtk-3.0 gtk-4.0; do
    mkdir -p "${SKEL}/.config/${dir}"
    cp -a "${REPO_ROOT}/config/${dir}/." "${SKEL}/.config/${dir}/"
done
cp -a "${REPO_ROOT}/config/starship.toml" "${SKEL}/.config/starship.toml"
cp -a "${REPO_ROOT}/config/chromium-flags.conf" "${SKEL}/.config/chromium-flags.conf"
cp -a "${REPO_ROOT}/config/electron-flags.conf" "${SKEL}/.config/electron-flags.conf"
cp -a "${REPO_ROOT}/config/gradle/gradle.properties.arcforge" "${SKEL}/.gradle/gradle.properties"

for s in \
    scripts/easyarch.sh \
    scripts/diagnostico/02-validar-fase1.sh \
    scripts/manutencao/01-relatorio-memoria.sh \
    scripts/desktop/security-status.sh \
    scripts/desktop/easyarch-launcher.sh \
    scripts/terminal/easyarch-ai-assistant.sh \
    scripts/qol/easyarch-hub.sh \
    scripts/qol/easyarch-cheatsheet.sh \
    scripts/qol/easyarch-wallpaper-glacial.sh \
    scripts/qol/easyarch-lite-mode.sh \
    scripts/qol/easyarch-update-safe.sh \
    scripts/qol/easyarch-welcome.sh \
    scripts/qol/easyarch-sos.sh \
    scripts/qol/easyarch-power.sh \
    scripts/qol/easyarch-rede.sh \
    scripts/qol/easyarch-loja.sh \
    scripts/qol/easyarch-zen.sh \
    scripts/qol/easyarch-calc.sh \
    scripts/qol/easyarch-theme.sh; do
    target_name="$(basename "$s")"
    [[ "$target_name" == "easyarch.sh" ]] && target_name="easyarch"
    install -m 0755 "${REPO_ROOT}/${s}" "${SKEL}/.local/bin/${target_name}"
done
HOME="$SKEL" "${SKEL}/.local/bin/easyarch-wallpaper-glacial.sh" >/dev/null || true

# Replica dotfiles e ~/.local/bin para /root (autologin Zsh do releng) sem sobrescrever /root/easyarch
for item in .config .local .gradle; do
    cp -a "${SKEL}/${item}" "${PROFILE_DIR}/airootfs/root/"
done
install -m 0755 "${REPO_ROOT}/scripts/instalacao/easyarch-instalar-iso.sh" "${PROFILE_DIR}/airootfs/root/.local/bin/easyarch-instalar"
cat >> "${PROFILE_DIR}/airootfs/root/.zprofile" <<'EOF'
# EasyArch v5.4: garante ~/.local/bin no PATH do autologin Zsh e exibe guia rápido
export PATH="${HOME}/.local/bin:${PATH}"
if [[ -t 1 ]]; then
    printf '
====================================================================
'
    printf '              EasyArch v5.4 — LIVE & INSTALL ISO
'
    printf '====================================================================
'
    printf '  • Instalar no computador (guiado):   easyarch-instalar
'
    printf '  • Conectar Wi-Fi antes de instalar:  nmtui
'
    printf '  • Diagnóstico sem tocar no disco:    /root/easyarch/scripts/diagnostico/01-diagnostico-hardware-disco.sh
'
    printf '====================================================================

'
fi
EOF

printf '[EasyArch ISO] Iniciando mkarchiso (pode levar 5-15 min dependendo da conexão)...\n'
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

ISO_FILE=""
shopt -s nullglob
for cand in "${OUT_DIR}"/easyarch-*.iso; do
    if [[ -z "$ISO_FILE" || "$cand" -nt "$ISO_FILE" ]]; then
        ISO_FILE="$cand"
    fi
done
shopt -u nullglob
if [[ -f "$ISO_FILE" ]]; then
    sha256sum "$ISO_FILE" > "${ISO_FILE}.sha256"
    printf '\n[SUCESSO] ISO gerada com sucesso:\n'
    printf '  Arquivo: %s\n' "$ISO_FILE"
    printf '  SHA-256: %s\n' "$(cat "${ISO_FILE}.sha256")"
    printf '\nPara gravar no pendrive (substitua /dev/sdX pelo dispositivo real após lsblk):\n'
    printf '  sudo dd bs=4M if="%s" of=/dev/sdX conv=fsync oflag=direct status=progress\n' "$ISO_FILE"
else
    printf '[ERRO] Nenhuma imagem .iso encontrada em %s\n' "$OUT_DIR" >&2
    exit 1
fi
