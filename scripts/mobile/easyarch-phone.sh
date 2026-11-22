#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Integração Smartphone Android (ADB, scrcpy e Offload Termux USB)
# Destino: ~/.local/bin/easyarch-phone.sh
#
# Correções v4.4:
#   - Remove usuário fixo incorreto `u0_a0` (Termux usa UID dinâmico); usa
#     TERMUX_USER somente quando definido pelo usuário.
#   - Remove o túnel `adb forward` automaticamente ao sair de `offload` (trap EXIT).
# ==============================================================================

set -euo pipefail

TERMUX_PORT="${TERMUX_PORT:-8022}"
TERMUX_USER="${TERMUX_USER:-}"

usage() {
    cat <<'EOF'
Uso:
  easyarch-phone.sh status                        Verifica dispositivos conectados via ADB
  easyarch-phone.sh mirror                        Abre espelhamento/controle remoto leve (scrcpy)
  easyarch-phone.sh push <local> <remoto>         Envia arquivo/pasta para o smartphone
  easyarch-phone.sh pull <remoto> <local>         Baixa arquivo/pasta do smartphone
  easyarch-phone.sh forward <porta_pc> <porta_cel> Encaminha porta TCP via USB
  easyarch-phone.sh offload "<comando>"           Executa tarefa remota no Termux via SSH sobre USB

Variáveis opcionais:
  TERMUX_PORT=8022    Porta SSH do Termux
  TERMUX_USER=...     Usuário Termux (veja `whoami` no Termux, se necessário)
  ANDROID_SERIAL=...  Serial do dispositivo quando houver mais de um conectado
EOF
}

require_adb() {
    if ! command -v adb >/dev/null 2>&1; then
        printf '[ERRO] Binário "adb" não encontrado. Instale: sudo pacman -S android-tools\n' >&2
        exit 1
    fi
}

require_device() {
    require_adb
    if ! adb get-state >/dev/null 2>&1; then
        printf '[ERRO] Nenhum smartphone Android único/autorizado detectado via ADB.\n' >&2
        printf '       Verifique cabo USB, Depuração USB ou defina ANDROID_SERIAL se houver vários dispositivos.\n' >&2
        exit 1
    fi
}

action="${1:-}"
shift || true

case "$action" in
    status)
        require_adb
        adb devices -l
        ;;
    mirror)
        if ! command -v scrcpy >/dev/null 2>&1; then printf '[ERRO] Binário "scrcpy" não encontrado. Instale: sudo pacman -S scrcpy\n' >&2; exit 1; fi
        require_device
        # Bitrate e resolução moderados para baixo consumo de CPU/RAM na Vega 11
        exec scrcpy --max-size=1280 --max-fps=60 --video-bit-rate=6M --turn-screen-off
        ;;
    push)
        [[ $# -lt 2 ]] && { usage; exit 1; }
        require_device
        adb push "$1" "$2"
        ;;
    pull)
        [[ $# -lt 2 ]] && { usage; exit 1; }
        require_device
        adb pull "$1" "$2"
        ;;
    forward)
        [[ $# -lt 2 ]] && { usage; exit 1; }
        if ! [[ "$1" =~ ^[0-9]+$ && "$2" =~ ^[0-9]+$ ]] || (( 10#$1 < 1 || 10#$1 > 65535 || 10#$2 < 1 || 10#$2 > 65535 )); then
            printf '[ERRO] Portas inválidas: "%s" e "%s" (use inteiros entre 1 e 65535).\n' "$1" "$2" >&2
            exit 1
        fi
        require_device
        adb forward "tcp:${1}" "tcp:${2}"
        printf '[OK] Porta local tcp:%s encaminhada para dispositivo tcp:%s.\n' "$1" "$2"
        ;;
    offload)
        remote_cmd="${*:-}"
        [[ -z "$remote_cmd" ]] && { usage; exit 1; }
        require_device
        adb forward "tcp:${TERMUX_PORT}" "tcp:${TERMUX_PORT}"
        trap 'adb forward --remove "tcp:${TERMUX_PORT}" >/dev/null 2>&1 || true' EXIT
        dev_serial="$(adb get-serialno 2>/dev/null | tr -cd '[:alnum:]._-' || true)"
        dev_serial="${dev_serial:-${ANDROID_SERIAL:-default}}"
        dev_serial="$(printf '%s' "$dev_serial" | tr -cd '[:alnum:]._-')"
        dev_serial="${dev_serial:-default}"
        ssh_target="127.0.0.1"
        [[ -n "$TERMUX_USER" ]] && ssh_target="${TERMUX_USER}@127.0.0.1"
        printf '[EasyArch] Executando tarefa via túnel USB -> Termux SSH (%s:%s, alias termux-%s)...\n' "$ssh_target" "$TERMUX_PORT" "$dev_serial"
        ssh -p "$TERMUX_PORT" -o StrictHostKeyChecking=accept-new -o "HostKeyAlias=termux-${dev_serial}" "$ssh_target" "$remote_cmd"
        ;;
    ""|-h|--help|ajuda)
        usage
        exit 0
        ;;
    *)
        printf '[ERRO] Subcomando desconhecido: %s\n' "$action" >&2
        usage >&2
        exit 1
        ;;
esac
