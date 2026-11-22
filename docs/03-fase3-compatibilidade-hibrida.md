# Projeto Linux Forge — Fase 3: Compatibilidade Híbrida (Linux, Windows e Android)

> **Princípio de Engenharia:** Integração unificada no lançador sem sacrificar segurança nem manter ambientes pesados residentes nos ~6 GB de RAM utilizáveis do Ryzen 5 3400G.

---

## 1. Camada Linux (Pacman, AUR, Flatpak e AppImage)

| Origem | Uso Recomendado | Isolamento |
| :--- | :--- | :--- |
| **Pacman (Repositórios Oficiais)** | Base do sistema, drivers AMD, compositor, CLI e bibliotecas críticas | Sistema nativo + perfis AppArmor |
| **Flatpak (Flathub)** | Aplicações gráficas de desktop (navegadores, Bottles, mensageiros, Flatseal) | Sandbox `bubblewrap` + portais Wayland (`xdg-desktop-portal-hyprland` / `gtk`) ([ArchWiki Flatpak](https://wiki.archlinux.org/title/Flatpak)) |
| **AUR** | Apenas quando não houver pacote oficial ou Flatpak equivalente | Revisão obrigatória do `PKGBUILD` antes de compilar |
| **AppImage** | Aplicações portáteis pontuais | **Não é sandboxed por padrão.** Use `easyarch-appimage-sandbox.sh` (`bubblewrap`) para restringir acesso ao `$HOME` |

---

## 2. Camada Windows (Wine, Bottles, Steam/Proton, DXVK, VKD3D e NTSync)

- **Programas Desktop Windows:** Preferência por **Bottles** via Flatpak (`com.usebottles.bottles`) — combina gerenciamento de prefixos independentes (com DXVK/VKD3D) com sandbox `bubblewrap`.
- **Jogos Windows:** Preferência por **Steam + Proton** (e **Proton-GE** gerenciado pelo ProtonUp-Qt) + **Gamescope** + **RADV**.
- **NTSync Real:** Integrado no kernel mainline (6.14+, presente no `linux 7.3.x` do Arch). Pacotes oficiais `wine` / `wine-staging` (11.14-2+), Proton `11.0-1+` e `GE-Proton10-10+` suportam NTSync nativamente quando `/dev/ntsync` está presente ([ArchWiki Wine](https://wiki.archlinux.org/title/Wine)). Valide com `easyarch-ntsync-check.sh` (`lsof /dev/ntsync`).
- **Segurança na abertura de `.exe` e `.msi`:**
  - Prefixos Wine **não são sandboxes** (o drive `Z:` aponta para `/`).
  - O arquivo `easyarch-windows-safe.desktop` integra `.exe`/`.msi` ao gerenciador de arquivos chamando `easyarch-win-run.sh`, que **nunca executa automaticamente**: exibe caminho e hash SHA-256, exige confirmação explícita e isola cada app em seu próprio `WINEPREFIX`.
  - Ao encerrar, o wrapper finaliza **somente** o `wineserver` daquele prefixo (`WINEPREFIX=... wineserver -w`), jamais usando `wineserver -k` global sobre outros apps Windows em uso.
  - **Recomendação:** Para evitar execução implícita via `binfmt` ao clicar/chamar `.exe` por engano, desative `wine.conf` em `/etc/binfmt.d/` criando um symlink nulo (`sudo ln -sf /dev/null /etc/binfmt.d/wine.conf`).

---

## 3. Camada Android (Waydroid Sob Demanda)

- **Funcionamento:** Executa Android em container LXC sobre Wayland com aceleração gráfica AMD/Mesa (Vega 11) ([ArchWiki Waydroid](https://wiki.archlinux.org/title/Waydroid)).
- **Requisitos de Kernel:** Verifica presença de `binder_linux` (`/dev/binderfs` ou `/dev/binder`). No kernel `linux` oficial do Arch, confirme com `04-validar-fase3.sh` (caso o módulo não esteja ativo no kernel padrão no momento do teste, `linux-zen` inclui `binder` nativamente).
- **Aplicações ARM (`libndk`):** O suporte a APKs ARM exige camada de tradução (`libndk`) instalada na imagem Android quando necessário.
- **Limitações Honestas:** Nem todo APK funcionará. Aplicativos bancários, jogos com anti-cheat agressivo, apps com **Play Integrity / Widevine DRM L1** ou dependência estrita de serviços proprietários do Google podem falhar ou exigir imagem GAPPS (que consome mais RAM).
- **Gestão Inteligente de Memória (Sob Demanda):**
  - `waydroid-container.service` fica **desabilitado no boot** (`0 MB` quando ocioso).
  - O script `easyarch-waydroid.sh` inicia o container apenas quando você abre um app Android, mantém o container rodando enquanto houver **qualquer** janela Android aberta e encerra sessão + container automaticamente quando **todas** as aplicações Android forem fechadas.
- **Firewall (`nftables`):** O arquivo `etc/nftables.d/20-waydroid.nft` libera apenas DHCP/DNS e encaminhamento da interface virtual `waydroid0`, mantendo a política `drop` na entrada da máquina.

---

## 4. Guia de Instalação, Testes Individuais, Desinstalação e Recuperação

### Instalação
1. Instale os pacotes oficiais:
   `mapfile -t pkgs < <(grep -Ev '^\s*(#|$)' packages/fase3-hibrido.txt) && sudo pacman -S --needed "${pkgs[@]}"`
2. Configure o Flathub no escopo de usuário (sem exigir root para apps):
   `flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo`
3. Instale Bottles, Flatseal e ProtonUp-Qt (Flatpak):
   `flatpak install --user flathub com.usebottles.bottles com.github.tchx84.Flatseal net.davidotek.pupgui2`
4. Instale as integrações locais não destrutivas da Fase 3:
   `./scripts/instalacao/03-instalar-fase3.sh`
5. *(Waydroid — após revisar PKGBUILD no AUR)* Instale `waydroid`, inicialize a imagem (`sudo waydroid init`), desabilite inicialização automática (`sudo systemctl disable --now waydroid-container.service`) e inclua `etc/nftables.d/20-waydroid.nft` no `/etc/nftables.conf`.

### Testes Individuais (Antes de Avançar para a Fase 4)
1. **Validação estrutural:** `./scripts/diagnostico/04-validar-fase3.sh`
2. **Teste Flatpak/Sandbox:** Abrir Bottles e conferir permissões com `flatpak info --show-permissions com.usebottles.bottles`.
3. **Teste Windows + NTSync:** Abrir um utilitário/jogo Windows e rodar `easyarch-ntsync-check.sh` durante a execução; depois fechar e rodar `01-relatorio-memoria.sh pos-wine`.
4. **Teste Android Sob Demanda:** Abrir um app com `easyarch-waydroid.sh launch <pacote>`, testar com 2 apps abertos simultaneamente, fechar ambos e confirmar que `waydroid-container.service` foi encerrado e a RAM foi liberada (`01-relatorio-memoria.sh pos-waydroid`).

### Desinstalação e Recuperação
- **Remover integração `.exe`/`.msi`:** Apague `~/.local/share/applications/easyarch-windows-safe.desktop` e rode `update-desktop-database ~/.local/share/applications`.
- **Reverter regras nftables do Waydroid:** Remova a linha `include` de `20-waydroid.nft` e reinicie `nftables.service`.
