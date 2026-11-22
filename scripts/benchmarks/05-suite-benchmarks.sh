#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Suíte Padronizada de Benchmarks (7 Cenários + Auditoria)
# Destino: ~/.local/bin/05-suite-benchmarks.sh
#
# Correções v4.4:
#   - Fecha descritor de /proc/<pid>/comm no awk mesmo em EOF (rc_cmd >= 0).
#   - Contagem exata de processos Wine (`pgrep -x`) sem falsos positivos de caminho.
#   - Fallback de temperatura CPU para Intel (`Package id 0:` / `Core 0:`) antes de `edge:`.
# ==============================================================================

set -uo pipefail

RAW_SCENARIO="${1:-}"
if [[ -z "$RAW_SCENARIO" ]]; then
    printf 'Uso: 05-suite-benchmarks.sh <nome-do-cenario>\n' >&2
    exit 1
fi

SCENARIO="$(printf '%s' "$RAW_SCENARIO" | tr -cs '[:alnum:]_-' '_' | sed 's/^_//; s/_$//')"
SCENARIO="${SCENARIO:-cenario}"

OUT_DIR="${HOME}/easyarch-benchmarks"
mkdir -p "$OUT_DIR"
STAMP="$(date '+%Y%m%d-%H%M%S')"
REPORT="${OUT_DIR}/bench-${SCENARIO}-${STAMP}.txt"
CSV="${OUT_DIR}/resumo-benchmarks.csv"

if [[ ! -f "$CSV" ]]; then
    printf 'timestamp,cenario,kernel,mem_total_mib,mem_used_real_mib,mem_avail_mib,swap_used_mib,zram_data_mib,zram_compr_mib,wine_procs,waydroid_active,temp_c\n' > "$CSV"
fi

mem_total_kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
mem_avail_kb="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"
swap_total_kb="$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo)"
swap_free_kb="$(awk '/^SwapFree:/ {print $2}' /proc/meminfo)"

mem_total_mib="$(( ${mem_total_kb:-0} / 1024 ))"
mem_avail_mib="$(( ${mem_avail_kb:-0} / 1024 ))"
mem_used_mib="$(( (${mem_total_kb:-0} - ${mem_avail_kb:-0}) / 1024 ))"
swap_used_mib="$(( (${swap_total_kb:-0} - ${swap_free_kb:-0}) / 1024 ))"

zram_data_mib="0"
zram_compr_mib="0"
if command -v zramctl >/dev/null 2>&1 && zramctl --bytes --noheadings --output DATA,COMPR /dev/zram0 >/dev/null 2>&1; then
    read -r zd zc < <(zramctl --bytes --noheadings --output DATA,COMPR /dev/zram0 2>/dev/null || echo "0 0")
    zram_data_mib="$(( ${zd:-0} / 1048576 ))"
    zram_compr_mib="$(( ${zc:-0} / 1048576 ))"
fi

wine_procs="$(pgrep -xc 'wineserver|wine64|wine|wine-preloader|wine64-preloade' 2>/dev/null || true)"
wine_procs="${wine_procs:-0}"
waydroid_active="$(systemctl is-active waydroid-container.service 2>/dev/null || echo inactive)"
kernel_clean="$(uname -r | tr ',' '_')"

temp_c="NA"
if command -v sensors >/dev/null 2>&1; then
    sensors_out="$(sensors 2>/dev/null || true)"
    temp_c="$(printf '%s\n' "$sensors_out" | awk '/Tctl:|Tdie:/ {gsub(/[+°C]/,"",$2); print $2; exit}')"
    if [[ -z "$temp_c" ]]; then
        temp_c="$(printf '%s\n' "$sensors_out" | awk '/Package id 0:|Core 0:/ {for (i=1;i<=NF;i++) if ($i ~ /\+[0-9]/) {gsub(/[+°C,]/,"",$i); print $i; exit}}')"
    fi
    if [[ -z "$temp_c" ]]; then
        temp_c="$(printf '%s\n' "$sensors_out" | awk '/edge:/ {gsub(/[+°C]/,"",$2); print $2; exit}')"
    fi
    [[ -z "$temp_c" ]] && temp_c="NA"
fi

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
    printf 'EasyArch v5.4 — BENCHMARK REAL: %s\n' "$SCENARIO"
    printf 'Data/Hora: %s | Kernel: %s\n' "$(date -Is)" "$kernel_clean"
    printf '================================================================================\n\n'
    printf -- '--- Tempo de Inicialização (systemd-analyze) ---\n'
    systemd-analyze 2>/dev/null || printf 'systemd-analyze indisponível.\n'
    printf '\n--- Memória (free -m) ---\n'
    free -m
    printf '\nRAM efetivamente ocupada: %d MiB | MemAvailable: %d MiB\n' "$mem_used_mib" "$mem_avail_mib"
    printf 'ZRAM Data: %d MiB | ZRAM Compr: %d MiB | Wine procs: %s | Waydroid: %s\n\n' \
        "$zram_data_mib" "$zram_compr_mib" "$wine_procs" "$waydroid_active"
    printf -- '--- ZRAM (zramctl) ---\n'
    zramctl 2>/dev/null || printf 'zramctl indisponível.\n'
    printf '\n--- Pressão de Memória (PSI) ---\n'
    cat /proc/pressure/memory 2>/dev/null || printf 'PSI indisponível.\n'
    printf '\n--- CPU Ociosa (1s) ---\n'
    if command -v mpstat >/dev/null 2>&1; then mpstat 1 1; else vmstat 1 2; fi
    printf '\n--- Temperaturas (sensors) ---\n'
    sensors 2>/dev/null || printf 'sensors indisponível.\n'
    printf '\n--- Top 15 Processos por PSS (KiB) ---\n'
    top_pss
} > "$REPORT"

printf '%s,%s,%s,%d,%d,%d,%d,%d,%d,%s,%s,%s\n' \
    "$(date -Is)" "$SCENARIO" "$kernel_clean" \
    "$mem_total_mib" "$mem_used_mib" "$mem_avail_mib" "$swap_used_mib" \
    "$zram_data_mib" "$zram_compr_mib" "$wine_procs" "$waydroid_active" "$temp_c" >> "$CSV"

printf '[OK] Benchmark v5.4 salvo em: %s\n' "$REPORT"
printf '[OK] CSV atualizado em:       %s\n' "$CSV"
