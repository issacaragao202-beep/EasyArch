# Auditoria e Correções Estruturais — EasyArch v4.1

> **Escopo desta revisão:** Correção estrutural completa de todos os problemas reais apontados na auditoria técnica (sem adicionar funcionalidades artificiais), unificação de versão (`EasyArch v4.1`) e alinhamento honesto entre documentação e implementação.

---

## 1. Correções Estruturais Aplicadas na v4.1

| Problema Apontado | Correção Aplicada na v4.1 |
| :--- | :--- |
| **`[multilib]` não habilitado antes da Fase 2** | `easyarch-setup.sh` agora detecta se `[multilib]` está ativo, faz backup de `/etc/pacman.conf`, habilita e executa `pacman -Sy` antes de instalar `lib32-*`. |
| **Snapper apenas como template + falsa proteção no atualizador** | Criado `scripts/instalacao/easyarch-configurar-snapper.sh` (valida Btrfs, cria config `root`, aplica template e confirma snapshot inicial). `easyarch-update-safe.sh` agora verifica se o Snapper está ativo em Btrfs e cria/confirma snapshot pré-atualização antes de rodar `pacman -Syu`. |
| **`earlyoom` com aspas/espaços internos e `polkit-kde`** | `etc/default/earlyoom` reescrito sem aspas nem espaços internos em `EARLYOOM_ARGS` (conforme upstream) e trocando `polkit-kde-authentication-agent-1` por `hyprpolkitagent`. |
| **DNS-over-TLS desconectado do NetworkManager e `/etc/resolv.conf`** | Criado `etc/NetworkManager/conf.d/10-easyarch-dns.conf`, symlink `/etc/resolv.conf -> /run/systemd/resolve/stub-resolv.conf` no `easyarch-aplicar-etc.sh` e validação ponta a ponta em `security-status.sh`. |
| **Erros silenciados com `|| true` em `easyarch-aplicar-etc.sh`** | Removidos todos os `|| true` de `sysctl` e `systemctl`; falhas são contabilizadas e retornam `exit 1`. |
| **`flush ruleset` global no `nftables.conf`** | Substituído por tabela isolada `table inet easyarch_filter` + `flush table inet easyarch_filter` (preserva regras de containers/VMs de terceiros). |
| **Dependências entre fases no `easyarch.sh` e `02-instalar-configs-fase2.sh`** | `easyarch.sh` agora valida cada script dependente via `require_bin` com mensagem orientativa; `02-instalar-configs-fase2.sh` instala também `01-relatorio-memoria.sh`, `02-validar-fase1.sh` e todos os utilitários `easyarch-*` em ordem limpa. |
| **Bug `TERMUX_USER` ignorado no `easyarch-phone.sh`** | Comando SSH corrigido para `"${TERMUX_USER}@127.0.0.1"`. |
| **Wallpaper SVG sem `librsvg`, conflito `-d -x` no dock e corrida no `exec-once`** | `librsvg` adicionado em `fase2-desktop-terminal.txt`; removido `-x` do `nwg-dock-hyprland -d`; `dbus-update-activation-environment` + `import-environment` + `hyprpolkitagent` encadeados em sequência no `hyprland.conf`. |
| **Resíduos `linux-forge` / `forge-` / `v2` / `v3` e referências ao HTML** | Todo o repositório unificado como **EasyArch v4.1** (`etc/sysctl.d/90-easyarch-memory.conf`, `/root/easyarch`, `~/.local/share/easyarch`, `~/easyarch-benchmarks`, `alias easyarch-ai`). |
| **Escopo honesto de Wine, Bubblewrap e Construtor ISO** | Documentado claramente que Wine sem `Z:` e `bwrap` com `XDG_RUNTIME_DIR` reduzem superfície mas não substituem sandbox completa contra binários maliciosos; `06-construir-iso-archiso.sh` agora embute configs de `/etc` e `/etc/skel/.config/` na Live ISO e declara honestamente que gera uma **Live ISO personalizada baseada no `releng` do Arch Linux** (não um instalador automático de disco). |

---

## 2. O Que Ainda Exige Execução Real (Sem Promessas Prematuras)
- **Validado estaticamente neste ambiente:** sintaxe Bash (`bash -n`) de todos os 35 scripts, JSON da Waybar, ausência de resíduos de caminhos quebrados e consistência de pacotes.
- **Pendente de teste real (próxima etapa recomendada):**
  1. Teste de boot, rede, Snapper, `earlyoom`, `nftables` e `DoT` em **máquina virtual (QEMU/KVM ou VirtualBox)** antes de ir para o disco principal.
  2. Benchmarks reais no **Ryzen 5 3400G** (Hyprland ocioso, navegador, Minecraft/ArcForge, Wine/Proton, Waydroid) para validar metas de 400–700 MB e calibrar `swappiness`/`sysctl` com dados reais.
