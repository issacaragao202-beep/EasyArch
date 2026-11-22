#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Instalador Não Destrutivo de Dotfiles + QoL (Usuário)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BACKUP_DIR="${HOME}/.config-backup-$(date '+%Y%m%d-%H%M%S')"

log() { printf '[EasyArch v5.4] %s\n' "$1"; }

backup_if_exists() {
    local target="$1"
    if [[ -e "$target" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp -a "$target" "$BACKUP_DIR/"
        log "Backup salvo de $(basename "$target") em ${BACKUP_DIR}"
    fi
}

configure_waybar_temp_sensor() {
    local wb_cfg="${HOME}/.config/waybar/config.jsonc"
    [[ -f "$wb_cfg" ]] || return 0
    grep -q '"hwmon-path-abs"' "$wb_cfg" && return 0

    local h name dev_path hwmon_abs="" fallback_hwmon=""
    for h in /sys/class/hwmon/hwmon*; do
        [[ -r "${h}/name" && -r "${h}/temp1_input" ]] || continue
        name="$(cat "${h}/name" 2>/dev/null || true)"
        dev_path="$(readlink -f "${h}/device" 2>/dev/null || true)"
        if [[ "$name" == "k10temp" || "$name" == "coretemp" ]]; then
            if [[ -n "$dev_path" && -d "${dev_path}/hwmon" ]]; then
                hwmon_abs="${dev_path}/hwmon"
                break
            fi
        elif [[ -z "$fallback_hwmon" && -n "$dev_path" && -d "${dev_path}/hwmon" ]]; then
            fallback_hwmon="${dev_path}/hwmon"
        fi
    done

    hwmon_abs="${hwmon_abs:-$fallback_hwmon}"
    if [[ -n "$hwmon_abs" ]]; then
        local tmp_wb
        tmp_wb="$(mktemp)"
        awk -v hp="$hwmon_abs" '
            /"temperature": \{/ {
                print
                print "    \"hwmon-path-abs\": \"" hp "\","
                print "    \"input-filename\": \"temp1_input\","
                next
            }
            { print }
        ' "$wb_cfg" > "$tmp_wb" && mv "$tmp_wb" "$wb_cfg"
        log "Sensor de temperatura configurado na Waybar: ${hwmon_abs}/temp1_input"
    else
        log "Nenhum sensor hwmon detectado (ex.: VM sem sensor térmico); Waybar usará zona padrão."
    fi
}

mkdir -p "${HOME}/.config" "${HOME}/.local/bin"

for dir in hypr waybar nwg-dock-hyprland rofi swaync swayosd foot fish gtk-3.0 gtk-4.0; do
    backup_if_exists "${HOME}/.config/${dir}"
    mkdir -p "${HOME}/.config/${dir}"
    cp -a "${ROOT_DIR}/config/${dir}/." "${HOME}/.config/${dir}/"
    log "Configuração aplicada: ~/.config/${dir}"
done

configure_waybar_temp_sensor

backup_if_exists "${HOME}/.config/starship.toml"
cp -a "${ROOT_DIR}/config/starship.toml" "${HOME}/.config/starship.toml"
backup_if_exists "${HOME}/.config/chromium-flags.conf"
cp -a "${ROOT_DIR}/config/chromium-flags.conf" "${HOME}/.config/chromium-flags.conf"
backup_if_exists "${HOME}/.config/electron-flags.conf"
cp -a "${ROOT_DIR}/config/electron-flags.conf" "${HOME}/.config/electron-flags.conf"

for s in \
    scripts/easyarch.sh \
    scripts/diagnostico/02-validar-fase1.sh \
    scripts/diagnostico/03-validar-fase2.sh \
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
    install -m 0755 "${ROOT_DIR}/${s}" "${HOME}/.local/bin/${target_name}"
done


# Autostart do Hyprland no tty1 para quem usa bash como shell de login (fish já tem o bloco no config.fish)
install_bash_autostart() {
    local prof="${HOME}/.bash_profile"
    if [[ -f "$prof" ]] && grep -q '>>> easyarch-autostart >>>' "$prof"; then
        return 0
    fi
    if [[ -f "$prof" ]]; then
        backup_if_exists "$prof"
    else
        printf '[[ -f ~/.bashrc ]] && . ~/.bashrc\n' > "$prof"
    fi
    cat >> "$prof" <<'EOT'

# >>> easyarch-autostart >>>
case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) export PATH="${HOME}/.local/bin:${PATH}" ;;
esac
# Inicia o Hyprland ao logar no tty1. Para desativar: touch ~/.config/easyarch/no-autostart
if [[ -z "${WAYLAND_DISPLAY:-}" && -z "${DISPLAY:-}" && "$(tty 2>/dev/null)" == /dev/tty1 && ! -e "$HOME/.config/easyarch/no-autostart" ]]; then
    if command -v start-hyprland >/dev/null 2>&1; then
        exec start-hyprland
    elif command -v Hyprland >/dev/null 2>&1; then
        exec Hyprland
    fi
fi
# <<< easyarch-autostart <<<
EOT
    log "Autostart do Hyprland (tty1) e PATH (~/.local/bin) adicionados em ~/.bash_profile"
}
install_bash_autostart

"${HOME}/.local/bin/easyarch-wallpaper-glacial.sh" || true
log "Instalação de usuário EasyArch v5.4 concluída. Use 'easyarch' ou SUPER + H."
