#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Executor Sob Demanda de Agentes CLI (Zero RAM em Background)
# Destino: ~/.local/bin/easyarch-agents.sh
#
# Correções v4.4:
#   - Injeta a chave via `export` + `exec` em vez de `env VAR=...`, evitando
#     exposição do segredo em /proc/<pid>/cmdline.
#   - Verifica se o cofre `pass` foi inicializado antes de chamar `pass insert`.
# ==============================================================================

set -euo pipefail

usage() {
    cat <<'EOF'
Uso:
  easyarch-agents.sh run <agente> [args...]   Executa agente sob demanda (omniroute|opencode|codex|hermes)
  easyarch-agents.sh set-key <agente>         Salva chave de API (omniroute|opencode|codex|hermes)
  easyarch-agents.sh status                   Lista disponibilidade dos binários de agentes CLI
EOF
}

is_valid_agent() {
    case "${1:-}" in
        omniroute|opencode|codex|hermes) return 0 ;;
        *) return 1 ;;
    esac
}

has_secret_service() {
    command -v secret-tool >/dev/null 2>&1 \
        && command -v busctl >/dev/null 2>&1 \
        && busctl --user list 2>/dev/null \
           | awk '$1 == "org.freedesktop.secrets" && $2 ~ /^[0-9]+$/ { found=1 } END { exit !found }'
}

fetch_secret() {
    local key_name="$1"
    local val=""
    if has_secret_service; then
        val="$(secret-tool lookup service easyarch-ai key "$key_name" 2>/dev/null || true)"
    fi
    if [[ -z "$val" ]] && command -v pass >/dev/null 2>&1; then
        val="$(pass show "easyarch/api/${key_name}" 2>/dev/null | head -n 1 || true)"
    fi
    printf '%s' "$val"
}

action="${1:-}"
shift || true

case "$action" in
    set-key)
        kname="${1:-}"
        if ! is_valid_agent "$kname"; then
            printf '[ERRO] Nome de agente inválido: "%s" (use: omniroute, opencode, codex ou hermes).\n' "$kname" >&2
            usage
            exit 1
        fi
        if has_secret_service; then
            secret-tool store --label="EasyArch API: ${kname}" service easyarch-ai key "$kname"
            printf '[OK] Chave "%s" armazenada no keyring (libsecret).\n' "$kname"
        elif command -v pass >/dev/null 2>&1; then
            store_dir="${PASSWORD_STORE_DIR:-${HOME}/.password-store}"
            if [[ ! -f "${store_dir}/.gpg-id" ]]; then
                printf '[ERRO] Cofre `pass` ainda não inicializado em %s.\n' "$store_dir" >&2
                printf '       Inicialize primeiro com: gpg --full-generate-key && pass init <ID_GPG>\n' >&2
                exit 1
            fi
            pass insert "easyarch/api/${kname}"
        else
            printf '[ERRO] Instale e inicialize `pass` (gnupg) ou um daemon Secret Service (ex.: gnome-keyring).\n' >&2
            exit 1
        fi
        ;;
    run)
        agent="${1:-}"
        shift || true
        case "$agent" in
            omniroute) bin="omniroute"; env_var="OMNIROUTE_API_KEY" ;;
            opencode)  bin="opencode";  env_var="OPENAI_API_KEY" ;;
            codex)     bin="codex";     env_var="OPENAI_API_KEY" ;;
            hermes)    bin="hermes";    env_var="HERMES_API_KEY" ;;
            *) printf '[ERRO] Agente desconhecido: %s\n' "$agent" >&2; usage; exit 1 ;;
        esac
        if ! command -v "$bin" >/dev/null 2>&1; then
            printf '[ERRO] Binário "%s" não encontrado no PATH.\n' "$bin" >&2
            exit 1
        fi
        secret_val="$(fetch_secret "$agent")"
        if [[ -n "$secret_val" ]]; then
            export "${env_var}=${secret_val}"
            unset secret_val
            exec "$bin" "$@"
        else
            printf '[AVISO] Nenhuma chave encontrada no cofre para "%s"; executando sem injeção automática.\n' "$agent"
            exec "$bin" "$@"
        fi
        ;;
    status)
        for b in omniroute opencode codex hermes; do
            if command -v "$b" >/dev/null 2>&1; then
                printf '[OK]      %s (%s)\n' "$b" "$(command -v "$b")"
            else
                printf '[AUSENTE] %s (instalar sob demanda quando for usar)\n' "$b"
            fi
        done
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
