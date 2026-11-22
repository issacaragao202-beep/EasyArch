#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Script de Manutenção 01: Relatório Padronizado de Memória
# Uso: 01-relatorio-memoria.sh [--show] [rotulo-do-cenario]
#
# Correções v4.3:
#   - Sanitiza o rótulo do cenário para nome de arquivo seguro.
#   - Corrige race condition fatal no `awk` de `top_pss` via `getline` seguro.
# ==============================================================================

set -uo pipefail

SHOW_OUTPUT=0
if [[ "${1:-}" == "--show" ]]; then
    SHOW_OUTPUT=1
    shift
fi

RAW_SCENARIO="${1:-medicao-geral}"
SCENARIO="$(printf '%s' "$RAW_SCENARIO" | tr -cs '[:alnum:]_-' '_' | sed 's/^_//; s/_$//')"
SCENARIO="${SCENARIO:-medicao-geral}"

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
OUT_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/easyarch/relatorios"
mkdir -p "$OUT_DIR"
OUT_FILE="${OUT_DIR}/memoria-${SCENARIO}-${TIMESTAMP}.txt"

top_pss() {
    local -a readable_files=()
    local f
    for f in /proc/[0-9]*/smaps_rollup; do
        [[ -r "$f" ]] && readable_files+=("$f")
    done
    (( ${#readable_files[@]} == 0 )) && return 0
    awk '
        BEGIN {
            for (i = 1; i < ARGC; i++) {
                f = ARGV[i]; ARGV[i] = ""
                split(f, p, "/")
                pid = p[3]; pss = 0
                while ((rc = (getline line < f)) > 0) {
                    if (line ~ /^Pss:/) { split(line, a); pss += a[2] }
                }
                if (rc >= 0) close(f)
                if (pss > 0) {
                    comm = "desconhecido"
                    cmdf = "/proc/" pid "/comm"
                    rc_cmd = (getline comm < cmdf)
                    if (rc_cmd >= 0) close(cmdf)
                    printf "%10d KiB\tPID %-7s\t%s\n", pss, pid, comm
                }
            }
            exit 0
        }
    ' "${readable_files[@]}" 2>/dev/null | sort -rn | head -n 15
}

{
    printf 'EasyArch v5.4 — RELATÓRIO DE MEMÓRIA (%s)\n' "$SCENARIO"
    printf 'Data/Hora: %s | Kernel: %s\n' "$(date -Is)" "$(uname -r)"
    printf '================================================================================\n\n'

    printf -- '--- 1. Resumo (free -m) ---\n'
    free -m
    printf '\n'

    printf -- '--- 2. /proc/meminfo (campos-chave) ---\n'
    grep -E '^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapCached|Active|Inactive|SwapTotal|SwapFree|Shmem|SReclaimable):' /proc/meminfo
    printf '\n'

    printf -- '--- 3. Pressão de Memória (PSI - /proc/pressure/memory) ---\n'
    if [[ -r /proc/pressure/memory ]]; then
        cat /proc/pressure/memory
    else
        printf 'PSI indisponível.\n'
    fi
    printf '\n'

    printf -- '--- 4. ZRAM (zramctl) ---\n'
    if command -v zramctl >/dev/null 2>&1; then
        zramctl
    else
        printf 'zramctl indisponível.\n'
    fi
    printf '\n'

    printf -- '--- 5. Top 15 Processos por PSS (Proportional Set Size em KiB) ---\n'
    top_pss
    printf '\n(Nota: execute com sudo para incluir o PSS de processos de outros usuários/root.)\n'
} > "$OUT_FILE"

if (( SHOW_OUTPUT == 1 )); then
    cat "$OUT_FILE"
    printf '\n'
fi
printf '[INFO] Relatório de memória salvo em: %s\n' "$OUT_FILE"
