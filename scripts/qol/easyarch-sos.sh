#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Guia Rápido de Recuperação de Emergência (Modo SOS)
# Destino: ~/.local/bin/easyarch-sos.sh (chamado por `easyarch sos` e Hub #12)
# ==============================================================================

set -uo pipefail

cat <<'EOF'
========================================================================
           EasyArch v5.4 — MODO SOS (GUIA DE RECUPERAÇÃO)
========================================================================

1. HYPRLAND NÃO ABRE OU TELA PRETA
   • Pressione Ctrl + Alt + F3 para abrir um terminal texto (TTY).
   • Veja os erros recentes:
       journalctl --user -b -p err
       ls -lt "$XDG_RUNTIME_DIR/hypr/"
   • Restaure dotfiles anteriores a partir do backup automático:
       ls -ld ~/.config-backup-*

2. SISTEMA NÃO DÁ BOOT APÓS ATUALIZAR KERNEL OU CONFIGS
   • No menu do systemd-boot, pressione 'e' na entrada do Arch Linux:
     - Suspeita de AppArmor: adicione `apparmor=0` ao final da linha.
     - Shell de emergência:  adicione `systemd.unit=rescue.target`.

3. REVERTER ATUALIZAÇÃO QUEBRADA VIA SNAPSHOT BTRFS (ARCH LIVE ISO)
   1) Dê boot no pendrive Arch Live ISO.
   2) (Se usar LUKS2) cryptsetup open /dev/<particao> cryptroot
   3) Monte o topo do Btrfs (subvolid=5):
        mount -o subvolid=5 /dev/<dispositivo-btrfs> /mnt
   4) Identifique o snapshot bom em /mnt/@snapshots/<N>/info.xml
   5) Mova a raiz quebrada e restaure o snapshot:
        mv /mnt/@ /mnt/@.quebrado
        btrfs subvolume snapshot /mnt/@snapshots/<N>/snapshot /mnt/@
   6) Desmonte (/mnt) e reinicie. Depois remova @.quebrado com
      `btrfs subvolume delete`.

4. REDE / DNS BLOQUEADO (PORTAL CATIVO EM HOTEL/AEROPORTO)
   • Edite /etc/systemd/resolved.conf.d/10-easyarch-dot.conf:
       DNSOverTLS=opportunistic
   • Reinicie: sudo systemctl restart systemd-resolved.service
========================================================================
EOF
