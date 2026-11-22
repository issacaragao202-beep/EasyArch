# Projeto Linux Forge — Fase 4: Desenvolvimento, IA Sob Demanda, Mobile, Perfis e Benchmarks

> **Objetivo:** Preparar ambiente completo de desenvolvimento (incluindo Minecraft 1.20.1 / Fabric / Java 17 para o projeto **ArcForge**), execução segura e sob demanda de agentes CLI, integração Android via USB/Termux, 4 perfis de desempenho e a suíte real de benchmarks dos 7 cenários — tudo dentro dos ~6 GB utilizáveis do Ryzen 5 3400G.

---

## 1. Toolchain de Desenvolvimento e Gerenciamento por Projeto

- **Compiladores e Runtimes Oficiais:** `gcc`, `clang`, `mingw-w64-gcc`, `python`, `nodejs`, `npm`, `jdk17-openjdk`, `gradle`, `git`.
- **Múltiplas Versões sem Poluir o Sistema:** No Arch Linux, várias versões do OpenJDK (`8`, `11`, `17`, `21`, `25`) coexistem sem conflito via `archlinux-java` ([ArchWiki Java](https://wiki.archlinux.org/title/Java)). Para Python/Node, use ambientes virtuais por projeto (`python -m venv`, `pipx`) em vez de instalar versões antigas globalmente.
- **Compatibilidade Minecraft 1.20.1 / Fabric / Projeto ArcForge:**
  - Use `source ~/.local/bin/easyarch-arcforge-env.sh` para fixar `JAVA_HOME=/usr/lib/jvm/java-17-openjdk` apenas na sessão do projeto.
  - Copie `config/gradle/gradle.properties.arcforge` para `~/.gradle/gradle.properties` (ou para a raiz do projeto): limita o heap a `-Xmx2048m`, desativa o daemon residente (`org.gradle.daemon=false`) e limita workers a 4 para compilar sem pressionar o OOM Killer nos ~6 GB úteis.
- **Editor / IDE:** VS Code (ou VSCodium/Neovim) deve ser usado **sem** extensões ociosas em segundo plano; ao compilar projetos Java grandes, feche o navegador ou abas pesadas para evitar competição por RAM.

---

## 2. Agentes CLI e Segurança de Chaves de API

- **Zero Consumo em Background:** OmniRoute, OpenCode, Codex CLI e Hermes Agent são invocados exclusivamente sob demanda via `easyarch-agents.sh`. Nenhum daemon de IA fica residente em memória.
- **Armazenamento Seguro de Chaves:** Nunca salve chaves de API em `~/.bashrc`, `config.fish`, arquivos `.env` versionados no Git ou arquivos públicos. O wrapper `easyarch-agents.sh` lê segredos diretamente do cofre criptografado (`pass` + GPG ou `libsecret`/`secret-tool`) apenas na memória do processo filho e descarta ao encerrar.

---

## 3. Integração com Smartphone Android (ADB, scrcpy e Offload via Termux)

- **Ferramentas Oficiais:** `android-tools` (`adb`), `android-udev` e `scrcpy` ([ArchWiki ADB](https://wiki.archlinux.org/title/Android_Debug_Bridge)).
- **Esclarecimento Técnico Honesto:** Conectar o smartphone via USB **não** transfere nem soma automaticamente a CPU ou GPU do celular ao barramento do computador.
- **Arquitetura Concreta e Testável de Offload (`easyarch-phone.sh offload`):**
  1. No smartphone (Termux): instale `openssh` (`pkg install openssh`), configure chave pública SSH e inicie `sshd` (porta padrão `8022`).
  2. No Linux Forge: o script executa `adb forward tcp:8022 tcp:8022` (túnel USB de baixa latência, sem depender de Wi-Fi).
  3. O computador envia uma tarefa específica (ex.: processamento Python, compactação, script de automação ou agente leve) via SSH sobre o túnel USB e sincroniza os resultados de volta com `rsync`/`scp`.
  4. **Benefício real:** Descarrega tarefas discretas e paralelizáveis sem consumir RAM dos ~6 GB do Ryzen 5 3400G, de forma 100% mensurável e reproduzível.

---

## 4. Perfis de Desempenho (`easyarch-profile.sh`)

Cada perfil modifica apenas parâmetros tecnicamente justificados ([ArchWiki CPU frequency scaling](https://wiki.archlinux.org/title/CPU_frequency_scaling)):

| Perfil | Governador CPU (`cpupower`) | Hyprland / Efeitos | Uso Recomendado |
| :--- | :--- | :--- | :--- |
| **`economico`** | `powersave` / `conservative` | Animações ligadas, `vfr=true` | Leitura, estudo, terminal e tarefas leves |
| **`equilibrado`** | `schedutil` (padrão) | Animações suaves 75 Hz, `vfr=true` | Uso diário geral |
| **`jogos`** | `performance` | Desativa animações/opacidade do compositor durante o jogo; recomenda `gamescope` + RADV | Steam/Proton, Lutris (avalie nativo 1080p vs. FSR caso a caso — sem promessa de ganho garantido) |
| **`dev`** | `schedutil` | Mantém `earlyoom` protegendo compiladores + aplica limites Gradle (`-Xmx2048m`) | Compilação Java 17/Gradle (ArcForge), GCC/Clang, Node |

---

## 5. Suíte de Benchmarks e Critérios de Aceitação (7 Cenários Reais)

O script `scripts/benchmarks/05-suite-benchmarks.sh` registra medições **reais** (nunca fictícias) em `~/easyarch-benchmarks/` para os 7 cenários obrigatórios:
1. `01-boot-limpo` (`systemd-analyze` + RAM pós-boot sem apps)
2. `02-desktop-ocioso` (Hyprland + Waybar + Dock + PipeWire)
3. `03-navegador-abas` (navegador com múltiplas abas abertas)
4. `04-build-java-gradle` (tempo de compilação + pico de RAM/ZRAM)
5. `05-jogo-proton` (MangoHud FPS/frametime + RAM/temperatura)
6. `06-app-wine` (uso de RAM + confirmação `/dev/ntsync`)
7. `07-app-waydroid` (uso durante execução + verificação obrigatória **pós-encerramento** para provar liberação de RAM)

---

## 6. Guia de Instalação, Verificação e Manutenção

1. Instale os pacotes oficiais:
   `mapfile -t pkgs < <(grep -Ev '^\s*(#|$)' packages/fase4-dev-mobile.txt) && sudo pacman -S --needed "${pkgs[@]}"`
2. Instale os scripts de usuário (não destrutivo):
   `./scripts/instalacao/04-instalar-fase4.sh`
3. Teste cada módulo individualmente:
   - `source ~/.local/bin/easyarch-arcforge-env.sh && java -version`
   - `easyarch-phone.sh status`
   - `easyarch-profile.sh status`
   - `05-suite-benchmarks.sh 02-desktop-ocioso`
   - `02-manutencao-rotina.sh`
