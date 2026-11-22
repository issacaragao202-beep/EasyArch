#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Wrapper Seguro para Executáveis Windows (.exe / .msi)
# Destino: ~/.local/bin/easyarch-win-run.sh
#
# Correções v4.4:
#   - Por padrão copia o executável para C:\easyarch_run\ em vez de montar a
#     pasta pai inteira (ex.: ~/Downloads) em E: RW. Exige flag explícita
#     --mount-dir para instaladores multi-arquivo com DLLs irmãs (bloqueando
#     ainda /, $HOME e ~/Downloads).
#   - Varre TODOS os symlinks em drive_c/users/$USER (find -maxdepth 2 -type l),
#     isolando pastas em qualquer idioma (PT-BR/EN) que apontem para fora do prefixo.
#   - Detecta atualização de versão do Wine no prefixo e roda wineboot -u ANTES
#     de remover Z: e symlinks, evitando regeneração silenciosa durante o app.
# ==============================================================================

set -euo pipefail

MOUNT_DIR=0
while [[ "${1:-}" == -* ]]; do
    case "$1" in
        --mount-dir) MOUNT_DIR=1; shift ;;
        --) shift; break ;;
        -h|--help)
            printf 'Uso: easyarch-win-run.sh [--mount-dir] <arquivo.exe|arquivo.msi>\n'
            exit 0
            ;;
        *)
            printf '[ERRO] Opção desconhecida: %s\n' "$1" >&2
            exit 1
            ;;
    esac
done

if ! command -v wine >/dev/null 2>&1; then
    printf '[ERRO] Pacote "wine" não instalado. Instale a Fase 3 (sudo pacman -S wine).\n' >&2
    exit 1
fi

TARGET="${1:-}"
if [[ -z "$TARGET" || ! -f "$TARGET" ]]; then
    printf '[ERRO] Informe um arquivo .exe ou .msi válido.\n' >&2
    exit 1
fi

ABS_PATH="$(readlink -f -- "$TARGET")"
ABS_DIR="$(dirname -- "$ABS_PATH")"
FILE_NAME="$(basename -- "$ABS_PATH")"
EXT="${FILE_NAME##*.}"
EXT_LOWER="${EXT,,}"

if [[ "$FILE_NAME" != *.* || ( "$EXT_LOWER" != "exe" && "$EXT_LOWER" != "msi" ) ]]; then
    printf '[ERRO] Extensão não suportada: "%s" (permitido apenas .exe ou .msi).\n' "$FILE_NAME" >&2
    exit 1
fi

SHA256="$(sha256sum "$ABS_PATH" | awk '{print $1}')"
SHORT_HASH="${SHA256:0:8}"
SAFE_NAME="$(printf '%s' "${FILE_NAME%.*}" | tr -cs '[:alnum:]_-' '_' | tr '[:upper:]' '[:lower:]')"
SAFE_NAME="${SAFE_NAME:-winapp}"
PREFIX_ID="${SAFE_NAME}-${SHORT_HASH}"
PREFIX_DIR="${HOME}/.local/share/easyarch/wine-prefixes/${PREFIX_ID}"
LOG_DIR="${HOME}/.local/state/easyarch/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/wine-${PREFIX_ID}-$(date '+%Y%m%d-%H%M%S').log"

# Bloqueia montagem direta de diretórios amplos do usuário mesmo com --mount-dir
is_broad_user_dir() {
    local d home_real
    d="$(readlink -f -- "$1" 2>/dev/null || printf '%s' "$1")"
    home_real="$(readlink -f -- "$HOME" 2>/dev/null || printf '%s' "$HOME")"
    local -a blocked=(
        "/" "/tmp" "$home_real"
        "${home_real}/Downloads" "${home_real}/Transferências" "${home_real}/Desktop"
        "${home_real}/Área de Trabalho" "${home_real}/Documents" "${home_real}/Documentos"
        "${home_real}/Pictures" "${home_real}/Imagens"
    )
    if command -v xdg-user-dir >/dev/null 2>&1; then
        local xtype xval
        for xtype in DOWNLOAD DESKTOP DOCUMENTS PICTURES; do
            xval="$(xdg-user-dir "$xtype" 2>/dev/null || true)"
            [[ -n "$xval" ]] && blocked+=("$xval")
        done
    fi
    local b b_real
    for b in "${blocked[@]}"; do
        b_real="$(readlink -f -- "$b" 2>/dev/null || printf '%s' "$b")"
        [[ "$d" == "$b_real" ]] && return 0
    done
    local -a blocked_trees=(
        "/etc" "/usr" "/var" "/boot" "/sys" "/proc" "/root"
        "${home_real}/.ssh" "${home_real}/.gnupg" "${home_real}/.config"
        "${home_real}/.local" "${home_real}/.password-store"
        "${home_real}/.aws" "${home_real}/.kube"
    )
    for b in "${blocked_trees[@]}"; do
        b_real="$(readlink -f -- "$b" 2>/dev/null || printf '%s' "$b")"
        case "$d" in
            "$b_real"|"$b_real"/*) return 0 ;;
        esac
    done
    return 1
}

if (( MOUNT_DIR == 1 )) && is_broad_user_dir "$ABS_DIR"; then
    printf '[AVISO] --mount-dir recusado para diretório amplo (%s); copiando arquivo para o prefixo.\n' "$ABS_DIR" >&2
    MOUNT_DIR=0
fi

confirm_run() {
    local mount_note="Execução isolada em C:\\easyarch_run\\ (pasta de origem NÃO será montada)."
    if (( MOUNT_DIR == 1 )); then
        mount_note="ATENÇÃO (--mount-dir): a pasta ${ABS_DIR} será montada em E:."
    fi
    local msg
    printf -v msg '%s\n\nArquivo: %s\nCaminho: %s\nSHA-256: %s\nPrefixo: %s\n%s\nDrive Z: (/) e symlinks para $HOME serão isolados.\n\nPara sandbox completa, prefira Bottles (Flatpak).' \
        "Executar este arquivo Windows em prefixo Wine isolado?" \
        "$FILE_NAME" "$ABS_PATH" "$SHA256" "$PREFIX_DIR" "$mount_note"
    if [[ -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]] && command -v zenity >/dev/null 2>&1; then
        zenity --question --no-markup --width=560 \
            --title="EasyArch v5.4 — Confirmação de Segurança (.exe/.msi)" \
            --text="$msg" \
            --ok-label="Executar em prefixo isolado" \
            --cancel-label="Cancelar"
    else
        printf '%s\n' "$msg"
        read -r -p "Digite SIM para confirmar: " ans
        [[ "$ans" == "SIM" ]]
    fi
}

isolate_user_dirs() {
    local win_user="${USER:-$(id -un)}"
    local user_root="${PREFIX_DIR}/drive_c/users/${win_user}"
    [[ -d "$user_root" ]] || return 0
    local abs_prefix link target
    abs_prefix="$(readlink -f -- "$PREFIX_DIR")"
    while IFS= read -r -d '' link; do
        target="$(readlink -f -- "$link" 2>/dev/null || true)"
        case "$target" in
            "${abs_prefix}"|"${abs_prefix}"/*) ;;
            *)
                rm -f "$link"
                mkdir -p "$link"
                ;;
        esac
    done < <(find "$user_root" -maxdepth 2 -type l -print0 2>/dev/null)
}

if ! confirm_run; then
    printf '[INFO] Execução cancelada pelo usuário.\n'
    exit 0
fi

export WINEPREFIX="$PREFIX_DIR"
export WINEARCH="${WINEARCH:-win64}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-winemenubuilder.exe=d}"

cur_wine_ver="$(wine --version 2>/dev/null || echo unknown)"
ver_stamp="${PREFIX_DIR}/.easyarch-wine-version"
prev_wine_ver="$(cat "$ver_stamp" 2>/dev/null || true)"

if [[ ! -d "$PREFIX_DIR" || "$cur_wine_ver" != "$prev_wine_ver" ]]; then
    mkdir -p "$PREFIX_DIR"
    wineboot -u >/dev/null 2>&1 || true
    wineserver -w || true
    printf '%s\n' "$cur_wine_ver" > "$ver_stamp"
fi

mkdir -p "${PREFIX_DIR}/dosdevices"
# Garante remoção do symlink Z: (/) e de todos os symlinks para fora do prefixo
rm -f "${PREFIX_DIR}/dosdevices/z:"
isolate_user_dirs

if (( MOUNT_DIR == 1 )); then
    ln -sfn "$ABS_DIR" "${PREFIX_DIR}/dosdevices/e:"
    WIN_TARGET="E:\\${FILE_NAME}"
    cd "$ABS_DIR"
else
    rm -f "${PREFIX_DIR}/dosdevices/e:"
    IN_PREFIX_DIR="${PREFIX_DIR}/drive_c/easyarch_run"
    mkdir -p "$IN_PREFIX_DIR"
    cp -f -- "$ABS_PATH" "${IN_PREFIX_DIR}/${FILE_NAME}"
    WIN_TARGET="C:\\easyarch_run\\${FILE_NAME}"
    cd "$IN_PREFIX_DIR"
fi

{
    printf '[%s] Iniciando %s (SHA256=%s) em %s\n' "$(date -Is)" "$FILE_NAME" "$SHA256" "$WINEPREFIX"
} >> "$LOG_FILE"

wine_rc=0
if [[ "$EXT_LOWER" == "msi" ]]; then
    wine msiexec /i "$WIN_TARGET" >>"$LOG_FILE" 2>&1 || wine_rc=$?
else
    wine "$WIN_TARGET" >>"$LOG_FILE" 2>&1 || wine_rc=$?
fi

wineserver -w || true
printf '[INFO] Prefixo "%s" encerrado (código %d). Log: %s\n' "$PREFIX_ID" "$wine_rc" "$LOG_FILE"
exit "$wine_rc"
