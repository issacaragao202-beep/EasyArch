#!/usr/bin/env bash
# ==============================================================================
# EasyArch — Script de Manutenção de Rotina (Auditável e Seguro)
# Destino: ~/.local/bin/02-manutencao-rotina.sh
#
# Não apaga dados nem executa operações destrutivas automaticamente; apenas
# diagnostica estado do SSD, snapshots, órfãos do Pacman e cache.
# ==============================================================================

set -uo pipefail

printf '============================================================\n'
printf ' EasyArch — MANUTENÇÃO E SAÚDE (%s)\n' "$(date -Is)"
printf '============================================================\n\n'

printf '--- 1. Espaço em Disco e Compressão Btrfs ---\n'
df -h / /home 2>/dev/null || df -h /
printf '\n'

printf '--- 2. Serviços com Falha (systemd --failed) ---\n'
systemctl --failed --no-pager 2>/dev/null || true
printf '\n'

printf '--- 3. Status do TRIM Periódico (fstrim.timer) ---\n'
systemctl status fstrim.timer --no-pager 2>/dev/null | head -n 8 || true
printf '\n'

printf '--- 4. Pacotes Órfãos do Pacman (apenas listagem) ---\n'
pacman -Qdtq 2>/dev/null || printf 'Nenhum pacote órfão encontrado.\n'
printf '\n'

printf '--- 5. Tamanho do Cache do Pacman ---\n'
du -sh /var/cache/pacman/pkg 2>/dev/null || true
printf '(Para limpar mantendo as 2 últimas versões, rode manualmente: sudo paccache -rk2)\n\n'

printf '--- 6. Snapshots Snapper (requer sudo para listar) ---\n'
if command -v snapper >/dev/null 2>&1; then
    snapper -c root list 2>/dev/null || printf 'Execute com sudo para listar snapshots do Snapper.\n'
fi
