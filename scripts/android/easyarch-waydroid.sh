#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Gerenciador Sob Demanda do Waydroid (com flock anti-corrida)
# Destino: ~/.local/bin/easyarch-waydroid.sh
#
# Correções v4.4:
#   - Valida presença do binário `waydroid` antes de acionar o systemd.
#   - `count_android_windows` retorna -1 (nunca 0) em falha transitória do
#     `hyprctl clients -j` ou `jq`, evitando auto-stop por falso negativo.
#   - Alerta caso `net.ipv4.ip_forward` esteja 0 após iniciar o container.
# ==============================================================================

set -euo pipefail

POLL_SECONDS=5
GRACE_CHECKS=3
STARTUP_GRACE_SECONDS=45
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/easyarch-waydroid-watch-$(id -u).lock"

usage() {
    cat <<'EOF'
Uso:
  easyarch-waydroid.sh start                  Inicia container e sessão Android sob demanda
  easyarch-waydroid.sh launch <pacote>        Inicia (se necessário) e abre o app Android
  easyarch-waydroid.sh install-apk <arq.apk>  Instala APK após checagem de extensão e SHA-256
  easyarch-waydroid.sh status                 Mostra container, sessão e janelas Android abertas
  easyarch-waydroid.sh stop                   Encerra sessão e container imediatamente
  easyarch-waydroid.sh watch                  Monitor protegido por flock (auto-stop ao fechar apps)
EOF
}

require_waydroid() {
    if ! command -v waydroid >/dev/null 2>&1; then
        printf '[ERRO] Pacote "waydroid" (AUR opcional) não está instalado.\n' >&2
        exit 1
    fi
}

can_inspect_windows() {
    command -v hyprctl >/dev/null 2>&1 \
        && command -v jq >/dev/null 2>&1 \
        && hyprctl monitors >/dev/null 2>&1
}

count_android_windows() {
    if ! can_inspect_windows; then
        echo -1
        return 0
    fi
    local raw cnt
    if ! raw="$(hyprctl clients -j 2>/dev/null)" || [[ -z "$raw" ]]; then
        echo -1
        return 0
    fi
    if ! cnt="$(printf '%s' "$raw" | jq -e '[.[] | select((.class // "" | test("waydroid"; "i")) or (.initialClass // "" | test("waydroid"; "i")))] | length' 2>/dev/null)"; then
        echo -1
        return 0
    fi
    printf '%s\n' "$cnt"
}

ensure_running() {
    require_waydroid
    if ! systemctl is-active --quiet waydroid-container.service 2>/dev/null; then
        printf '[EasyArch] Iniciando waydroid-container.service sob demanda...\n'
        sudo systemctl start waydroid-container.service
    fi
    if [[ -r /proc/sys/net/ipv4/ip_forward ]] && [[ "$(cat /proc/sys/net/ipv4/ip_forward)" != "1" ]]; then
        printf '[AVISO] net.ipv4.ip_forward=0; se o container ficar sem internet, verifique waydroid-net e etc/nftables.d/20-waydroid.nft.\n' >&2
    fi
    local wd_status
    wd_status="$(waydroid status 2>/dev/null || true)"
    if ! grep -qi 'Session:.*RUNNING' <<<"$wd_status"; then
        printf '[EasyArch] Iniciando sessão Waydroid...\n'
        nohup waydroid session start >/dev/null 2>&1 </dev/null &
        local started=0
        for _ in $(seq 1 20); do
            wd_status="$(waydroid status 2>/dev/null || true)"
            if grep -qi 'Session:.*RUNNING' <<<"$wd_status"; then
                started=1
                break
            fi
            sleep 1
        done
        if (( started == 0 )); then
            printf '[ERRO] Sessão Waydroid não atingiu estado RUNNING em 20s.\n' >&2
            return 1
        fi
    fi
}

stop_all() {
    local non_interactive="${1:-0}"
    printf '[EasyArch] Encerrando sessão e container Waydroid para liberar RAM...\n'
    command -v waydroid >/dev/null 2>&1 && waydroid session stop 2>/dev/null || true
    if systemctl is-active --quiet waydroid-container.service 2>/dev/null; then
        if (( non_interactive == 1 )); then
            if ! sudo -n systemctl stop waydroid-container.service 2>/dev/null; then
                command -v notify-send >/dev/null 2>&1 && notify-send "EasyArch Waydroid" \
                    "Sessão encerrada, mas o container exige 'easyarch android stop' (ou regra sudoers NOPASSWD para systemctl stop waydroid-container.service)." || true
                return 0
            fi
        else
            sudo systemctl stop waydroid-container.service || true
        fi
    fi
    printf '[EasyArch] Waydroid encerrado.\n'
}

watch_loop() {
    if ! can_inspect_windows; then
        printf '[AVISO] Auto-stop do Waydroid requer Hyprland + jq ativos; encerrando monitor sem parar o Waydroid.\n' >&2
        exit 0
    fi
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
        exit 0
    fi
    local seen_window=0
    local waited=0
    local zero_streak=0
    local err_streak=0
    local max_err_streak=6
    while true; do
        sleep "$POLL_SECONDS"
        local count
        count="$(count_android_windows)"
        if (( count < 0 )); then
            err_streak=$((err_streak + 1))
            if (( err_streak >= max_err_streak )); then
                exit 0
            fi
            continue
        fi
        err_streak=0
        if (( count > 0 )); then
            seen_window=1
            zero_streak=0
        elif (( seen_window == 0 && waited < STARTUP_GRACE_SECONDS )); then
            waited=$((waited + POLL_SECONDS))
        else
            zero_streak=$((zero_streak + 1))
            if (( zero_streak >= GRACE_CHECKS )); then
                stop_all 1
                break
            fi
        fi
    done
}

action="${1:-}"
shift || true

case "$action" in
    start)
        ensure_running
        ;;
    launch)
        pkg="${1:-}"
        [[ -z "$pkg" ]] && { usage; exit 1; }
        ensure_running
        waydroid app launch "$pkg"
        nohup "$0" watch >/dev/null 2>&1 </dev/null &
        ;;
    install-apk)
        apk="${1:-}"
        [[ -z "$apk" || ! -f "$apk" ]] && { printf '[ERRO] APK inválido.\n' >&2; exit 1; }
        if [[ "${apk,,}" != *.apk ]]; then
            printf '[ERRO] O arquivo informado não possui extensão .apk.\n' >&2
            exit 1
        fi
        abs_apk="$(readlink -f -- "$apk")"
        sha="$(sha256sum "$abs_apk" | awk '{print $1}')"
        printf 'APK: %s\nSHA-256: %s\n' "$abs_apk" "$sha"
        read -r -p "Confirmar instalação deste APK no Waydroid? (digite SIM): " ans
        [[ "$ans" != "SIM" ]] && { printf '[INFO] Instalação cancelada.\n'; exit 0; }
        ensure_running
        waydroid app install "$abs_apk"
        ;;
    status)
        printf 'Container systemd: %s\n' "$(systemctl is-active waydroid-container.service 2>/dev/null || echo inactive)"
        win_cnt="$(count_android_windows)"
        if (( win_cnt < 0 )); then
            printf 'Janelas Android abertas (Hyprland): indisponível (fora do Hyprland)\n'
        else
            printf 'Janelas Android abertas (Hyprland): %s\n' "$win_cnt"
        fi
        if command -v waydroid >/dev/null 2>&1; then
            waydroid status 2>/dev/null || true
        else
            printf 'Binário waydroid: não instalado (AUR opcional).\n'
        fi
        ;;
    stop)
        stop_all 0
        ;;
    watch)
        watch_loop
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
