# PROJECT_STATE — EasyArch v5.4 (Correção Integral dos 6 Bugs pós-v5.3)

> **Versão única do repositório:** `EasyArch v5.4` · **Data:** 2026-11-21
> **Hardware-alvo:** AMD Ryzen 5 3400G (4C/8T · Zen+) · Radeon Vega 11 · 8 GB DDR4 single-channel 2667 MHz (~6 GB utilizáveis) · Mancer B450M-DA V2SC · SSD SATA Kingston A400 240 GB · Monitor 1920×1080 @ 75 Hz · UEFI.

---

## 1. Pacote Atual
- **Arquivo:** `easyarch-v5.4.zip` (repositório limpo e unificado sob `easyarch/`).
- **Relatórios de Auditoria e Evolução:** `docs/08-auditoria-e-correcoes-estruturais-v4.1.md` até `docs/21-auditoria-e-correcoes-v5.4.md`.

## 2. Estado Real das Validações (Sem Resultados Fictícios)
- **Sintaxe Bash (`bash -n`) e permissões `0755`:** Aprovadas em todos os 42 scripts `.sh` (41 em `scripts/` + `tests/run-tests.sh`).
- **Suíte `tests/run-tests.sh`:** 228 verificações automatizadas (incluindo regressões v5.4 para `chpasswd` seguro, `command -v swaync-client`, `jq` na Fase 2, `auto_yes` e `easyarch-calc.sh`).
- **Pendentes em ambiente real (Arch Linux VM UEFI e hardware Ryzen 5 3400G):** `mkarchiso`, execução real do `easyarch-instalar`, `nft -c`, `cpupower frequency-info`, boot UEFI + AppArmor + Hyprland + Waydroid.
