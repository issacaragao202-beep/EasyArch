# Instalação ISO 1 Comando e Pós-Instalação 1 Clique — EasyArch v5.3

> **Escopo:** Reduzir a barreira de entrada para iniciantes vindos do Windows sem depender do schema mutável do `archinstall` em modo unattended.

## Melhorias da v5.3
1. **Instalador Guiado da Live ISO (`scripts/instalacao/easyarch-instalar-iso.sh`, comando `easyarch-instalar`):**
   - Exibido automaticamente no banner de boot da Live ISO (`/root/.zprofile`).
   - Checa UEFI, abre `nmtui` automaticamente se não houver internet e oferece 2 caminhos: **Automático Guiado** (4 perguntas simples + confirmação literal `APAGAR <disco>`, cria GPT + EFI 1 GiB + Btrfs `@`/`@home`/`@snapshots` + LUKS2 opcional + `systemd-boot` com AppArmor/zswap + `/etc` + Snapper + Glacial HUD prontos no primeiro boot) ou **Personalizado / Dual-Boot** (`archinstall` oficial).
2. **Pós-Instalação em 1 Clique (`scripts/instalacao/easyarch-setup.sh` + `--yes` em `easyarch-aplicar-etc.sh`):**
   - Novo seletor inicial com **1) Completo em 1 Clique** (`--auto`), **2) Essencial Ultra-Leve** (`--essencial`) e **3) Personalizado** (`--personalizado`), eliminando as 10 confirmações repetitivas.
