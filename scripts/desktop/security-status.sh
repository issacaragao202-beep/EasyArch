#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Indicador de Segurança para Waybar e Terminal
# Destino: ~/.local/bin/security-status.sh
#
# Uso:
#   security-status.sh          Saída JSON para o módulo custom/security da Waybar
#   security-status.sh --human  Saída legível para terminal (`easyarch seguranca`)
# ==============================================================================

set -uo pipefail

HUMAN_MODE=0
if [[ "${1:-}" == "--human" ]]; then
    HUMAN_MODE=1
fi

issues=()

if [[ -r /sys/kernel/security/lsm ]] && grep -q apparmor /sys/kernel/security/lsm; then
    aa="OK"
else
    aa="OFF"
    issues+=("AppArmor")
fi

if systemctl is-active --quiet nftables.service 2>/dev/null; then
    fw="OK"
else
    fw="OFF"
    issues+=("nftables")
fi

resolv_ok=0
if [[ -L /etc/resolv.conf ]] && readlink -f /etc/resolv.conf | grep -q 'stub-resolv\.conf'; then
    resolv_ok=1
elif [[ -r /etc/resolv.conf ]] && grep -q '^nameserver 127\.0\.0\.53' /etc/resolv.conf; then
    resolv_ok=1
fi

rstatus="$(resolvectl status 2>/dev/null || true)"
rglobal="$(awk '/^Global/{g=1; next} /^Link /{g=0} g{print}' <<<"$rstatus")"
[[ -z "$rglobal" ]] && rglobal="$rstatus"
dot_mode="off"
if grep -qiE 'DNSOverTLS setting:[[:space:]]*opportunistic|DNSOverTLS=opportunistic' <<<"$rglobal"; then
    dot_mode="opportunistic"
elif grep -qiE 'DNSOverTLS setting:[[:space:]]*yes|DNSOverTLS=yes' <<<"$rglobal"; then
    dot_mode="yes"
elif grep -q '+DNSOverTLS' <<<"$rglobal"      && ! grep -qiE 'DNSOverTLS setting:[[:space:]]*no|-DNSOverTLS' <<<"$rglobal"; then
    dot_mode="yes"
fi
if (( resolv_ok == 1 )) && systemctl is-active --quiet systemd-resolved.service 2>/dev/null; then
    if [[ "$dot_mode" == "yes" ]]; then
        dns="DoT-OK"
    elif [[ "$dot_mode" == "opportunistic" ]]; then
        dns="DoT-OPT"
        issues+=("DoT-opt")
    else
        dns="DoT-OFF"
        issues+=("DoT")
    fi
else
    dns="DoT-OFF"
    issues+=("DoT")
fi

if (( ${#issues[@]} == 0 )); then
    text="SEC OK"
    cls="secure"
    tooltip="AppArmor: ${aa} | nftables: ${fw} | DNS: ${dns} (resolv.conf verificado)"
elif (( ${#issues[@]} == 1 )); then
    text="SEC ! (${issues[0]})"
    cls="warning"
    tooltip="Pendente: ${issues[*]} | AppArmor: ${aa} | nftables: ${fw} | DNS: ${dns}"
else
    text="SEC ALERTA"
    cls="critical"
    tooltip="Camadas inativas: ${issues[*]}"
fi

if (( HUMAN_MODE == 1 )); then
    printf '=== EasyArch v5.4 — Status de Segurança ===\n'
    printf '  Resumo:   %s\n' "$text"
    printf '  AppArmor: %s\n' "$aa"
    printf '  nftables: %s\n' "$fw"
    printf '  DNS DoT:  %s\n' "$dns"
    if (( ${#issues[@]} > 0 )); then
        printf '  Pendente: %s\n' "${issues[*]}"
    fi
else
    printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$text" "$cls" "$tooltip"
fi
