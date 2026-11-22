#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Wrapper bubblewrap para AppImage (Isolamento Reforçado)
# Destino: ~/.local/bin/easyarch-appimage-sandbox.sh
#
# Correções v4.5:
#   - Corrige parsing da flag `-h` (`while [[ "${1:-}" == -* ]]`).
#   - Valida presença de `bwrap`, usa `--dev-bind-try /dev/dri /dev/dri` (VMs),
#     evita colisão em `SANDBOX_HOME` via hash curto SHA-256 e monta `$XAUTHORITY`
#     somente leitura quando `--x11` é solicitado.
# ==============================================================================

set -euo pipefail

ALLOW_X11=0
NO_NET=0
while [[ "${1:-}" == -* ]]; do
    case "$1" in
        --x11) ALLOW_X11=1; shift ;;
        --no-net) NO_NET=1; shift ;;
        --) shift; break ;;
        -h|--help)
            printf 'Uso: easyarch-appimage-sandbox.sh [--x11] [--no-net] <caminho/para/App.AppImage> [args...]\n'
            exit 0
            ;;
        *)
            printf '[ERRO] Opção desconhecida: %s\n' "$1" >&2
            printf 'Uso: easyarch-appimage-sandbox.sh [--x11] [--no-net] <caminho/para/App.AppImage> [args...]\n' >&2
            exit 1
            ;;
    esac
done

if ! command -v bwrap >/dev/null 2>&1; then
    printf '[ERRO] Pacote "bubblewrap" não instalado. Instale com: sudo pacman -S bubblewrap\n' >&2
    exit 1
fi

APPIMAGE="${1:-}"
shift || true

if [[ -z "$APPIMAGE" || ! -f "$APPIMAGE" ]]; then
    printf 'Uso: easyarch-appimage-sandbox.sh [--x11] [--no-net] <caminho/para/App.AppImage> [args...]\n' >&2
    exit 1
fi

ABS_APP="$(readlink -f -- "$APPIMAGE")"
if [[ ! -x "$ABS_APP" ]]; then
    printf '[ERRO] O arquivo não possui permissão de execução (+x): %s\n' "$ABS_APP" >&2
    printf '       Aplique antes: chmod +x "%s"\n' "$ABS_APP" >&2
    exit 1
fi

# Hash do CAMINHO (não do conteúdo): atualizar o AppImage no mesmo lugar mantém as configurações do app.
SHORT_HASH="$(printf '%s' "$ABS_APP" | sha256sum | awk '{print substr($1, 1, 8)}')"
APP_NAME="$(basename "$ABS_APP" | tr -cs '[:alnum:]_-' '_' | sed 's/^_//; s/_$//')"
APP_NAME="${APP_NAME:-appimage}-${SHORT_HASH}"
SANDBOX_HOME="${HOME}/.local/share/easyarch/appimage-homes/${APP_NAME}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
mkdir -p "$SANDBOX_HOME"

BWRAP_ARGS=(
    --ro-bind /usr /usr
    --symlink usr/lib /lib
    --symlink usr/lib /lib64
    --symlink usr/bin /bin
    --symlink usr/bin /sbin
    --ro-bind /etc /etc
    --ro-bind-try /run/systemd/resolve /run/systemd/resolve
    --ro-bind-try /sys/dev/char /sys/dev/char
    --ro-bind-try /sys/devices /sys/devices
    --ro-bind-try /sys/class/drm /sys/class/drm
    --dev /dev
    --dev-bind-try /dev/dri /dev/dri
    --dev-bind-try /dev/fuse /dev/fuse
    --proc /proc
    --tmpfs /tmp
    --tmpfs "$RUNTIME_DIR"
    --chmod 0700 "$RUNTIME_DIR"
    --bind "$SANDBOX_HOME" "$HOME"
    --ro-bind "$ABS_APP" /app.AppImage
    --setenv APPIMAGE_EXTRACT_AND_RUN 1
    --setenv ARGV0 /app.AppImage
    --cap-drop ALL
    --unshare-pid
    --unshare-ipc
    --unshare-uts
    --unshare-cgroup-try
    --new-session
    --die-with-parent
)

# --no-net: sem acesso à rede (apps offline, ex.: editores e visualizadores)
if (( NO_NET == 1 )); then
    BWRAP_ARGS+=(--unshare-net)
fi

# Expõe somente sockets de display Wayland e áudio (nunca D-Bus nem IPC do Hyprland)
if [[ -n "${WAYLAND_DISPLAY:-}" && -S "${RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]]; then
    BWRAP_ARGS+=(--bind "${RUNTIME_DIR}/${WAYLAND_DISPLAY}" "${RUNTIME_DIR}/${WAYLAND_DISPLAY}")
fi
if [[ -S "${RUNTIME_DIR}/pipewire-0" ]]; then
    BWRAP_ARGS+=(--bind "${RUNTIME_DIR}/pipewire-0" "${RUNTIME_DIR}/pipewire-0")
fi
if [[ -S "${RUNTIME_DIR}/pulse/native" ]]; then
    BWRAP_ARGS+=(--dir "${RUNTIME_DIR}/pulse" --bind "${RUNTIME_DIR}/pulse/native" "${RUNTIME_DIR}/pulse/native")
fi

# XWayland somente sob opt-in explícito (--x11); propaga XAUTHORITY quando existir
if (( ALLOW_X11 == 1 )) && [[ -n "${DISPLAY:-}" && -d /tmp/.X11-unix ]]; then
    BWRAP_ARGS+=(--ro-bind /tmp/.X11-unix /tmp/.X11-unix)
    if [[ -n "${XAUTHORITY:-}" && -r "$XAUTHORITY" ]]; then
        BWRAP_ARGS+=(--ro-bind "$XAUTHORITY" /tmp/.easyarch-xauth --setenv XAUTHORITY /tmp/.easyarch-xauth)
    fi
else
    BWRAP_ARGS+=(--unsetenv DISPLAY --unsetenv XAUTHORITY)
fi

exec bwrap "${BWRAP_ARGS[@]}" /app.AppImage "$@"
