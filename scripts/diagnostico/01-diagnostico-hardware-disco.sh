#!/usr/bin/env bash
# ==============================================================================
# EasyArch — Script 01: Diagnóstico de Hardware e Disco (100% SOMENTE LEITURA)
# Fase 1 / Etapa 1
#
# Objetivo:
#   Coletar informações reais do hardware, firmware UEFI, tabela de partições,
#   saúde do SSD e suporte do kernel sem modificar absolutamente nada no sistema.
#
# Uso:
#   chmod +x 01-diagnostico-hardware-disco.sh
#   ./01-diagnostico-hardware-disco.sh
#   (Para dados SMART completos do SSD, pode ser executado com sudo.)
# ==============================================================================

set -uo pipefail

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
if [[ -w "$PWD" ]]; then
    OUT_FILE="${PWD}/relatorio-hardware-disco-${TIMESTAMP}.txt"
else
    OUT_FILE="/tmp/relatorio-hardware-disco-${TIMESTAMP}.txt"
fi

log_info() {
    printf '[INFO] %s\n' "$1"
}

section() {
    printf '\n================================================================================\n' >> "$OUT_FILE"
    printf ' %s\n' "$1" >> "$OUT_FILE"
    printf '================================================================================\n' >> "$OUT_FILE"
}

run_cmd() {
    local label="$1"
    shift
    printf '\n--- %s ---\n' "$label" >> "$OUT_FILE"
    if command -v "$1" >/dev/null 2>&1; then
        "$@" >> "$OUT_FILE" 2>&1 || printf '[AVISO] Comando retornou código %d\n' "$?" >> "$OUT_FILE"
    else
        printf '[INDISPONÍVEL] Comando "%s" não encontrado neste ambiente.\n' "$1" >> "$OUT_FILE"
    fi
}

log_info "Iniciando diagnóstico SOMENTE LEITURA do Projeto EasyArch..."
log_info "Nenhuma partição ou configuração será alterada."

{
    printf 'EasyArch — RELATÓRIO DE DIAGNÓSTICO DE HARDWARE E DISCO\n'
    printf 'Data/Hora: %s\n' "$(date -Is)"
    printf 'Hostname:  %s\n' "$(hostname 2>/dev/null || echo desconhecido)"
    printf 'Usuário:   %s (UID=%s)\n' "$(id -un)" "$(id -u)"
} > "$OUT_FILE"

section "1. FIRMWARE UEFI E KERNEL ATUAL"
if [[ -d /sys/firmware/efi/efivars ]]; then
    printf 'Modo de Boot: UEFI DETECTADO (/sys/firmware/efi/efivars existe)\n' >> "$OUT_FILE"
    if [[ -r /sys/firmware/efi/fw_platform_size ]]; then
        printf 'Arquitetura UEFI: %s bits\n' "$(cat /sys/firmware/efi/fw_platform_size)" >> "$OUT_FILE"
    fi
else
    printf 'Modo de Boot: BIOS/LEGACY (ATENÇÃO: projeto exige UEFI!)\n' >> "$OUT_FILE"
fi
run_cmd "Kernel (uname -a)" uname -a
run_cmd "Parâmetros atuais do kernel (/proc/cmdline)" cat /proc/cmdline
run_cmd "Entradas UEFI (efibootmgr)" efibootmgr -v

section "2. CPU, GPU E MEMÓRIA RAM REAL"
run_cmd "CPU (lscpu)" lscpu
run_cmd "Memória (free -h)" free -h
run_cmd "Detalhes de Memória (/proc/meminfo - principais linhas)" grep -E '^(MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo
if command -v lspci >/dev/null 2>&1; then
    run_cmd "Controlador Gráfico (lspci -nnk VGA/3D)" bash -c 'lspci -nnk | grep -A 3 -E "VGA|3D|Display"'
else
    printf '\n--- Controlador Gráfico (lspci -nnk VGA/3D) ---\n[INDISPONÍVEL] Comando "lspci" não encontrado neste ambiente.\n' >> "$OUT_FILE"
fi
run_cmd "Módulos de RAM (dmidecode -t memory, requer root)" dmidecode -t memory

section "3. DISCOS, PARTIÇÕES EXISTENTES E SISTEMAS INSTALADOS"
run_cmd "Blocos e Sistemas de Arquivos (lsblk -f -o NAME,SIZE,TYPE,FSTYPE,FSVER,LABEL,UUID,MOUNTPOINTS,MODEL)" \
    lsblk -f -o NAME,SIZE,TYPE,FSTYPE,FSVER,LABEL,UUID,MOUNTPOINTS,MODEL
run_cmd "Tabela de Partições (fdisk -l, requer root)" fdisk -l
run_cmd "Suporte a TRIM/Discard nos discos (lsblk --discard)" lsblk --discard -o NAME,DISC-ALN,DISC-GRAN,DISC-MAX,DISC-ZERO
run_cmd "Espaço em montagens atuais (df -hT)" df -hT

section "4. SAÚDE DO SSD (SMART)"
if command -v smartctl >/dev/null 2>&1; then
    for dev in /dev/sd? /dev/nvme?n?; do
        if [[ -b "$dev" ]]; then
            run_cmd "SMART Info ($dev)" smartctl -i -H "$dev"
        fi
    done
else
    printf '[INDISPONÍVEL] smartctl não instalado (pacote smartmontools).\n' >> "$OUT_FILE"
fi

section "5. SUPORTE DE MÓDULOS DO KERNEL (ntsync, binder, zram, apparmor)"
{
    for mod in ntsync zram btrfs dm_crypt binder_linux; do
        if modinfo "$mod" >/dev/null 2>&1; then
            printf 'Módulo %-14s: DISPONÍVEL\n' "$mod"
        else
            printf 'Módulo %-14s: NÃO ENCONTRADO no kernel atual\n' "$mod"
        fi
    done
    if [[ -e /dev/ntsync ]]; then
        printf '/dev/ntsync          : PRESENTE (%s)\n' "$(ls -l /dev/ntsync)"
    else
        printf '/dev/ntsync          : AUSENTE (módulo não carregado ou indisponível)\n'
    fi
    if [[ -r /sys/kernel/security/lsm ]]; then
        printf 'LSMs ativos          : %s\n' "$(cat /sys/kernel/security/lsm)"
    fi
} >> "$OUT_FILE"

section "6. MONITOR E REDE"
run_cmd "Interfaces de Rede (ip -brief addr)" ip -brief addr
if [[ -d /sys/class/drm ]]; then
    printf '\n--- Conectores DRM e Modos Detectados ---\n' >> "$OUT_FILE"
    for status_file in /sys/class/drm/card*-*/status; do
        [[ -r "$status_file" ]] || continue
        dir="$(dirname "$status_file")"
        conn="$(basename "$dir")"
        st="$(cat "$status_file")"
        printf 'Conector %s: %s\n' "$conn" "$st" >> "$OUT_FILE"
        if [[ "$st" == "connected" && -r "${dir}/modes" ]]; then
            head -n 10 "${dir}/modes" | sed 's/^/  modo: /' >> "$OUT_FILE"
        fi
    done
fi

log_info "Diagnóstico concluído com sucesso."
log_info "Arquivo gerado: ${OUT_FILE}"
log_info "Próximo passo: envie este relatório antes de iniciar o particionamento da Etapa 2."
