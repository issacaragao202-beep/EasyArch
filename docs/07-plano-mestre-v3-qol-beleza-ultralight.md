# Projeto Linux Forge — Plano Mestre v3.0: Ultra-Leve, Bonito (Glacial Silver) e Fácil para Novatos (QoL)

> **Missão da v3.0:** Aproximar o sistema da meta experimental de **~400 MB de RAM ociosa** no Ryzen 5 3400G (~6 GB úteis), elevar o acabamento visual **Glacial Silver** em todas as janelas (GTK, tela de bloqueio, wallpaper e barra) e eliminar a curva de aprendizado para iniciantes com automações seguras em 1 clique — **sem desligar nenhuma camada de segurança**.

---

## 1. Pilar 1 — Engenharia Ultra-Leve (Onde Economizamos RAM de Verdade)

Em vez de "maquiar" métricas desligando segurança, a v3.0 ataca os 6 maiores ladrões silenciosos de RAM e largura de banda no single-channel da Vega 11:

| Otimização v3.0 | Arquivo Implementado | Economia / Ganho Real | Referência |
| :--- | :--- | :--- | :--- |
| **Trocar `polkit-kde-agent` por `hyprpolkitagent`** | `packages/fase2-desktop-terminal.txt` + `hyprland.conf` | Remove bibliotecas pesadas do KDE/Plasma da memória residente; ativação nativa por D-Bus/systemd user. | [hyprpolkitagent](https://archlinux.org/packages/extra/x86_64/hyprpolkitagent/) |
| **Limitar `systemd-journald` em RAM e SSD** | `etc/systemd/journald.conf.d/10-easyarch-lean.conf` | Trava `/run/log/journal` em **32 MiB** (evita tmpfs comer >150 MB ao longo do dia) e disco em **150 MiB** (protege o SSD 240 GB). | [journald.conf(5)](https://man.archlinux.org/man/journald.conf.5.en) |
| **Desativar gravação de Core Dumps gigantes** | `etc/systemd/coredump.conf.d/10-easyarch-nocore.conf` | Evita que um crash de jogo/navegador grave 2 GB de dump no SSD Kingston A400 DRAM-less e trave o sistema. | `systemd-coredump` |
| **Servidor `foot --server` + `footclient`** | `config/hypr/hyprland.conf` | Abrir 3 ou 4 terminais compartilha o mesmo processo-base e cache de fontes em RAM. | — |
| **Waybar com polling inteligente (5s / 10s / 60s)** | `config/waybar/config.jsonc` | Reduz acordadas da CPU e consultas desnecessárias mantendo responsividade instantânea. | — |
| **Modo Ultra-Leve sob demanda (`easyarch-lite-mode.sh`)** | `scripts/qol/easyarch-lite-mode.sh` | Pausa temporariamente o dock e animações antes de jogos ou builds Java 17 (ArcForge) e restaura com 1 comando. | — |
| **Flags Wayland + VA-API para Chromium/Electron** | `config/chromium-flags.conf` & `config/electron-flags.conf` | Elimina overhead de XWayland em apps Electron/VS Code/Chromium e usa decodificação de vídeo por hardware na Vega 11. | — |

---

## 2. Pilar 2 — Refinamento Estético Total (Glacial Silver Coeso)

- **Wallpaper Vetorial Automático (`swaybg`):** Aplicado no boot com < 8 MB de RAM usando o SVG minimalista `glacial-silver-1080p.svg` gerado localmente.
- **Tela de Bloqueio Elegante (`hyprlock`):** Vidro escuro `#0B0F14`, anel metálico prata/ciano `#7DD3FC`, relógio minimalista e zero blur custoso (`SUPER + L`).
- **Gerenciamento de Ociosidade (`hypridle`):** Escurece/desliga o monitor suavemente após 10 min e bloqueia a tela com `hyprlock`, poupando energia e preservando o painel.
- **Coerência GTK3 e GTK4:** `config/gtk-3.0/settings.ini` e `config/gtk-4.0/settings.ini` forçam `gtk-application-prefer-dark-theme=1` e tipografia limpa em todos os apps gráficos.

---

## 3. Pilar 3 — QoL para Novatos (Sem Medo do Arch Linux)

1. **Boas-Vindas no Primeiro Login (`easyarch-welcome.sh`):** Roda uma única vez ao entrar no Hyprland, apresenta os 4 atalhos essenciais, testa áudio/segurança e nunca mais incomoda (pode ser reaberto pelo menu `SUPER + H`).
2. **Atualização Segura em 1 Comando (`easyarch-update-safe.sh`):**
   - Verifica espaço livre no SSD Kingston A400 antes de atualizar;
   - Confirma que `snap-pac` criará snapshot Btrfs automático antes da atualização;
   - Atualiza `pacman` e `flatpak` de forma guiada e exibe lembrete se o kernel foi atualizado (para reiniciar).
3. **Central QoL Turbinada (`easyarch-hub.sh` v3.0 — `SUPER + H`):** Agora inclui **Atualização Segura**, **Modo Ultra-Leve (ON/OFF)**, **Bloquear Tela**, **Perfis**, **Memória**, **Segurança**, **Waydroid**, **ArcForge Java 17**, **Smartphone USB** e **SOS**.

---

## 4. Pilar 4 — Segurança 100% Preservada
Nenhuma otimização da v3.0 desativa AppArmor, `nftables`, DNS-over-TLS, `earlyoom`, remoção do drive `Z:` no Wine ou `bubblewrap`. O sistema fica mais leve, mais bonito e mais fácil **mantendo defesa em profundidade real**.
