# Projeto Linux Forge — Etapa 1: Arquitetura, Plano de Memória e Fundamentos da Fase 1

> **Hardware-alvo exclusivo:** AMD Ryzen 5 3400G (4C/8T) · Radeon Vega 11 integrada · 8 GB DDR4 single-channel (2667 MHz, ~6 GB utilizáveis) · Mancer B450M-DA V2SC · SSD SATA Kingston A400 240 GB · Monitor 1920×1080 @ 75 Hz · UEFI.

---

## 1. Cronograma de Execução em 10 Etapas (Ritmo Controlado: ≥ 2h a cada 3 Etapas)

Para garantir estabilidade, testes reais em cada camada e zero improviso, o projeto está dividido em **10 etapas** distribuídas nas **4 fases obrigatórias**, com **checkpoints de consolidação e testes de no mínimo 2 horas a cada bloco de 3 etapas**:

| Bloco / Tempo Mínimo | Etapa | Fase | Escopo Principal | Critério para Avançar |
| :--- | :---: | :---: | :--- | :--- |
| **Bloco 1** (≥ 2h) | **1 (Atual)** | Fase 1 | Arquitetura final, justificativas, plano de memória, pacotes, dotfiles não destrutivos e script de diagnóstico de disco | Relatório de disco real coletado pelo usuário |
| **Bloco 1** (≥ 2h) | **2** | Fase 1 | Plano exato de particionamento (Btrfs + UEFI + LUKS2 opcional), instalação base do Arch Linux e kernel estável | Sistema inicializando em UEFI com Btrfs/Zstd |
| **Bloco 1** (≥ 2h) | **3** | Fase 1 | ZRAM, `earlyoom`, `sysctl` de memória, Snapper, `fstrim.timer` e teste de recuperação de snapshot | *Checkpoint 1:* Boot limpo, ZRAM ativa e rollback validado |
| **Bloco 2** (≥ 2h) | **4** | Fase 1 | Segurança em camadas: AppArmor, `nftables`, `systemd-resolved` (DoT) e `sysctl` de kernel/rede | *Firewall, AppArmor e DoT verificados em execução* |
| **Bloco 2** (≥ 2h) | **5** | Fase 2 | Interface **Glacial Silver**: Hyprland (1080p@75Hz), Waybar, Dock flutuante, Lançador, PipeWire e AMDGPU/Mesa/RADV | Sessão gráfica estável sem tearing/stuttering |
| **Bloco 2** (≥ 2h) | **6** | Fase 2 | Terminal inteligente: Foot, Fish, Starship, FZF, Zoxide, Tealdeer, Pay-Respects, Pkgfile e arquitetura de assistente | *Checkpoint 2:* RAM ociosa medida (meta 500–700 MB / exp. 400 MB) |
| **Bloco 3** (≥ 2h) | **7** | Fase 3 | Camada Windows e Jogos: Wine/Staging, Bottles, Steam/Proton/GE, DXVK, VKD3D, Gamescope e `/dev/ntsync` | Prefixo isolado e `/dev/ntsync` validados |
| **Bloco 3** (≥ 2h) | **8** | Fase 3 | Camada Android: Waydroid sob demanda, aceleração Mesa, gestão de APKs, `libndk` e encerramento controlado | Container encerra e libera RAM após fechar apps |
| **Bloco 3** (≥ 2h) | **9** | Fase 4 | Dev (GCC, Clang, MinGW, Python, Node, Java 17/Gradle p/ Minecraft 1.20.1 Fabric / ArcForge), agentes CLI sob demanda, ADB/scrcpy/Termux | *Checkpoint 3:* Build Java 17 e offload Termux testados |
| **Bloco 4** (Final) | **10** | Fase 4 | Perfis de desempenho (Econômico, Equilibrado, Jogos, Dev), automação de manutenção e suíte de benchmarks (7 cenários) | Relatório final com medições reais coletadas |

---

## 2. Arquitetura Final Escolhida e Justificativas Técnicas

Todas as escolhas priorizam os repositórios oficiais do Arch Linux e refletem o estado atual documentado em novembro de 2026:

| Camada | Componente Escolhido | Justificativa Técnica | Referência Oficial |
| :--- | :--- | :--- | :--- |
| **Base** | Arch Linux minimalista (ISO `2026.11.01`) | Controle granular de pacotes sem serviços residentes ocultos; rolling release garante Mesa/RADV e kernel atualizados para Vega 11 e `ntsync`. | [Arch Linux Releases](https://archlinux.org/releng/releases/2026.11.01/) |
| **Kernel** | `linux` estável (`7.3.5.arch1-1` atual) + `linux-zen` como alternativa experimental | O kernel estável oferece máxima previsibilidade, suporte nativo ao driver `ntsync` (integrado desde 6.14+) e menor risco de regressão em drivers. `linux-zen` será avaliado apenas por benchmark real, nunca por suposição. | [Pacote linux](https://archlinux.org/packages/core/x86_64/linux/) · [ArchWiki Kernel](https://wiki.archlinux.org/title/Kernel) |
| **Bootloader** | `systemd-boot` (UEFI) | Nativo do `systemd`, leve, configuração textual simples em `/boot/loader/entries/`, sem a complexidade de parser do GRUB; ideal para UEFI puro. | [ArchWiki Kernel parameters](https://wiki.archlinux.org/title/Kernel_parameters_(Portugu%C3%AAs)) |
| **Sistema de Arquivos** | Btrfs com `compress=zstd:1`, `noatime`, subvolumes flat + Snapper + `fstrim.timer` | Compressão Zstd nível 1 reduz escritas no SSD Kingston A400 (240 GB, DRAM-less) e economiza espaço com baixo custo de CPU. Subvolumes isolam sistema, home, cache e logs. `fstrim.timer` semanal preserva desempenho do SSD. | [ArchWiki Btrfs](https://wiki.archlinux.org/title/Btrfs) · [ArchWiki Snapper](https://wiki.archlinux.org/title/Snapper) · [ArchWiki SSD](https://wiki.archlinux.org/title/Solid_state_drive) |
| **Criptografia** | LUKS2 opcional (`sd-encrypt`, Argon2id com `--pbkdf-memory 524288`) | Protege dados em repouso. Em máquinas com ~6 GB úteis, limitar a memória do Argon2id a 512 MiB evita falhas de alocação no initramfs (padrão é 1 GiB). Impacto na CPU Ryzen 5 3400G é baixo graças a AES-NI. | [ArchWiki dm-crypt](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system) |
| **Memória Virtual** | `zram-generator` (`zstd`, limite ~3 GiB, prioridade 100) + `zswap.enabled=0` | Comprime páginas inativas na própria RAM sem desgastar o SSD SATA de 240 GB. Desativar `zswap` é obrigatório para evitar compressão duplicada e estatísticas falsas no `zramctl`. | [ArchWiki Zram](https://wiki.archlinux.org/title/Zram) |
| **Proteção OOM** | `earlyoom` (daemon em C) | Consumo mínimo (< 2 MB), age antes do OOM Killer do kernel congelar a interface. Protege compositor, terminais, compiladores e IDEs (`--avoid`), priorizando abas/renderers pesados (`--prefer`). | [ArchWiki Improving performance](https://wiki.archlinux.org/title/Improving_performance) |
| **Controle de Acesso** | AppArmor (`lsm=` no kernel + `apparmor.service`) | Escolhido pela simplicidade de manutenção baseada em caminhos de arquivo e menor curva operacional no Arch Linux (não por suposta superioridade universal de desempenho sobre SELinux). Nota: no Arch, `dbus` não é compilado com suporte AppArmor. | [ArchWiki AppArmor](https://wiki.archlinux.org/title/AppArmor) |
| **Firewall** | `nftables` direto (sem UFW concorrente) | Framework nativo do kernel Linux; regras declarativas em um único arquivo (`/etc/nftables.conf`), sem camadas redundantes ou conflito de tabelas. | [ArchWiki Security](https://wiki.archlinux.org/title/Security) |
| **DNS** | `systemd-resolved` com DNS-over-TLS (`DNSOverTLS=yes`, porta 853) | Criptografa consultas DNS em trânsito contra interceptação local/ISP. **Ressalva:** DoT não bloqueia malware; filtragem de domínios maliciosos será camada independente e opcional. | [ArchWiki systemd-resolved](https://wiki.archlinux.org/title/Systemd-resolved) |
| **Gráficos e Áudio** | Wayland + Hyprland + AMDGPU/Mesa/RADV + PipeWire (Fase 2) | Pilha moderna sem Xorg legado, menor latência em 75 Hz, controle preciso de efeitos para não roubar largura de banda da Vega 11 e áudio de baixa latência sob demanda. | — |

---

## 3. Diagrama da Arquitetura (Linux Forge)

```text
+-----------------------------------------------------------------------------------+
|                        CAMADA DE APLICAÇÕES E PRODUTIVIDADE                       |
|  [Linux Nativo / Flatpak (bwrap)]  [Windows: Bottles/Proton]  [Android: Waydroid] |
|        (Sob demanda, isolados)       (Prefixos + /dev/ntsync)   (Encerra ocioso)  |
+-----------------------------------------------------------------------------------+
|                     INTERFACE VISUAL (GLACIAL SILVER) & SHELL                     |
|  [Hyprland (Wayland, 1080p@75Hz)] [Waybar] [Dock] [Lançador] [Foot+Fish+Starship] |
+-----------------------------------------------------------------------------------+
|                      SEGURANÇA EM CAMADAS (DEFESA EM PROFUNDIDADE)                |
|  [AppArmor (MAC)]  [nftables (Input Drop)]  [systemd-resolved (DoT 853)] [sysctl] |
+-----------------------------------------------------------------------------------+
|                    GERENCIAMENTO EXTREMO DE MEMÓRIA (~6 GB ÚTEIS)                 |
|  [zram-generator (zstd, <=3 GiB, prio 100)] [zswap=0] [earlyoom (prefer/avoid)]   |
+-----------------------------------------------------------------------------------+
|                        BASE DO SISTEMA E ARMAZENAMENTO                            |
|  [Arch Linux] [Kernel linux 7.3.x + ntsync] [systemd + systemd-boot (UEFI)]       |
|  [Btrfs (zstd:1, noatime) + Snapper]  -->  [LUKS2 Opcional]  -->  [Kingston A400] |
+-----------------------------------------------------------------------------------+
|                                 HARDWARE REAL                                     |
|  Ryzen 5 3400G (4C/8T) | Vega 11 (iGPU) | 8 GB DDR4 Single-Channel 2667 MHz       |
+-----------------------------------------------------------------------------------+
```

---

## 4. Principais Limitações do Hardware Real

1. **Memória Física Utilizável (~6 GB) e Single-Channel a 2667 MHz:** A Radeon Vega 11 reserva cerca de 2 GB da RAM física (UMA Frame Buffer) e compartilha o único canal de memória com a CPU. A largura de banda de memória (~21,3 GB/s teóricos em single-channel 2667 MHz) é o principal gargalo para jogos, renderização pesada e multitarefa simultânea.
2. **Pressão de Memória em Cargas Combinadas:** É tecnicamente inviável manter simultaneamente navegador com dezenas de abas, Waydroid (Android), Wine/Proton, IDE e compilação Java/Gradle sem degradação severa. A arquitetura resolve isso por **isolamento temporal (execução sob demanda)** e **compressão em RAM (ZRAM)**, não por milagres.
3. **SSD SATA Kingston A400 (240 GB):** Unidade SATA sem cache DRAM dedicado. Escritas aleatórias intensas (como swap em disco tradicional ou snapshots descontrolados) degradam rapidamente a latência e a vida útil da NAND. Por isso: **ZRAM como swap primária**, `noatime`, compressão `zstd:1`, exclusão de caches/logs dos snapshots e retenção enxuta no Snapper.
4. **CPU 4C/8T (Zen+):** Excelente para desktop responsivo e jogos leves/médios, mas exige cuidado com processos de indexação em segundo plano (Tracker, Baloo, etc. ficam **proibidos**) e com nível de compressão Zstd (mantido baixo para não competir com CPU/GPU).

---

## 5. Plano de Otimização de Memória

### Metas e Metodologia Honesta
- **Meta realista (desktop ocioso):** **500–700 MB** de RAM utilizada após boot limpo com sessão gráfica Hyprland + Waybar + PipeWire + NetworkManager/resolved.
- **Meta experimental:** aproximar-se de **400 MB** ajustando serviços residentes, sem jamais desativar segurança (AppArmor/nftables), áudio ou portais essenciais. Se a medição real ficar acima de 400 MB, registraremos o valor exato e os maiores consumidores por **PSS (Proportional Set Size)**.
- **Diferenciação rigorosa de métricas:** Nunca confundir `MemUsed` bruto com `MemAvailable`, cache de página (`buff/cache`) e memória realmente indisponível. O script `01-relatorio-memoria.sh` coleta `free -m`, `/proc/meminfo`, `/proc/pressure/memory` (PSI), `zramctl` e o top 15 de processos por PSS.

### Políticas Aplicadas na Fase 1
1. **ZRAM Dinâmica (`zram-generator`):**
   - Algoritmo `zstd`, tamanho `min(ram / 2, 3072)` (~3 GiB virtuais sem pré-alocação física), prioridade `100`.
   - Parâmetro de kernel `zswap.enabled=0` obrigatório para não interferir na ZRAM.
   - `vm.swappiness=100` inicial (adequado para ZRAM, diferente do mito `swappiness=10` de discos mecânicos), com `vm.page-cluster=0` para evitar leitura antecipada inútil em swap de RAM. Será comparado via benchmark com valores como `60`, `100` e `150` na Etapa 3/10.
2. **`earlyoom` Conservador:**
   - Aciona `SIGTERM` em 8% de RAM livre + 10% de swap livre; `SIGKILL` em 4% RAM + 5% swap.
   - **Prioridade de encerramento (`--prefer`):** abas/renderers de navegadores e apps Electron pesados.
   - **Proteção (`--avoid`):** `systemd`, `Hyprland`, `foot`, `sshd`, `javac`, `gradle`, `gcc`, `clang`, `waybar`.
3. **Zero Serviços Pesados Residentes:** Wine, Steam, Waydroid, Docker/Podman e agentes CLI só sobem quando invocados e são encerrados após o uso.

---

## 6. Arquitetura de Subvolumes Btrfs (Planejada para a Etapa 2)

A execução só ocorrerá na Etapa 2 **após** analisarmos o relatório de disco do seu computador. O layout flat planejado é:

| Subvolume | Ponto de Montagem | Incluído no Snapshot de `@`? | Motivo Técnico |
| :--- | :--- | :---: | :--- |
| `@` | `/` | **Sim (alvo principal)** | Sistema operacional, pacotes e `/etc` — permite rollback de atualizações quebradas. |
| `@home` | `/home` | Não (política própria opcional) | Evita perder documentos ou código-fonte recente ao reverter uma atualização do sistema. |
| `@snapshots` | `/.snapshots` | Não | Armazena os snapshots do Snapper sem recursão. |
| `@var_log` | `/var/log` | Não | Mantém logs intactos mesmo após rollback para diagnosticar o que falhou. |
| `@var_cache_pacman` | `/var/cache/pacman/pkg` | Não | Evita inflar snapshots com pacotes `.pkg.tar.zst` baixados pelo Pacman no SSD de 240 GB. |
| `@var_tmp` | `/var/tmp` | Não | Arquivos temporários persistentes não precisam de snapshot. |

> **Nota importante:** Snapshots Btrfs **não substituem backups externos** (se o SSD falhar, os snapshots vão juntos). Além disso, a restauração só será declarada funcional após teste prático real na Etapa 3.

---

## 7. Lista de Pacotes da Fase 1 (Repositórios Oficiais Arch Linux)

A lista completa e pronta para instalação está em `packages/fase1-base.txt` no pacote entregue. Resumo por função:

- **Base e Kernel:** `base`, `base-devel`, `linux`, `linux-headers`, `linux-firmware`, `amd-ucode`
- **Sistema de Arquivos, Disco e Snapshots:** `btrfs-progs`, `dosfstools`, `cryptsetup`, `snapper`, `snap-pac`, `compsize`, `smartmontools`
- **Memória e Desempenho:** `zram-generator`, `earlyoom`, `lm_sensors`, `sysstat`
- **Rede e Segurança:** `networkmanager`, `nftables`, `apparmor`, `audit`, `ca-certificates`
- **Ferramentas Essenciais de Manutenção e Diagnóstico:** `git`, `vim`, `nano`, `man-db`, `man-pages`, `util-linux`, `pciutils`, `usbutils`, `lsof`, `htop`

*(O kernel alternativo `linux-zen` e `linux-zen-headers` só serão instalados opcionalmente na etapa de benchmark comparativo.)*

---

## 8. Estrutura de Diretórios dos Arquivos do Projeto

```text
linux-forge/
├── PROJECT_STATE.md                           # Registro persistente de estado do projeto
├── docs/
│   └── 01-arquitetura-e-plano-linux-forge.md  # Este documento técnico
├── packages/
│   └── fase1-base.txt                         # Lista limpa de pacotes oficiais da Fase 1
├── etc/
│   ├── modules-load.d/
│   │   └── ntsync.conf                        # Carregamento do módulo ntsync
│   ├── nftables.conf                          # Firewall nftables documentado
│   ├── default/
│   │   └── earlyoom                           # Política conservadora de proteção OOM
│   ├── snapper/configs/
│   │   └── root.template                      # Retenção controlada de snapshots (SSD 240 GB)
│   ├── sysctl.d/
│   │   ├── 90-linux-forge-memory.conf         # Ajustes de memória para ZRAM
│   │   └── 95-linux-forge-security.conf       # Hardening de kernel e rede documentado
│   └── systemd/
│       ├── zram-generator.conf                # ZRAM zstd <= 3 GiB, prioridade 100
│       └── resolved.conf.d/
│           └── 10-linux-forge-dot.conf        # DNS-over-TLS via systemd-resolved
└── scripts/
    ├── diagnostico/
    │   ├── 01-diagnostico-hardware-disco.sh   # 100% SOMENTE LEITURA (executar agora!)
    │   └── 02-validar-fase1.sh                # Validação pós-instalação da Fase 1
    └── manutencao/
        └── 01-relatorio-memoria.sh            # Medição consistente de RAM, PSS, ZRAM e PSI
```

---

## 9. Guia Rápido para Não Especialistas (Como Usar, Verificar e Recuperar)

- **Antes de qualquer instalação (AGORA):** Execute o script `01-diagnostico-hardware-disco.sh` no Arch Live ISO (ou no Linux atual). Ele **não altera nada** no disco; apenas gera um arquivo `relatorio-hardware-disco.txt` com suas partições reais, status UEFI e saúde do SSD.
- **Como executar o diagnóstico com segurança:**
  1. Dê permissão de execução: `chmod +x 01-diagnostico-hardware-disco.sh`
  2. Rode o script: `./01-diagnostico-hardware-disco.sh`
  3. Envie o arquivo `relatorio-hardware-disco.txt` gerado aqui no chat (e informe se deseja manter algum Windows em dual-boot e se deseja ativar criptografia LUKS2).
- **Como verificar se cada componente funciona (na Etapa 3/4):** Rodar `./scripts/diagnostico/02-validar-fase1.sh`, que testa cada serviço individualmente sem mascarar falhas.
- **Como desfazer ou recuperar:** Todos os arquivos em `etc/` são modulares (`*.d/*.conf`). Para desativar qualquer camada sem reinstalar o sistema, basta mover o arquivo `.conf` para `/root/backup/` e reiniciar o serviço correspondente (ou remover o parâmetro `lsm=` no menu do `systemd-boot` pressionando `e` na inicialização).
