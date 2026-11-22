#!/usr/bin/env bash
# ==============================================================================
# EasyArch — Verificador Real de NTSync (/dev/ntsync)
# Destino: ~/.local/bin/easyarch-ntsync-check.sh
# ==============================================================================

set -uo pipefail

printf '=== EasyArch — VERIFICAÇÃO NTSYNC ===\n'
printf 'Kernel: %s\n' "$(uname -r)"

mods_out="$(lsmod 2>/dev/null || true)"
if grep -q '^ntsync ' <<<"$mods_out"; then
    printf '[OK]    Módulo ntsync carregado no kernel.\n'
else
    printf '[AVISO] Módulo ntsync não listado em lsmod (tente: sudo modprobe ntsync).\n'
fi

if [[ -c /dev/ntsync ]]; then
    printf '[OK]    Dispositivo /dev/ntsync presente: %s\n' "$(ls -l /dev/ntsync)"
else
    printf '[FALHA] /dev/ntsync ausente.\n'
    exit 1
fi

if command -v wine >/dev/null 2>&1; then
    printf '[INFO]  Versão do Wine instalada: %s\n' "$(wine --version)"
fi

if command -v lsof >/dev/null 2>&1; then
    printf '\n--- Processos usando /dev/ntsync agora (execute enquanto um jogo/app roda) ---\n'
    lsof /dev/ntsync 2>/dev/null || printf 'Nenhum processo utilizando /dev/ntsync neste instante (ou requer sudo para processos de outro UID).\n'
fi
