#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Arquitetura Extensível de Assistente de Terminal (Offline-Safe)
# Destino: ~/.local/bin/easyarch-ai-assistant.sh
#
# Regras obrigatórias de segurança:
#   - O terminal tradicional nunca depende deste script nem de internet.
#   - Classifica comandos em SEGURO, PRIVILEGIADO ou DESTRUTIVO.
#   - Nunca executa comandos destrutivos ou privilegiados automaticamente.
# ==============================================================================

set -uo pipefail

usage() {
    cat <<'EOF'
Uso:
  easyarch-ai explicar "<comando>"   Explica um comando usando documentação local (tldr/man) e checa riscos
  easyarch-ai checar "<comando>"     Classifica se o comando é seguro, privilegiado ou destrutivo
  easyarch-ai status                 Mostra o estado do assistente e backend configurado
EOF
}

classify_command() {
    local cmd="$1"
    local sq="'"
    # sh/bash/eval/source executando saída de curl/wget: bash <(curl ..), sh -c "$(curl ..)", bash <<< "$(curl ..)"
    local re_shell_fetch='((ba|z|da|fi)?sh|eval|source|\.)[[:space:]]+((-[a-zA-Z]+|/dev/stdin)[[:space:]]+)*(<<<[[:space:]]*)?.?(<\(|\$\()[[:space:]]*(curl|wget)'
    local prefix="(^|[[:space:]\;\&\|\(\"\`${sq}])([a-zA-Z0-9_./-]*/)?\\\\?"
    local blk_devs='/dev/(sd|nvme|hd|vd|disk|mmcblk|mapper/|dm-|md[0-9]|loop)'

    if [[ "$cmd" =~ ${prefix}rm[[:space:]]+((-[a-zA-Z]*[rR][a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*[rR]|--recursive|--force)[[:space:]]*)+ ]] \
       || [[ "$cmd" =~ ${prefix}rm[[:space:]]+.*(-[rR][[:space:]]+-f|-f[[:space:]]+-[rR]|--recursive.*--force|--force.*--recursive) ]] \
       || [[ "$cmd" =~ ${prefix}rm[[:space:]]+.*(-[a-zA-Z]*[rRf][a-zA-Z]*|--recursive|--force)[[:space:]]+(--[[:space:]]+)?(/(etc|boot|usr|var|bin|lib|sbin|sys|proc|home|\*)?|~|\$HOME|\$\{HOME\})([[:space:]\"\'\`]|/|$) ]] \
       || [[ "$cmd" =~ ${prefix}dd[[:space:]]+.*of= ]] \
       || [[ "$cmd" =~ ${prefix}(mkfs(\.|[[:space:]])|mkswap|wipefs|blkdiscard|fdisk|parted|sgdisk|shred) ]] \
       || [[ "$cmd" =~ ${prefix}hdparm[[:space:]]+.*--security-erase ]] \
       || [[ "$cmd" =~ ${prefix}cryptsetup[[:space:]]+(.*[[:space:]])?(luksFormat|luksErase|erase)([[:space:]]|$) ]] \
       || [[ "$cmd" =~ ${prefix}nvme[[:space:]]+(.*[[:space:]])?(format|sanitize)([[:space:]]|$) ]] \
       || [[ "$cmd" =~ ${prefix}btrfs[[:space:]]+(device[[:space:]]+(remove|delete)|subvolume[[:space:]]+delete)([[:space:]]|$) ]] \
       || [[ "$cmd" =~ ${prefix}pacman[[:space:]]+-[a-zA-Z]*S[a-zA-Z]*cc([[:space:]]|$) ]] \
       || [[ "$cmd" =~ \>\|?[[:space:]]*/proc/sysrq-trigger([[:space:]]|$) ]] \
       || [[ "$cmd" =~ ${prefix}chmod[[:space:]]+(-R|--recursive)[[:space:]]+(0?777|0?000|a\+rwx) ]] \
       || [[ "$cmd" =~ ${prefix}chmod[[:space:]]+(0?777|0?000|a\+rwx)[[:space:]]+(-R|--recursive) ]] \
       || [[ "$cmd" =~ (curl|wget)[[:space:]].*\|[[:space:]]*((sudo|doas|env)([[:space:]]+-[a-zA-Z0-9-]+([[:space:]]+[^[:space:]\|]+)?)*[[:space:]]+)*([a-zA-Z0-9_./-]*/)?((ba|z|da|fi)?sh|python[23]?|perl|ruby|node(js)?|php|lua|awk)([[:space:]]|$) ]] \
       || [[ "$cmd" =~ \>\|?[[:space:]]*${blk_devs} ]] \
       || [[ "$cmd" =~ ${prefix}(tee|cp|mv)[[:space:]]+(.*[[:space:]])?${blk_devs} ]] \
       || [[ "$cmd" =~ ${prefix}find[[:space:]]+.*[[:space:]](-delete|-exec[[:space:]]+([a-zA-Z0-9_./-]*/)?rm)([[:space:]]|$) ]] \
       || [[ "$cmd" =~ ${prefix}mv[[:space:]]+.*[[:space:]]/dev/null([[:space:]]|$) ]] \
       || [[ "$cmd" =~ :[[:space:]]*\([[:space:]]*\)[[:space:]]*\{ ]] \
       || [[ "$cmd" =~ ${re_shell_fetch} ]] \
       || [[ "$cmd" =~ ${prefix}git[[:space:]]+(clean[[:space:]]+(.*[[:space:]])?(-[a-zA-Z]*f|--force)|reset[[:space:]]+(.*[[:space:]])?--hard|push[[:space:]]+(.*[[:space:]])?(--force|-f)([[:space:]]|$)) ]] \
       || [[ "$cmd" =~ ${prefix}truncate[[:space:]]+(.*[[:space:]])?(-s[[:space:]]*0|--size(=|[[:space:]]+)0)([[:space:]]|$) ]] \
       || [[ "$cmd" =~ ${prefix}mv[[:space:]]+(-[a-zA-Z-]+[[:space:]]+)*(/(etc|boot|usr|var|bin|lib|sbin|home)?)/?[[:space:]] ]] \
       || [[ "$cmd" =~ ${prefix}(iptables|ip6tables)[[:space:]]+(.*[[:space:]])?(-F|--flush)([[:space:]]|$) ]] \
       || [[ "$cmd" =~ ${prefix}nft[[:space:]]+flush[[:space:]]+ruleset ]] \
       || [[ "$cmd" =~ ${prefix}(kill|pkill|killall)[[:space:]]+(-9|-KILL|-SIGKILL|-s[[:space:]]+(9|KILL|SIGKILL))[[:space:]]+(-1|1)([[:space:]]|$) ]] \
       || [[ "$cmd" =~ (^|[[:space:]\;\&\|\(])1?\>\|?[[:space:]]*(/etc/|/boot/|~/\.|\$HOME/\.|\$\{HOME\}/\.) ]] \
       || [[ "$cmd" =~ ${prefix}(chown|chmod)[[:space:]]+(-[a-zA-Z]*R[a-zA-Z]*|--recursive)[[:space:]]+(--?[a-zA-Z0-9-]+[[:space:]]+)*[^[:space:]-][^[:space:]]*[[:space:]]+(/(etc|boot|usr|var|bin|lib|sbin|home)?|~|\$HOME)/?([[:space:]]|$) ]] \
       || [[ "$cmd" =~ ${prefix}chmod[[:space:]]+(0?000|0?777|a-rwx|a\+rwx)[[:space:]]+/(etc|boot|usr|var|bin|lib|sbin)?([[:space:]]|/|$) ]] \
       || [[ "$cmd" =~ ${prefix}pacman[[:space:]]+-[a-zA-Z]*R[a-zA-Z]*dd ]] \
       || [[ "$cmd" =~ ${prefix}pacman[[:space:]]+.*(-[a-zA-Z]*R|--remove).*--nodeps.*--nodeps ]] \
       || [[ "$cmd" =~ ${prefix}pacman[[:space:]]+(-[a-zA-Z]*R[a-zA-Z]*|--remove)[[:space:]]+(.*[[:space:]])?(base|glibc|linux(-zen|-lts|-hardened)?|systemd|pacman|bash|coreutils|filesystem)([[:space:]]|$) ]]; then
        printf 'DESTRUTIVO'
    elif [[ "$cmd" =~ ${prefix}(sudo|doas|su|systemctl|pacman|btrfs|cryptsetup|nft|chown|chmod|mount|umount)([[:space:]\"\'\`]|$) ]]; then
        printf 'PRIVILEGIADO'
    else
        printf 'SEGURO'
    fi
}

extract_base_bin() {
    local cmd="$1"
    local -a tokens=()
    local cur="" in_sq=0 in_dq=0 escaped=0 ch j
    for (( j = 0; j < ${#cmd}; j++ )); do
        ch="${cmd:j:1}"
        if (( escaped )); then
            cur+="$ch"
            escaped=0
        elif (( in_sq )); then
            if [[ "$ch" == "'" ]]; then in_sq=0; else cur+="$ch"; fi
        elif (( in_dq )); then
            if [[ "$ch" == "\\" ]]; then
                escaped=1
            elif [[ "$ch" == '"' ]]; then
                in_dq=0
            else
                cur+="$ch"
            fi
        else
            case "$ch" in
                "\\") escaped=1 ;;
                "'") in_sq=1 ;;
                '"') in_dq=1 ;;
                ";"|"&"|"|")
                    if [[ -n "$cur" ]]; then tokens+=("$cur"); cur=""; fi
                    break
                    ;;
                [[:space:]])
                    if [[ -n "$cur" ]]; then tokens+=("$cur"); cur=""; fi
                    ;;
                *) cur+="$ch" ;;
            esac
        fi
    done
    [[ -n "$cur" ]] && tokens+=("$cur")

    local i=0
    while (( i < ${#tokens[@]} )); do
        local tok="${tokens[$i]}"
        local base="${tok#\\}"
        base="$(basename -- "$base" 2>/dev/null || printf '%s' "$base")"
        case "$base" in
            sudo|doas)
                i=$((i + 1))
                while (( i < ${#tokens[@]} )) && [[ "${tokens[$i]}" == -* ]]; do
                    if [[ "${tokens[$i]}" == "--" ]]; then
                        i=$((i + 1)); break
                    elif [[ "${tokens[$i]}" =~ ^-(u|g|C|D|p|r|t)$ ]]; then
                        i=$((i + 2))
                    else
                        i=$((i + 1))
                    fi
                done
                ;;
            env)
                i=$((i + 1))
                while (( i < ${#tokens[@]} )) && [[ "${tokens[$i]}" == -* ]]; do
                    if [[ "${tokens[$i]}" == "--" ]]; then
                        i=$((i + 1)); break
                    elif [[ "${tokens[$i]}" == "-S" ]]; then
                        if (( i + 1 < ${#tokens[@]} )); then
                            extract_base_bin "${tokens[$((i + 1))]}"
                            return 0
                        fi
                        return 0
                    elif [[ "${tokens[$i]}" =~ ^-(u|C)$ ]]; then
                        i=$((i + 2))
                    else
                        i=$((i + 1))
                    fi
                done
                ;;
            command)
                i=$((i + 1))
                while (( i < ${#tokens[@]} )) && [[ "${tokens[$i]}" == -* ]]; do
                    if [[ "${tokens[$i]}" == "--" ]]; then
                        i=$((i + 1)); break
                    else
                        i=$((i + 1))
                    fi
                done
                ;;
            exec)
                i=$((i + 1))
                while (( i < ${#tokens[@]} )) && [[ "${tokens[$i]}" == -* ]]; do
                    if [[ "${tokens[$i]}" == "--" ]]; then
                        i=$((i + 1)); break
                    elif [[ "${tokens[$i]}" == "-a" ]]; then
                        i=$((i + 2))
                    else
                        i=$((i + 1))
                    fi
                done
                ;;
            nohup)
                i=$((i + 1))
                ;;
            *)
                if [[ "$tok" == *=* && "$tok" != =* ]]; then
                    i=$((i + 1))
                    continue
                fi
                tok="${tok#\\}"
                basename -- "$tok" 2>/dev/null || printf '%s' "$tok"
                return 0
                ;;
        esac
    done
}

cmd_action="${1:-}"
shift || true

case "$cmd_action" in
    checar)
        target="${*:-}"
        [[ -z "$target" ]] && { usage; exit 1; }
        risk="$(classify_command "$target")"
        printf '[EasyArch AI] Comando: %s\n' "$target"
        printf '[EasyArch AI] Classificação de risco: %s\n' "$risk"
        case "$risk" in
            DESTRUTIVO)
                printf '[BLOQUEADO] Operação potencialmente destrutiva. Exige revisão manual e confirmação explícita.\n'
                ;;
            PRIVILEGIADO)
                printf '[ATENÇÃO] Operação administrativa/privilegiada. Revise o alvo antes de autorizar.\n'
                ;;
            SEGURO)
                printf '[OK] Nenhum padrão destrutivo ou privilegiado óbvio detectado.\n'
                ;;
        esac
        ;;
    explicar)
        target="${*:-}"
        [[ -z "$target" ]] && { usage; exit 1; }
        base_bin="$(extract_base_bin "$target")"
        risk="$(classify_command "$target")"
        printf '[EasyArch AI] Risco estimado: %s\n\n' "$risk"
        if [[ -z "$base_bin" ]]; then
            printf 'Não foi possível identificar o comando base em "%s".\n' "$target"
            exit 1
        fi
        if command -v tldr >/dev/null 2>&1; then
            tldr "$base_bin" 2>/dev/null || man -f "$base_bin" 2>/dev/null || printf 'Sem resumo local para "%s".\n' "$base_bin"
        else
            man -f "$base_bin" 2>/dev/null || printf 'Instale tealdeer (tldr) para exemplos práticos locais.\n'
        fi
        ;;
    status)
        printf 'Modo offline local (tldr/man + classificador de risco): ATIVO\n'
        printf 'Backend de IA externo (Fase 4): %s\n' "${EASYARCH_AI_BACKEND:-nao-configurado (opcional)}"
        ;;
    ""|-h|--help|ajuda)
        usage
        exit 0
        ;;
    *)
        printf '[ERRO] Subcomando desconhecido: %s\n' "$cmd_action" >&2
        usage >&2
        exit 1
        ;;
esac
