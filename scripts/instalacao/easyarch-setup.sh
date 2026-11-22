#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Assistente Guiado de Pós-Instalação (Com [multilib] Automático)
# Destino: scripts/instalacao/easyarch-setup.sh
#
# Correções v4.4:
#   - Limpa arquivos temporários com trap EXIT (não vaza em abortos via set -e).
#   - Sincroniza bancos (`pacman -Syu --needed`) na Etapa 0/4 para evitar erro em
#     instalações limpas com cache vazio/obsoleto.
# ==============================================================================

set -euo pipefail

SETUP_MODE=""
while [[ "${1:-}" == -* ]]; do
    case "$1" in
        --auto|--completo) SETUP_MODE="completo"; shift ;;
        --essencial)       SETUP_MODE="essencial"; shift ;;
        --personalizado)   SETUP_MODE="personalizado"; shift ;;
        -h|--help)
            cat <<'EOF'
EasyArch v5.4 — Assistente Guiado de Pós-Instalação
Uso:
  ./easyarch-setup.sh                 Menu rápido (1 Clique Completo / Essencial / Personalizado)
  ./easyarch-setup.sh --auto          Instala e configura tudo automaticamente (Fases 1–4)
  ./easyarch-setup.sh --essencial     Instala apenas Base + Desktop Glacial HUD (Fases 1–2)
  ./easyarch-setup.sh --personalizado Pergunta etapa por etapa
EOF
            exit 0
            ;;
        *) printf '[ERRO] Opção desconhecida: %s
' "$1" >&2; exit 1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TMP_FILES=()
PACMAN_SYNCED=0
cleanup_tmp() {
    if (( ${#TMP_FILES[@]} > 0 )); then
        rm -f "${TMP_FILES[@]}"
    fi
}
trap cleanup_tmp EXIT

ask_yes() {
    local prompt="$1"
    read -r -p "${prompt} (s/N): " ans
    [[ "${ans,,}" == "s" || "${ans,,}" == "sim" ]]
}

install_pkg_list() {
    local list_file="$1"
    local sync_flag="${2:-0}"
    local -a pkgs=()
    mapfile -t pkgs < <(grep -Ev '^\s*(#|$)' "$list_file")
    if (( ${#pkgs[@]} > 0 )); then
        if (( sync_flag == 1 || PACMAN_SYNCED == 0 )); then
            sudo pacman -Syu --needed "${pkgs[@]}"
            PACMAN_SYNCED=1
        else
            sudo pacman -S --needed "${pkgs[@]}"
        fi
    fi
}

is_multilib_enabled() {
    local cfg="${1:-/etc/pacman.conf}"
    awk '
        /^\[multilib\][[:space:]]*$/ { in_m=1; next }
        /^\[/ { in_m=0 }
        in_m && /^[[:space:]]*Include[[:space:]]*=/ { found=1 }
        END { exit !found }
    ' "$cfg" 2>/dev/null
}

ensure_multilib() {
    if is_multilib_enabled /etc/pacman.conf; then
        printf '[OK] Repositório [multilib] já está habilitado.\n'
        return 0
    fi
    printf '[ATENÇÃO] Os pacotes gráficos 32 bits (lib32-mesa/lib32-vulkan-radeon) exigem [multilib].\n'
    if (( ${auto_yes:-0} == 1 )) || ask_yes "Deseja habilitar [multilib] em /etc/pacman.conf (com backup) e rodar pacman -Syu?"; then
        local tmp_conf
        tmp_conf="$(mktemp)"
        TMP_FILES+=("$tmp_conf")
        sudo cp -a /etc/pacman.conf "/etc/pacman.conf.bak-$(date '+%Y%m%d-%H%M%S')"
        awk '
            /^[[:space:]]*#?[[:space:]]*\[multilib\][[:space:]]*$/ {
                print "[multilib]"
                in_m = 1; done_inc = 0
                next
            }
            in_m && /^[[:space:]]*#?[[:space:]]*\[/ {
                in_m = 0
            }
            in_m && !done_inc && /^[[:space:]]*#[[:space:]]*Include[[:space:]]*=/ {
                sub(/^[[:space:]]*#[[:space:]]*/, "")
                done_inc = 1
                print
                next
            }
            { print }
        ' /etc/pacman.conf > "$tmp_conf"
        if ! is_multilib_enabled "$tmp_conf"; then
            printf '[ERRO] Bloco #[multilib] não encontrado em /etc/pacman.conf. Habilite manualmente antes de continuar.\n' >&2
            return 1
        fi
        sudo install -m 0644 "$tmp_conf" /etc/pacman.conf
        sudo pacman -Syu
        PACMAN_SYNCED=1
        printf '[OK] [multilib] habilitado e sistema sincronizado.\n'
    else
        printf '[ERRO] Não é possível instalar pacotes lib32-* sem [multilib]. Abortando etapa.\n' >&2
        return 1
    fi
}

printf '====================================================================\n'
printf '          EasyArch v5.4 — Assistente Guiado de Configuração\n'
printf '   Hardware-alvo: Ryzen 5 3400G · Vega 11 · ~6 GB RAM Úteis\n'
printf '====================================================================\n\n'
printf 'Este assistente NÃO formata nem altera partições do disco.\n\n'

if [[ -z "$SETUP_MODE" ]]; then
    printf 'Escolha o modo de pós-instalação:\n'
    printf '  1) Completo em 1 Clique (Base + Glacial HUD + Wine/Flatpak + Dev + comando easyarch)\n'
    printf '  2) Essencial Ultra-Leve (Base + Desktop Glacial HUD + comando easyarch)\n'
    printf '  3) Personalizado (escolher etapa por etapa)\n'
    read -r -p "Opção [1]: " sm_opt
    case "${sm_opt:-1}" in
        1) SETUP_MODE="completo" ;;
        2) SETUP_MODE="essencial" ;;
        3) SETUP_MODE="personalizado" ;;
        *) printf '[EasyArch] Cancelado.\n'; exit 0 ;;
    esac
fi

run_fase0=0; run_fase1=0; run_fase2=0; run_fase3=0; run_fase4=0; auto_yes=0
case "$SETUP_MODE" in
    completo)      run_fase0=1; run_fase1=1; run_fase2=1; run_fase3=1; run_fase4=1; auto_yes=1 ;;
    essencial)     run_fase0=1; run_fase1=1; run_fase4=1; auto_yes=1 ;;
    personalizado) auto_yes=0 ;;
esac

if (( run_fase0 == 1 )) || { (( auto_yes == 0 )) && ask_yes "0/4) Garantir pacotes base (Fase 1), aplicar /etc (ZRAM, earlyoom, nftables, DoT) e Snapper?"; }; then
    if (( auto_yes == 1 )) || ask_yes "     Instalar/confirmar pacotes de packages/fase1-base.txt agora?"; then
        install_pkg_list "${ROOT_DIR}/packages/fase1-base.txt" 1
    fi
    if (( auto_yes == 1 )); then
        sudo "${ROOT_DIR}/scripts/instalacao/easyarch-aplicar-etc.sh" --yes
        sudo "${ROOT_DIR}/scripts/instalacao/easyarch-kernel-params.sh" --yes || true
        sudo "${ROOT_DIR}/scripts/instalacao/easyarch-configurar-snapper.sh" || true
    else
        sudo "${ROOT_DIR}/scripts/instalacao/easyarch-aplicar-etc.sh"
        if ask_yes "     Adicionar lsm=apparmor e zswap.enabled=0 aos parâmetros do kernel (com backup)?"; then
            sudo "${ROOT_DIR}/scripts/instalacao/easyarch-kernel-params.sh" --yes
        fi
        if ask_yes "     Configurar Snapper Btrfs em / agora?"; then
            sudo "${ROOT_DIR}/scripts/instalacao/easyarch-configurar-snapper.sh"
        fi
    fi
fi

if (( run_fase1 == 1 )) || { (( auto_yes == 0 )) && ask_yes "1/4) Instalar pacotes oficiais e tema Glacial HUD (Hyprland + Waybar + SwayNC + Foot/Fish)?"; }; then
    ensure_multilib
    install_pkg_list "${ROOT_DIR}/packages/fase2-desktop-terminal.txt"
    "${ROOT_DIR}/scripts/instalacao/02-instalar-configs-fase2.sh"
    sudo pkgfile --update || true
    tldr --update || true
    systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service || true
fi

if (( run_fase2 == 1 )) || { (( auto_yes == 0 )) && ask_yes "2/4) Instalar camada híbrida (Flatpak, Bottles, Wine, Steam, Gamescope)?"; }; then
    ensure_multilib
    install_pkg_list "${ROOT_DIR}/packages/fase3-hibrido.txt"
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
    if (( auto_yes == 1 )) || ask_yes "     Instalar Bottles (Flatpak --user) para apps Windows isolados agora?"; then
        flatpak install --user -y flathub com.usebottles.bottles || true
    fi
    "${ROOT_DIR}/scripts/instalacao/03-instalar-fase3.sh"
fi

if (( run_fase3 == 1 )) || { (( auto_yes == 0 )) && ask_yes "3/4) Instalar ambiente Dev (Java 17/Gradle p/ ArcForge, Python, Node, ADB/scrcpy, Perfis)?"; }; then
    ensure_multilib   # a lista da Fase 4 inclui lib32-mangohud
    install_pkg_list "${ROOT_DIR}/packages/fase4-dev-mobile.txt"
    "${ROOT_DIR}/scripts/instalacao/04-instalar-fase4.sh"
fi

if (( run_fase4 == 1 )) || { (( auto_yes == 0 )) && ask_yes "4/4) Garantir comando único 'easyarch' e validadores em ~/.local/bin/?"; }; then
    mkdir -p "${HOME}/.local/bin"
    install -m 0755 "${ROOT_DIR}/scripts/easyarch.sh" "${HOME}/.local/bin/easyarch"
    install -m 0755 "${ROOT_DIR}/scripts/diagnostico/02-validar-fase1.sh" "${HOME}/.local/bin/02-validar-fase1.sh"
    install -m 0755 "${ROOT_DIR}/scripts/manutencao/01-relatorio-memoria.sh" "${HOME}/.local/bin/01-relatorio-memoria.sh"
    install -m 0755 "${ROOT_DIR}/scripts/qol/easyarch-sos.sh" "${HOME}/.local/bin/easyarch-sos.sh"
    install -m 0755 "${ROOT_DIR}/scripts/desktop/security-status.sh" "${HOME}/.local/bin/security-status.sh"
    install -m 0755 "${ROOT_DIR}/scripts/qol/easyarch-hub.sh" "${HOME}/.local/bin/easyarch-hub.sh"
    printf '[OK] Comando único "easyarch" pronto!\n'
fi
