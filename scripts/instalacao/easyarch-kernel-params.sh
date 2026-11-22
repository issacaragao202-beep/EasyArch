#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Parâmetros de Kernel (AppArmor + zswap desligado)
# Destino: scripts/instalacao/easyarch-kernel-params.sh
#
# Adiciona, de forma idempotente e com backup:
#   lsm=landlock,lockdown,yama,integrity,apparmor,bpf   (ativa o AppArmor)
#   zswap.enabled=0                                     (evita dupla compressão com ZRAM)
#
# Suporta: systemd-boot (entradas em loader/entries), /etc/kernel/cmdline e GRUB.
# Uso:
#   sudo ./easyarch-kernel-params.sh              Aplica (pede confirmação)
#   sudo ./easyarch-kernel-params.sh --yes        Aplica sem perguntar
#   sudo ./easyarch-kernel-params.sh --dry-run    Só mostra o que mudaria
# Variáveis para testes: EASYARCH_BOOT_DIRS="dir1 dir2", EASYARCH_ETC_DIR, EASYARCH_SKIP_ROOT_CHECK=1
# ==============================================================================

set -euo pipefail

LSM_VALUE="landlock,lockdown,yama,integrity,apparmor,bpf"
PARAMS=("lsm=${LSM_VALUE}" "zswap.enabled=0")
ETC_DIR="${EASYARCH_ETC_DIR:-/etc}"
BOOT_DIRS="${EASYARCH_BOOT_DIRS:-/boot /efi /boot/efi}"
BACKUP_DIR="${EASYARCH_BACKUP_DIR:-/root/easyarch-kernel-backup-$(date '+%Y%m%d-%H%M%S')}"

DRY_RUN=0
ASSUME_YES=0
CHANGED=0
GRUB_TOUCHED=0

while [[ "${1:-}" == -* ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --yes|-y)  ASSUME_YES=1; shift ;;
        -h|--help)
            sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) printf '[ERRO] Opção desconhecida: %s\n' "$1" >&2; exit 1 ;;
    esac
done

if [[ "${EASYARCH_SKIP_ROOT_CHECK:-0}" != "1" && "$(id -u)" -ne 0 ]]; then
    printf '[ERRO] Execute com sudo: sudo %s\n' "$0" >&2
    exit 1
fi

# Tokeniza preservando aspas (sem globbing * e sem quebrar valores com espaços),
# remove lsm= e zswap.enabled= existentes e anexa os parâmetros do EasyArch.
rewrite_params() {
    local current="$1"
    local -a tokens=()
    local cur="" in_sq=0 in_dq=0 ch i
    for (( i = 0; i < ${#current}; i++ )); do
        ch="${current:i:1}"
        if (( in_sq )); then
            cur+="$ch"
            [[ "$ch" == "'" ]] && in_sq=0
        elif (( in_dq )); then
            cur+="$ch"
            [[ "$ch" == '"' ]] && in_dq=0
        else
            case "$ch" in
                "'") in_sq=1; cur+="$ch" ;;
                '"') in_dq=1; cur+="$ch" ;;
                [[:space:]])
                    if [[ -n "$cur" ]]; then tokens+=("$cur"); cur=""; fi
                    ;;
                *) cur+="$ch" ;;
            esac
        fi
    done
    [[ -n "$cur" ]] && tokens+=("$cur")

    local tok out=""
    for tok in "${tokens[@]}"; do
        case "$tok" in
            lsm=*|zswap.enabled=*) continue ;;
        esac
        out+="${out:+ }${tok}"
    done
    if [[ -n "$out" ]]; then
        printf '%s %s %s' "$out" "${PARAMS[0]}" "${PARAMS[1]}"
    else
        printf '%s %s' "${PARAMS[0]}" "${PARAMS[1]}"
    fi
}

has_all_params() {
    local norm lsm_cnt=0 zswap_cnt=0 has_lsm=0 has_zswap=0 tok
    norm="$(printf '%s' "$1" | tr '	' ' ')"
    set -f
    for tok in $norm; do
        case "$tok" in
            lsm=*)
                lsm_cnt=$((lsm_cnt + 1))
                [[ "$tok" == "${PARAMS[0]}" ]] && has_lsm=1
                ;;
            zswap.enabled=*)
                zswap_cnt=$((zswap_cnt + 1))
                [[ "$tok" == "${PARAMS[1]}" ]] && has_zswap=1
                ;;
        esac
    done
    set +f
    (( has_lsm == 1 && lsm_cnt == 1 && has_zswap == 1 && zswap_cnt == 1 ))
}

backup_file() {
    local f="$1"
    (( DRY_RUN == 1 )) && return 0
    mkdir -p "${BACKUP_DIR}$(dirname -- "$f")"
    cp -a "$f" "${BACKUP_DIR}${f}"
}

# Substitui primeira linha que casa com regex usando ENVIRON (imune a escapes \a, \n, \\ do awk -v)
replace_first_line() {
    local f="$1" pattern="$2" new_line="$3" tmp rc=0
    tmp="$(mktemp)"
    if NEW_LINE="$new_line" PAT="$pattern" awk '
        BEGIN { done = 0; pat = ENVIRON["PAT"]; rep = ENVIRON["NEW_LINE"] }
        $0 ~ pat && !done { print rep; done = 1; next }
        { print }
    ' "$f" > "$tmp"; then
        cat "$tmp" > "$f" || rc=$?
    else
        rc=$?
    fi
    rm -f "$tmp"
    return "$rc"
}

# Extrai quote, conteúdo interno e sufixo (ex.: comentário # ...) de GRUB_CMDLINE_LINUX_DEFAULT=...
parse_grub_line() {
    local line="$1" rest q="" inner="" trailing="" i ch escaped=0
    rest="${line#GRUB_CMDLINE_LINUX_DEFAULT=}"
    if [[ "$rest" == \"* || "$rest" == \'* ]]; then
        q="${rest:0:1}"
        for (( i = 1; i < ${#rest}; i++ )); do
            ch="${rest:i:1}"
            if (( escaped )); then
                inner+="\\${ch}"
                escaped=0
            elif [[ "$ch" == "\\" && "$q" == '"' ]]; then
                escaped=1
            elif [[ "$ch" == "$q" ]]; then
                trailing="${rest:$((i + 1))}"
                break
            else
                inner+="$ch"
            fi
        done
    else
        q='"'
        inner="${rest%%#*}"
        if [[ "$rest" == *"#"* ]]; then
            trailing="#${rest#*#}"
        fi
        inner="${inner%"${inner##*[![:space:]]}"}"
    fi
    PARSED_Q="$q"
    PARSED_INNER="$inner"
    PARSED_TRAILING="$trailing"
}

# Atualiza linha `options ...` de uma entrada do systemd-boot
patch_loader_entry() {
    local f="$1" line cur new
    line="$(grep -E '^options[[:space:]]' "$f" | head -n 1 || true)"
    if [[ -z "$line" ]]; then
        printf '[AVISO] %s não tem linha "options"; ignorado.\n' "$f" >&2
        return 0
    fi
    cur="${line#options}"
    cur="${cur#"${cur%%[![:space:]]*}"}"
    if has_all_params "$cur"; then
        printf '[OK]    Já configurado: %s\n' "$f"
        return 0
    fi
    new="options $(rewrite_params "$cur")"
    printf '[MUDA]  %s\n         de: %s\n         para: %s\n' "$f" "$line" "$new"
    if (( DRY_RUN == 0 )); then
        backup_file "$f"
        replace_first_line "$f" '^options[ \t]' "$new"
    fi
    CHANGED=1
}

# Atualiza arquivo de uma linha (/etc/kernel/cmdline)
patch_cmdline_file() {
    local f="$1" cur new
    cur="$(tr '\n' ' ' < "$f")"
    cur="${cur%"${cur##*[![:space:]]}"}"
    if has_all_params "$cur"; then
        printf '[OK]    Já configurado: %s\n' "$f"
        return 0
    fi
    new="$(rewrite_params "$cur")"
    printf '[MUDA]  %s\n         para: %s\n' "$f" "$new"
    if (( DRY_RUN == 0 )); then
        backup_file "$f"
        printf '%s\n' "$new" > "$f"
    fi
    CHANGED=1
}

# Atualiza GRUB_CMDLINE_LINUX_DEFAULT em /etc/default/grub (preservando aspas e comentários)
patch_grub() {
    local f="$1" line new
    line="$(grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' "$f" | head -n 1 || true)"
    if [[ -z "$line" ]]; then
        printf '[AVISO] %s sem GRUB_CMDLINE_LINUX_DEFAULT; ignorado.\n' "$f" >&2
        return 0
    fi
    PARSED_Q='"' PARSED_INNER="" PARSED_TRAILING=""
    parse_grub_line "$line"
    if has_all_params "$PARSED_INNER"; then
        printf '[OK]    Já configurado: %s\n' "$f"
        return 0
    fi
    new="GRUB_CMDLINE_LINUX_DEFAULT=${PARSED_Q}$(rewrite_params "$PARSED_INNER")${PARSED_Q}${PARSED_TRAILING}"
    printf '[MUDA]  %s\n         para: %s\n' "$f" "$new"
    if (( DRY_RUN == 0 )); then
        backup_file "$f"
        replace_first_line "$f" '^GRUB_CMDLINE_LINUX_DEFAULT=' "$new"
    fi
    CHANGED=1
    GRUB_TOUCHED=1
}

# 1. Descobre alvos ANTES de pedir confirmação
declare -a LOADER_ENTRIES=()
HAS_CMDLINE=0
HAS_GRUB=0

for d in $BOOT_DIRS; do
    if [[ -d "${d}/loader/entries" ]]; then
        shopt -s nullglob
        for f in "${d}"/loader/entries/*.conf; do
            # Pula entradas de fallback analisando apenas o nome do arquivo (não o caminho pai)
            [[ "$(basename -- "$f")" == *fallback* ]] && continue
            LOADER_ENTRIES+=("$f")
        done
        shopt -u nullglob
    fi
done

[[ -f "${ETC_DIR}/kernel/cmdline" ]] && HAS_CMDLINE=1
[[ -f "${ETC_DIR}/default/grub" ]] && HAS_GRUB=1

if (( ${#LOADER_ENTRIES[@]} == 0 && HAS_CMDLINE == 0 && HAS_GRUB == 0 )); then
    printf '[ERRO] Nenhuma configuração de bootloader encontrada (loader/entries, /etc/kernel/cmdline ou GRUB).\n' >&2
    printf '       Adicione manualmente à linha do kernel: %s %s\n' "${PARAMS[0]}" "${PARAMS[1]}" >&2
    exit 1
fi

if (( ASSUME_YES == 0 && DRY_RUN == 0 )); then
    printf 'Serão adicionados ao kernel: %s %s\n' "${PARAMS[0]}" "${PARAMS[1]}"
    read -r -p "Confirmar (s/N)? " ans
    if [[ "${ans,,}" != "s" && "${ans,,}" != "sim" ]]; then
        printf '[EasyArch] Cancelado.\n'
        exit 0
    fi
fi

for f in "${LOADER_ENTRIES[@]}"; do
    patch_loader_entry "$f"
done

if (( HAS_CMDLINE == 1 )); then
    patch_cmdline_file "${ETC_DIR}/kernel/cmdline"
fi

if (( HAS_GRUB == 1 )); then
    patch_grub "${ETC_DIR}/default/grub"
    if (( GRUB_TOUCHED == 1 && DRY_RUN == 0 )); then
        grub_dir=""
        for d in $BOOT_DIRS; do
            if [[ -d "${d}/grub" ]]; then
                grub_dir="${d}/grub"
                break
            fi
        done
        if command -v grub-mkconfig >/dev/null 2>&1 && [[ -n "$grub_dir" ]]; then
            grub-mkconfig -o "${grub_dir}/grub.cfg"
        else
            printf '[AVISO] Rode manualmente: grub-mkconfig -o /boot/grub/grub.cfg\n' >&2
        fi
    fi
fi

if (( CHANGED == 1 )); then
    if (( DRY_RUN == 1 )); then
        printf '\n[DRY-RUN] Nada foi alterado.\n'
    else
        printf '\n[OK] Backup em %s. Reinicie para aplicar (AppArmor só ativa após o reboot).\n' "$BACKUP_DIR"
        if (( HAS_CMDLINE == 1 )); then
            printf '[INFO] /etc/kernel/cmdline alterado: se usar UKI, regenere as imagens (kernel-install/mkinitcpio) antes de reiniciar.\n'
        fi
    fi
else
    printf '\n[OK] Nada a alterar.\n'
fi
