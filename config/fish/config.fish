# ==============================================================================
# EasyArch — Fish Shell Inteligente para Iniciantes
# Destino: ~/.config/fish/config.fish
#
# Recursos:
#   - Realce de sintaxe e destaque visual para comandos inválidos (nativo Fish)
#   - Prompt Starship (prata e ciano glacial)
#   - Zoxide (navegação inteligente entre diretórios)
#   - FZF (pesquisa interativa no histórico com Ctrl+R)
#   - Tealdeer (tldr — exemplos práticos)
#   - Pkgfile (sugere pacote para comandos ausentes)
#   - Pay-Respects (correção interativa quando instalado)
#   - Assistente extensível offline-safe (`easyarch-ai`)
# ==============================================================================

set -g fish_greeting ""

# Cores Glacial Silver para realce de sintaxe no Fish
set -g fish_color_normal c9d4e0
set -g fish_color_command 7dd3fc
set -g fish_color_param edf4fa
set -g fish_color_quote a7f3d0
set -g fish_color_comment 64748b
set -g fish_color_error f87171 --bold
set -g fish_color_autosuggestion 64748b

# Adiciona scripts locais ao PATH
fish_add_path -g "$HOME/.local/bin"

if status is-interactive
    # Starship prompt
    if type -q starship
        starship init fish | source
    end

    # Zoxide (comando `z` para navegação inteligente)
    if type -q zoxide
        zoxide init fish | source
    end

    # FZF (Ctrl+R para busca interativa no histórico)
    if type -q fzf
        fzf --fish | source
    end

    # Pay-Respects (opcional do AUR; nunca quebra o shell se ausente)
    if type -q pay-respects
        pay-respects fish --alias f | source
    end

    # Pkgfile (identifica qual pacote Arch fornece um comando ausente)
    if test -r /usr/share/doc/pkgfile/command-not-found.fish
        source /usr/share/doc/pkgfile/command-not-found.fish
    end
end

# Inicia o Hyprland automaticamente ao logar no tty1 (sem gerenciador de login).
# Para desativar: touch ~/.config/easyarch/no-autostart
if status is-login
    and test -z "$WAYLAND_DISPLAY" -a -z "$DISPLAY"
    and not test -e "$HOME/.config/easyarch/no-autostart"
    set -l cur_tty (tty 2>/dev/null)
    if test "$cur_tty" = "/dev/tty1"
        if type -q start-hyprland
            exec start-hyprland
        else if type -q Hyprland
            exec Hyprland
        end
    end
end

# Atalhos seguros para iniciantes
alias ll='ls -lh --color=auto'
alias la='ls -lah --color=auto'
alias ajuda='tldr'
alias easyarch-ai='$HOME/.local/bin/easyarch-ai-assistant.sh'
