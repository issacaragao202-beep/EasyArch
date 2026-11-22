#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Comando Único Mestre com Checagem Real de Dependências
# Destino: ~/.local/bin/easyarch (também chamado por SUPER + H)
# ==============================================================================

set -uo pipefail

BIN_DIR="${HOME}/.local/bin"

require_bin() {
    local bin_name="$1"
    local fase_hint="$2"
    if [[ ! -x "${BIN_DIR}/${bin_name}" ]]; then
        printf '[EasyArch] Recurso "%s" ainda não instalado.\n' "$bin_name" >&2
        printf '           Rode ./scripts/instalacao/easyarch-setup.sh e marque: %s\n' "$fase_hint" >&2
        exit 1
    fi
}

usage() {
    cat <<'EOF'
EasyArch v5.4 — Comando Único Simplificado
Uso:
  easyarch                  Abre o menu visual fácil (Rofi ou Terminal)
  easyarch loja             Abre a Loja Curada de Apps em 1 clique
  easyarch instalar <nome>  Busca e instala app (Pacman oficial ou Flatpak)
  easyarch remover <nome>   Remove pacote com segurança
  easyarch atualizar        Atualização segura com verificação real de snapshot Btrfs
  easyarch leve             Liga/desliga Modo Ultra-Leve (libera RAM)
  easyarch perfil [modo]    Troca perfil (economico | equilibrado | jogos | dev | status)
  easyarch wifi             Abre seletor fácil de Wi-Fi e redes (nmtui)
  easyarch energia          Menu visual: Bloquear, Suspender, Reiniciar ou Desligar
  easyarch memoria          Mostra uso real de RAM, ZRAM e top processos por PSS
  easyarch seguranca        Verifica AppArmor, nftables e DNS-over-TLS ponta a ponta
  easyarch android [acao]   Gerencia Waydroid sob demanda
  easyarch celular [acao]   Integra smartphone USB (ADB / scrcpy / Termux SSH)
  easyarch dev              Mostra como ativar Java 17 + Gradle (ArcForge)
  easyarch limpar           Limpeza segura de cache (mantém últimas 2 versões)
  easyarch atalhos          Mostra cola rápida de atalhos na tela
  easyarch sos              Guia de recuperação de emergência
EOF
}

# Mostra as N primeiras linhas da saída de um comando; "Nenhum resultado." só se a saída for vazia.
# Evita o falso "Nenhum resultado" causado por SIGPIPE do `head` sob pipefail.
show_first_lines() {
    local n="$1"; shift
    local out
    out="$("$@" 2>/dev/null || true)"
    if [[ -n "$out" ]]; then
        printf '%s\n' "$out" | head -n "$n" || true
    else
        printf 'Nenhum resultado.\n'
    fi
}

cmd_instalar() {
    local query="${1:-}"
    [[ -z "$query" ]] && read -r -p "Qual programa você quer buscar/instalar? " query
    [[ -z "$query" ]] && exit 0
    printf '\n=== [1] Repositórios Oficiais Arch (pacman) ===\n'
    show_first_lines 20 pacman -Ss "$query"
    if command -v flatpak >/dev/null 2>&1; then
        printf '\n=== [2] Flathub Isolado (Flatpak) ===\n'
        show_first_lines 10 flatpak search "$query"
    fi
    printf '\n1) Pacote oficial (pacman) | 2) Flatpak isolado | 3) Cancelar\n'
    read -r -p "Escolha (1/2/3): " opt
    case "$opt" in
        1) read -r -p "Nome EXATO do pacote pacman: " pkg; [[ -n "$pkg" ]] && sudo pacman -S --needed "$pkg" ;;
        2) if ! command -v flatpak >/dev/null 2>&1; then printf '[ERRO] Flatpak não instalado.\n' >&2; exit 1; fi; read -r -p "ID do app Flatpak: " app; if [[ -n "$app" ]]; then flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && flatpak install --user flathub "$app"; fi ;;
        *) printf '[EasyArch] Cancelado.\n' ;;
    esac
}

cmd_remover() {
    local pkg="${1:-}"
    [[ -z "$pkg" ]] && read -r -p "Pacote pacman a remover: " pkg
    [[ -z "$pkg" ]] && exit 0
    sudo pacman -Rs "$pkg"
}

cmd_limpar() {
    du -sh /var/cache/pacman/pkg 2>/dev/null || true
    read -r -p "Limpar cache antigo (pacman + Flatpaks não usados) mantendo 2 versões? (s/N): " ans
    if [[ "${ans,,}" != "s" && "${ans,,}" != "sim" ]]; then
        printf '[EasyArch] Limpeza cancelada.\n'
        return 0
    fi
    if command -v paccache >/dev/null 2>&1; then
        sudo paccache -rk2 || printf '[AVISO] Não foi possível limpar o cache do pacman.\n' >&2
    else
        printf '[AVISO] Instale pacman-contrib para usar paccache.\n'
    fi
    if command -v flatpak >/dev/null 2>&1; then
        flatpak uninstall --user --unused -y 2>/dev/null || true
    fi
    printf '[OK] Limpeza segura concluída.\n'
}

# Permite `source` nos testes sem executar o despacho de comandos
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    return 0
fi

action="${1:-menu}"
shift || true

case "$action" in
    menu)       require_bin "easyarch-hub.sh" "Etapa 1/4 (Desktop)"; exec "${BIN_DIR}/easyarch-hub.sh" ;;
    loja)       require_bin "easyarch-loja.sh" "Etapa 1/4 (Desktop)"; exec "${BIN_DIR}/easyarch-loja.sh" ;;
    instalar)   cmd_instalar "${1:-}" ;;
    remover)    cmd_remover "${1:-}" ;;
    atualizar)  require_bin "easyarch-update-safe.sh" "Etapa 1/4 (Desktop)"; exec "${BIN_DIR}/easyarch-update-safe.sh" ;;
    leve)       require_bin "easyarch-lite-mode.sh" "Etapa 1/4 (Desktop)"; exec "${BIN_DIR}/easyarch-lite-mode.sh" "${1:-toggle}" ;;
    zen)        require_bin "easyarch-zen.sh" "Etapa 1/4 (Desktop)"; exec "${BIN_DIR}/easyarch-zen.sh" "${1:-toggle}" ;;
    calc)       require_bin "easyarch-calc.sh" "Etapa 1/4 (Desktop)"; exec "${BIN_DIR}/easyarch-calc.sh" "$@" ;;
    tema)       require_bin "easyarch-theme.sh" "Etapa 1/4 (Desktop)"; exec "${BIN_DIR}/easyarch-theme.sh" "${1:-}" ;;
    perfil)     require_bin "easyarch-profile.sh" "Etapa 3/4 (Dev/Perfis)"; exec "${BIN_DIR}/easyarch-profile.sh" "${1:-status}" ;;
    wifi|rede)  require_bin "easyarch-rede.sh" "Etapa 1/4 (Desktop)"; exec "${BIN_DIR}/easyarch-rede.sh" ;;
    energia)    require_bin "easyarch-power.sh" "Etapa 1/4 (Desktop)"; exec "${BIN_DIR}/easyarch-power.sh" ;;
    memoria)    require_bin "01-relatorio-memoria.sh" "Etapa 1/4 ou 4/4"; exec "${BIN_DIR}/01-relatorio-memoria.sh" --show easyarch-check ;;
    seguranca)  require_bin "security-status.sh" "Etapa 1/4"; require_bin "02-validar-fase1.sh" "Etapa 1/4 ou 4/4"; "${BIN_DIR}/security-status.sh" --human; echo ""; exec "${BIN_DIR}/02-validar-fase1.sh" ;;
    android)    require_bin "easyarch-waydroid.sh" "Etapa 2/4 (Híbrido)"; exec "${BIN_DIR}/easyarch-waydroid.sh" "${1:-status}" "${@:2}" ;;
    celular)    require_bin "easyarch-phone.sh" "Etapa 3/4 (Dev/Mobile)"; exec "${BIN_DIR}/easyarch-phone.sh" "${1:-status}" "${@:2}" ;;
    dev)        require_bin "easyarch-arcforge-env.sh" "Etapa 3/4 (Dev)"; printf 'Para ativar Java 17 (ArcForge) neste terminal, rode:\n  Fish: source ~/.local/bin/easyarch-arcforge-env.fish\n  Bash: source ~/.local/bin/easyarch-arcforge-env.sh\n' ;;
    limpar)     cmd_limpar ;;
    atalhos)    require_bin "easyarch-cheatsheet.sh" "Etapa 1/4 (Desktop)"; exec "${BIN_DIR}/easyarch-cheatsheet.sh" ;;
    sos)        require_bin "easyarch-sos.sh" "Etapa 1/4 (Desktop)"; exec "${BIN_DIR}/easyarch-sos.sh" ;;
    ajuda|-h|--help) usage ;;
    *)          printf '[EasyArch] Opção desconhecida: "%s"\n\n' "$action"; usage; exit 1 ;;
esac
