#!/usr/bin/env bash
# ==============================================================================
# Origem/Licença: incorpora fluxos modificados de classy-giraffe/easy-arch (Apache 2.0; ver LICENSE-APACHE-2.0 e NOTICE).
# EasyArch v5.5 — Atalho Raiz do Instalador Unificado (EasyArch + easy-arch)
# Delega diretamente para scripts/instalacao/easyarch-instalar-iso.sh.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/scripts/instalacao/easyarch-instalar-iso.sh" "$@"
