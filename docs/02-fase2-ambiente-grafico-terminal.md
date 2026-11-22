# Projeto Linux Forge — Fase 2: Ambiente Gráfico (Glacial Silver) e Terminal Inteligente

> **Hardware-alvo:** AMD Ryzen 5 3400G · Radeon Vega 11 (AMDGPU + Mesa + RADV) · ~6 GB RAM utilizáveis · Monitor 1920×1080 @ 75 Hz · Wayland.

---

## 1. Identidade Visual — Glacial Silver

A identidade **Glacial Silver** combina vidro escuro, acabamento metálico prateado e detalhes pontuais em ciano glacial — limpa, minimalista e sem neon excessivo:

| Token | Hex | Aplicação |
| :--- | :---: | :--- |
| **Fundo Profundo (Preto Azulado)** | `#0B0F14` | Fundo do terminal, painéis e superfícies base |
| **Superfície Grafite** | `#141A23` | Cards, barras, dock e janelas do lançador |
| **Borda Metálica (Prata Escura)** | `#2C3645` | Bordas de janelas inativas e divisórias |
| **Prata Polida** | `#C9D4E0` | Texto principal, ícones e bordas sutis |
| **Branco Frio** | `#EDF4FA` | Títulos, hora e foco ativo |
| **Ciano Glacial (Destaque)** | `#7DD3FC` | Borda da janela ativa, workspace atual e alertas informativos |
| **Alerta / Erro** | `#F87171` | Comandos inválidos no Fish e falhas no indicador de segurança |

---

## 2. Escolhas Técnicas e Justificativas (Foco em RAM e Vega 11)

| Componente | Pacote Escolhido | Origem | Justificativa Técnica |
| :--- | :--- | :---: | :--- |
| **Compositor** | `hyprland` | Oficial (`extra`) | Wayland nativo, baixo consumo de RAM, `misc:vfr = true` (reduz quadros em tela ociosa) e `blur`/`shadow` desativados por padrão para não competir pela largura de banda single-channel da Vega 11 ([Hyprland Wiki](https://wiki.hypr.land/0.45.0/Configuring/Performance/)). |
| **Barra Superior** | `waybar` | Oficial (`extra`) | Barra fina (~28 px) em C++/GTK3 com módulos nativos de CPU, RAM, temperatura, rede, áudio PipeWire, tray e indicador customizado de segurança. |
| **Dock Inferior** | `nwg-dock-hyprland` | Oficial (`extra`) | Dock flutuante centralizado nativo para Hyprland ([nwg-dock-hyprland 0.4.11](https://archlinux.org/packages/extra/x86_64/nwg-dock-hyprland/)), com ocultação automática (`-d`) e indicadores de aplicativos abertos. |
| **Lançador (Spotlight)** | `rofi` (v2.1+ Wayland) + `fd` | Oficial (`extra`) | Suporte Wayland nativo no pacote oficial ([rofi 2.1.1](https://archlinux.org/packages/extra/x86_64/rofi/)); abre instantaneamente e encerrado libera 100% da RAM. Busca arquivos sob demanda com `fd`, sem indexadores residentes em memória. |
| **Notificações** | `mako` | Oficial (`extra`) | Daemon Wayland levíssimo (< 5 MB RAM); evita travamentos de apps que aguardam resposta do barramento de notificações ([Hyprland FAQ](https://wiki.hypr.land/0.48.0/FAQ/)). |
| **Pilha Gráfica AMD** | `mesa`, `vulkan-radeon`, `lib32-vulkan-radeon`, `lib32-mesa` | Oficial (`extra`/`multilib`) | Drivers abertos AMDGPU + Mesa + RADV com aceleração Vulkan 64/32 bits e decodificação de vídeo por hardware VA-API ([ArchWiki AMDGPU](https://wiki.archlinux.org/title/AMDGPU)). |
| **Áudio** | `pipewire`, `pipewire-alsa`, `pipewire-pulse`, `pipewire-jack`, `wireplumber` | Oficial (`extra`) | Substitui PulseAudio/JACK com menor latência e ativação sob demanda via sockets de usuário ([ArchWiki PipeWire](https://wiki.archlinux.org/title/PipeWire)). |
| **Terminal Inteligente** | `foot`, `fish`, `starship`, `fzf`, `zoxide`, `tealdeer`, `pkgfile` + `pay-respects-bin` (AUR) | Oficial + 1 AUR opcional | `foot` consome fração da RAM de terminais Electron/GPU pesados; `fish` oferece sintaxe e sugestões nativas; `pay-respects` é opcional do AUR ([pay-respects-bin](https://aur.archlinux.org/packages/pay-respects-bin)) após revisão do PKGBUILD. |

---

## 3. Monitor 1920×1080 @ 75 Hz e Cores

- O `hyprland.conf` configura `monitor = , 1920x1080@75, auto, 1` (escala inteira `1`, evitando sobrecarga de fractional scaling na Vega 11). Caso o monitor negocie outro modo via EDID, verifique os modos reais com `hyprctl monitors`.
- Animações foram calibradas com durações curtas e curvas suaves sincronizadas a 75 Hz, com `misc:vfr = true` e `render:direct_scanout = 1` para não sacrificar FPS em jogos tela cheia.
- **Cores:** Nenhuma calibração artificial arbitrária é aplicada; caso você possua um perfil `.icc` real do seu monitor, ele pode ser aplicado via `colord` ou suporte de gerenciamento de cor do compositor.

---

## 4. Arquitetura do Assistente de Terminal (Extensível e Offline-Safe)

O script `scripts/terminal/easyarch-ai-assistant.sh` cria uma camada modular (`easyarch-ai` no Fish) preparada para conectar modelos de IA futuramente sem depender deles:
- **Terminal tradicional 100% independente:** `foot` + `fish` + `tealdeer` + `pkgfile` funcionam integralmente offline.
- **Classificação de segurança integrada:** Antes de sugerir ou encaminhar qualquer comando, o módulo classifica padrões destrutivos ou privilegiados (`rm -rf`, `dd`, `mkfs`, `fdisk`, `wipefs`, `sudo`, `chmod -R`, `chown -R`) e **bloqueia execução automática**, exigindo confirmação explícita do usuário.

---

## 5. Guia de Instalação, Verificação, Desinstalação e Recuperação

### Instalação dos pacotes (no Arch instalado)
1. Instale os pacotes oficiais:
   `mapfile -t pkgs < <(grep -Ev '^\s*(#|$)' packages/fase2-desktop-terminal.txt) && sudo pacman -S --needed "${pkgs[@]}"`
2. Atualize as bases locais de comandos e exemplos:
   `sudo pkgfile --update && tldr --update`
3. *(Opcional — AUR)* Revise o `PKGBUILD` de `pay-respects-bin` antes de compilar/instalar.
4. Aplique os dotfiles com backup automático (não destrutivo):
   `./scripts/instalacao/02-instalar-configs-fase2.sh`
5. Habilite áudio e banco de atualizações de pacotes:
   `systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service`

### Verificação Objetiva
- Execute `./scripts/diagnostico/03-validar-fase2.sh` dentro da sessão Hyprland.
- O script valida AMDGPU/Vulkan (`vulkaninfo`), PipeWire (`wpctl`), Hyprland, Waybar, Dock, Rofi, Foot, Fish e dispara uma coleta padronizada de RAM ociosa (comparando contra a meta de **500–700 MB** e a meta experimental de **400 MB**).

### Desinstalação e Recuperação
- **Restaurar dotfiles anteriores:** O instalador salva uma cópia datada em `~/.config-backup-AAAAMMDD-HHMMSS/`.
- **Se o Hyprland não abrir:** Pressione `Ctrl + Alt + F3` para abrir um TTY, verifique o log em `$XDG_RUNTIME_DIR/hypr/` ou `~/.cache/hyprland/` e teste com `Hyprland --config /dev/null`.
