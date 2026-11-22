#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Loja Curada de Aplicativos em 1 Clique (`easyarch loja`)
# Destino: ~/.local/bin/easyarch-loja.sh
#
# Correções v4.5:
#   - Passa label, tipo e pacote via argumentos posicionais (`argv`) para o
#     `footclient -e bash -lc`, evitando perda de env vars no IPC do `foot --server`
#     e eliminando uso de `eval`.
#   - Checagem resiliente do daemon `foot --server` via `id -u` e regex `-f`.
# ==============================================================================

set -uo pipefail

CATALOG=(
    "Firefox (Navegador isolado Flatpak)|flatpak|org.mozilla.firefox"
    "Bottles (Programas Windows isolados)|flatpak|com.usebottles.bottles"
    "Flatseal (Controlar permissões de apps)|flatpak|com.github.tchx84.Flatseal"
    "ProtonUp-Qt (Instalar Proton-GE p/ jogos)|flatpak|net.davidotek.pupgui2"
    "Prism Launcher (Minecraft 1.20.1 / Fabric)|flatpak|org.prismlauncher.PrismLauncher"
    "LibreOffice (Textos e Planilhas)|flatpak|org.libreoffice.LibreOffice"
    "mpv (Reprodutor de Vídeos ultra-leve)|pacman|mpv"
    "GIMP (Editor de Imagens)|flatpak|org.gimp.GIMP"
    "OBS Studio (Gravação de Tela)|flatpak|com.obsproject.Studio"
    "Vesktop (Discord leve p/ Wayland)|flatpak|dev.vencord.Vesktop"
    "Steam (Jogos Windows via Proton)|pacman|steam"
    "VS Code Open Source (Code - OSS)|pacman|code"
)

pick_foot() {
    if command -v footclient >/dev/null 2>&1 && pgrep -u "$(id -u)" -f '(^|/)foot([[:space:]]|$).*--server' >/dev/null 2>&1; then
        printf 'footclient'
    elif command -v foot >/dev/null 2>&1; then
        printf 'foot'
    else
        printf ''
    fi
}

choose_app() {
    local labels=()
    local item
    for item in "${CATALOG[@]}"; do
        labels+=("${item%%|*}")
    done
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v rofi >/dev/null 2>&1; then
        printf '%s\n' "${labels[@]}" | rofi -dmenu -i -no-custom -p "Loja EasyArch"
    else
        printf '=== LOJA CURADA EASYARCH (Apps Testados p/ 6 GB RAM) ===\n' >&2
        local i=1 l
        for l in "${labels[@]}"; do printf '  %2d) %s\n' "$i" "$l" >&2; i=$((i+1)); done
        read -r -p "Digite o número do app (1-${#labels[@]}, ou Enter para sair): " n
        if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#labels[@]} )); then
            printf '%s\n' "${labels[$((n - 1))]}"
        fi
    fi
}

selected="$(choose_app)"
[[ -z "$selected" ]] && exit 0

for item in "${CATALOG[@]}"; do
    IFS='|' read -r label kind pkg <<< "$item"
    if [[ "$label" == "$selected" ]]; then
        if [[ "$kind" == "pacman" && "$pkg" == "steam" ]] && ! awk '/^\[multilib\][[:space:]]*$/{m=1;next} /^\[/{m=0} m && /^[[:space:]]*Include[[:space:]]*=/{f=1} END{exit !f}' /etc/pacman.conf 2>/dev/null; then
            msg="Steam requer o repositório [multilib] habilitado em /etc/pacman.conf. Rode ./scripts/instalacao/easyarch-setup.sh primeiro."
            [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v notify-send >/dev/null 2>&1 && notify-send "EasyArch Loja" "$msg" || true
            printf '[ERRO] %s\n' "$msg" >&2
            exit 1
        fi
        if [[ "$kind" == "flatpak" ]] && ! command -v flatpak >/dev/null 2>&1; then
            msg="Flatpak não instalado. Rode ./scripts/instalacao/easyarch-setup.sh (Etapa 2/4) ou sudo pacman -S flatpak."
            [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v notify-send >/dev/null 2>&1 && notify-send "EasyArch Loja" "$msg" || true
            printf '[ERRO] %s\n' "$msg" >&2
            exit 1
        fi

        term=""
        if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
            term="$(pick_foot)"
        fi

        if [[ -n "$term" ]]; then
            "$term" --title="Loja EasyArch — ${pkg}" -e bash -lc '
                label="$1"; kind="$2"; pkg="$3"; rc=0
                printf "Instalando: %s\n\n" "$label"
                if [[ "$kind" == "flatpak" ]]; then
                    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo                         && flatpak install --user -y flathub "$pkg" || rc=$?
                else
                    sudo pacman -S --needed "$pkg" || rc=$?
                fi
                echo ""
                if (( rc == 0 )); then
                    read -n 1 -r -p "[OK] Concluído! Pressione qualquer tecla para fechar..."
                else
                    read -n 1 -r -p "[ERRO] Falha na instalação (código ${rc}). Pressione qualquer tecla para fechar..."
                fi
                exit "$rc"
            ' _ "$label" "$kind" "$pkg"
        else
            printf 'Instalando: %s\n' "$label"
            if [[ "$kind" == "flatpak" ]]; then
                flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo                     && flatpak install --user -y flathub "$pkg"
            else
                sudo pacman -S --needed "$pkg"
            fi
        fi
        exit $?
    fi
done
