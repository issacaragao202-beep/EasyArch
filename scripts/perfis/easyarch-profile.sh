#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Perfis de Desempenho (Econômico, Equilibrado, Jogos, Dev)
# Destino: ~/.local/bin/easyarch-profile.sh
#
# Correções v4.4:
#   - Suporta energy_performance_preference (EPP) no driver amd-pstate-epp
#     (diferenciando realmente economico/equilibrado/dev/jogos no Ryzen 3400G).
#   - Respeita ~/.local/state/easyarch-lite-mode para não reativar animações
#     enquanto o Modo Ultra-Leve estiver ligado.
# ==============================================================================

set -euo pipefail

STATE_FILE="${HOME}/.local/state/easyarch-profile"
LITE_STATE_FILE="${HOME}/.local/state/easyarch-lite-mode"
mkdir -p "$(dirname "$STATE_FILE")"

set_epp() {
    local epp="$1"
    local avail_epp="/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_available_preferences"
    [[ -r "$avail_epp" ]] || return 0
    if grep -qw "$epp" "$avail_epp"; then
        if printf '%s\n' "$epp" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference >/dev/null 2>&1; then
            printf '[OK] EPP (amd-pstate-epp) ajustado para: %s\n' "$epp"
        fi
    fi
}

set_governor() {
    local gov="$1"
    local epp="$2"
    if [[ ! -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        printf '[AVISO] Interface cpufreq indisponível (ex.: VM); governador CPU não alterado.\n'
        return 0
    fi
    local avail_file="/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors"
    local avail_epp="/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_available_preferences"
    local has_epp=0
    [[ -r "$avail_epp" ]] && has_epp=1

    # Em acpi-cpufreq (ex.: Ryzen 5 3400G Zen+, sem EPP), "powersave" fixa o clock mínimo;
    # preferir "conservative" (ou "schedutil") para o perfil econômico e "ondemand"/"performance" quando diferenciado.
    if (( has_epp == 0 )) && [[ "$gov" == "powersave" && -r "$avail_file" ]]; then
        if grep -qw "conservative" "$avail_file"; then
            printf '[INFO] Driver sem EPP (ex.: acpi-cpufreq): usando "conservative" no perfil econômico em vez de travar clock mínimo com "powersave".\n'
            gov="conservative"
        elif grep -qw "schedutil" "$avail_file"; then
            printf '[INFO] Driver sem EPP (ex.: acpi-cpufreq): usando "schedutil" no perfil econômico.\n'
            gov="schedutil"
        fi
    fi

    if [[ -r "$avail_file" ]] && ! grep -qw "$gov" "$avail_file"; then
        if [[ "$gov" == "schedutil" ]] && grep -qw "powersave" "$avail_file"; then
            printf '[INFO] Driver CPU sem "schedutil" (ex.: amd-pstate-epp); usando "powersave" + EPP "%s".\n' "$epp"
            gov="powersave"
        elif [[ "$gov" == "ondemand" ]] && grep -qw "schedutil" "$avail_file"; then
            gov="schedutil"
        else
            printf '[AVISO] Governador "%s" indisponível (%s); mantendo atual.\n' "$gov" "$(cat "$avail_file")"
            set_epp "$epp"
            return 0
        fi
    fi
    if command -v cpupower >/dev/null 2>&1; then
        sudo cpupower frequency-set -g "$gov" >/dev/null
        printf '[OK] Governador CPU ajustado para: %s\n' "$gov"
    else
        printf '[AVISO] cpupower não instalado; governador não alterado.\n'
    fi
    set_epp "$epp"
}

set_hypr_fx() {
    local anim="$1"
    local lite_cur
    lite_cur="$(cat "$LITE_STATE_FILE" 2>/dev/null || echo off)"
    if [[ "$anim" == "1" && "$lite_cur" == "on" ]]; then
        printf '[INFO] Modo Ultra-Leve ativo: animações mantidas desligadas (use `easyarch leve off` para restaurar).\n'
        return 0
    fi
    if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors >/dev/null 2>&1; then
        hyprctl keyword animations:enabled "$anim" >/dev/null 2>&1 || true
        printf '[OK] Hyprland animations:enabled=%s\n' "$anim"
    fi
}

profile="${1:-status}"

case "$profile" in
    economico)
        set_governor powersave power
        set_hypr_fx 1
        printf 'economico\n' > "$STATE_FILE"
        ;;
    equilibrado)
        set_governor schedutil balance_power
        set_hypr_fx 1
        printf 'equilibrado\n' > "$STATE_FILE"
        ;;
    jogos)
        set_governor performance performance
        set_hypr_fx 0
        printf 'jogos\n' > "$STATE_FILE"
        printf '[DICA] Use gamescope + RADV; compare 1080p nativo vs. FSR por jogo sem presumir ganho universal.\n'
        ;;
    dev)
        if [[ -r /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_available_preferences ]]; then
            set_governor schedutil balance_performance
        else
            set_governor ondemand balance_performance
        fi
        set_hypr_fx 1
        printf 'dev\n' > "$STATE_FILE"
        printf '[DICA] Para ArcForge (Java 17), rode:\n'
        printf '       Fish: source ~/.local/bin/easyarch-arcforge-env.fish\n'
        printf '       Bash: source ~/.local/bin/easyarch-arcforge-env.sh\n'
        ;;
    status)
        printf 'Perfil registrado: %s\n' "$(cat "$STATE_FILE" 2>/dev/null || echo equilibrado)"
        if [[ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
            printf 'Governador CPU atual: %s\n' "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
        fi
        if [[ -r /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference ]]; then
            printf 'EPP atual:            %s\n' "$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference)"
        fi
        ;;
    *)
        printf 'Uso: easyarch-profile.sh {economico|equilibrado|jogos|dev|status}\n' >&2
        exit 1
        ;;
esac
