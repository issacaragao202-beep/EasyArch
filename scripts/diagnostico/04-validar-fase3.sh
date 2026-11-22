#!/usr/bin/env bash
# ==============================================================================
# EasyArch — Script 04: Validação Pós-Instalação da Fase 3 (SOMENTE LEITURA)
# Testa individualmente: Flatpak/bwrap, Wine/Steam/Gamescope, /dev/ntsync e Waydroid.
# ==============================================================================

set -uo pipefail

PASS=0; WARN=0; FAIL=0
ok()   { printf '[OK]    %s\n' "$1"; PASS=$((PASS + 1)); }
warn() { printf '[AVISO] %s\n' "$1"; WARN=$((WARN + 1)); }
fail() { printf '[FALHA] %s\n' "$1"; FAIL=$((FAIL + 1)); }

printf '============================================================\n'
printf ' EasyArch — VALIDAÇÃO DA FASE 3 (%s)\n' "$(date -Is)"
printf '============================================================\n\n'

# 1. Flatpak e bubblewrap
for bin in flatpak bwrap; do
    command -v "$bin" >/dev/null 2>&1 && ok "Sandboxing disponível: ${bin}" || fail "Ausente: ${bin}"
done

# 2. Wine, Steam, Gamescope e /dev/ntsync
for bin in wine winetricks steam gamescope; do
    command -v "$bin" >/dev/null 2>&1 && ok "Ferramenta Windows/Jogos instalada: ${bin}" || warn "Não instalado: ${bin}"
done

if [[ -c /dev/ntsync ]]; then
    ok "/dev/ntsync presente no kernel atual."
else
    warn "/dev/ntsync ausente (carregue com 'sudo modprobe ntsync')."
fi

# 3. Bottles Flatpak
if command -v flatpak >/dev/null 2>&1 && flatpak info com.usebottles.bottles >/dev/null 2>&1; then
    ok "Bottles (Flatpak) instalado."
else
    warn "Bottles (Flatpak) não instalado."
fi

# 4. Waydroid e política sob demanda
if command -v waydroid >/dev/null 2>&1; then
    ok "Waydroid instalado."
    if systemctl is-enabled --quiet waydroid-container.service 2>/dev/null; then
        warn "waydroid-container.service está ENABLED no boot (recomendado: disable para economizar RAM)."
    else
        ok "waydroid-container.service configurado sob demanda (disabled no boot)."
    fi
    if [[ -e /dev/binderfs || -e /dev/binder ]] || modinfo binder_linux >/dev/null 2>&1; then
        ok "Suporte a binder detectado para Waydroid."
    else
        warn "binder_linux não detectado neste kernel (avalie linux-zen se necessário)."
    fi
else
    warn "Waydroid não instalado (pacote AUR opcional)."
fi

# 5. Wrappers seguros do EasyArch
for w in easyarch-win-run.sh easyarch-ntsync-check.sh easyarch-waydroid.sh easyarch-appimage-sandbox.sh; do
    [[ -x "${HOME}/.local/bin/${w}" ]] && ok "Wrapper instalado: ${w}" || warn "Wrapper ausente em ~/.local/bin: ${w}"
done

printf '\n============================================================\n'
printf ' RESUMO: OK=%d | AVISOS=%d | FALHAS=%d\n' "$PASS" "$WARN" "$FAIL"
printf '============================================================\n'
(( FAIL > 0 )) && exit 1
exit 0
