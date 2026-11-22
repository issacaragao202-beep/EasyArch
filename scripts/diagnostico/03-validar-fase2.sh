#!/usr/bin/env bash
# ==============================================================================
# EasyArch — Script 03: Validação Pós-Instalação da Fase 2 (SOMENTE LEITURA)
# Verifica pilha gráfica AMD/Vulkan, PipeWire, Hyprland, Waybar, Dock, Rofi,
# Foot/Fish/Starship e mede RAM ociosa contra a meta (500-700 MB / exp. 400 MB).
# ==============================================================================

set -uo pipefail

PASS=0
WARN=0
FAIL=0

ok()   { printf '[OK]    %s\n' "$1"; PASS=$((PASS + 1)); }
warn() { printf '[AVISO] %s\n' "$1"; WARN=$((WARN + 1)); }
fail() { printf '[FALHA] %s\n' "$1"; FAIL=$((FAIL + 1)); }

printf '============================================================\n'
printf ' EasyArch — VALIDAÇÃO DA FASE 2 (%s)\n' "$(date -Is)"
printf '============================================================\n\n'

# 1. Sessão Wayland / Hyprland
if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
    ok "Sessão Wayland ativa."
else
    warn "XDG_SESSION_TYPE atual: '${XDG_SESSION_TYPE:-vazio}' (execute dentro do Hyprland)."
fi

if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors >/dev/null 2>&1; then
    ok "Hyprland respondendo via hyprctl."
    mon_out="$(hyprctl monitors 2>/dev/null || true)"
    if grep -qE '1920x1080@7[45]\.' <<<"$mon_out"; then
        ok "Modo 1920x1080@75Hz confirmado no monitor."
    else
        warn "Modo 1920x1080@75Hz não confirmado; verifique com 'hyprctl monitors'."
    fi
else
    warn "Hyprland não está em execução neste terminal."
fi

# 2. Vulkan RADV (Vega 11)
if command -v vulkaninfo >/dev/null 2>&1; then
    vk_out="$(vulkaninfo --summary 2>/dev/null || true)"
    if grep -qiE 'RADV|AMD' <<<"$vk_out"; then
        ok "Vulkan RADV (AMD) detectado."
    else
        fail "Vulkan RADV não detectado em vulkaninfo --summary."
    fi
else
    warn "vulkaninfo não encontrado (pacote vulkan-tools)."
fi

# 3. PipeWire / WirePlumber (aceita ativação sob demanda via socket)
for base in pipewire pipewire-pulse; do
    if systemctl --user is-active --quiet "${base}.service" 2>/dev/null || systemctl --user is-active --quiet "${base}.socket" 2>/dev/null; then
        ok "Serviço/socket de áudio ativo: ${base}"
    else
        fail "Serviço/socket de áudio INATIVO: ${base}"
    fi
done
if systemctl --user is-active --quiet wireplumber.service 2>/dev/null; then
    ok "Serviço de usuário ativo: wireplumber.service"
else
    fail "Serviço de usuário INATIVO: wireplumber.service"
fi

# 4. Processos gráficos leves esperados
for proc in waybar swaync nwg-dock-hyprland; do
    if (( ${#proc} > 15 )); then
        pgrep -u "$(id -u)" -f "(^|/)${proc}([[:space:]]|$)" >/dev/null 2>&1
    else
        pgrep -xu "$(id -u)" "$proc" >/dev/null 2>&1
    fi
    if (( $? == 0 )); then
        ok "Componente gráfico em execução: ${proc}"
    else
        warn "Componente gráfico não está em execução: ${proc}"
    fi
done

# 5. Ferramentas de terminal inteligente
for bin in foot fish starship fzf zoxide tldr pkgfile rofi; do
    if command -v "$bin" >/dev/null 2>&1; then
        ok "Binário instalado: ${bin}"
    else
        fail "Binário AUSENTE: ${bin}"
    fi
done

if command -v pay-respects >/dev/null 2>&1; then
    ok "Binário opcional AUR instalado: pay-respects"
else
    warn "pay-respects (AUR opcional) não instalado."
fi

# 6. Medição de RAM ociosa (MemTotal - MemAvailable)
mem_total_kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
mem_avail_kb="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"
used_mb="$(( (mem_total_kb - mem_avail_kb) / 1024 ))"
avail_mb="$(( mem_avail_kb / 1024 ))"

printf '\n--- Medição Real de Memória ---\n'
printf 'RAM efetivamente ocupada (Total - Available): %d MiB\n' "$used_mb"
printf 'RAM disponível (MemAvailable):                %d MiB\n' "$avail_mb"
if (( used_mb <= 450 )); then
    ok "Excelente: próximo da meta experimental de 400 MiB (${used_mb} MiB)."
elif (( used_mb <= 700 )); then
    ok "Dentro da meta realista de desktop ocioso 500–700 MiB (${used_mb} MiB)."
else
    warn "Acima de 700 MiB (${used_mb} MiB). Rode 01-relatorio-memoria.sh para inspecionar PSS."
fi

printf '\n============================================================\n'
printf ' RESUMO: OK=%d | AVISOS=%d | FALHAS=%d\n' "$PASS" "$WARN" "$FAIL"
printf '============================================================\n'

(( FAIL > 0 )) && exit 1
exit 0
