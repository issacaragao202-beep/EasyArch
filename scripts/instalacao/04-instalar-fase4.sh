#!/usr/bin/env bash
# ==============================================================================
# EasyArch — Instalador Não Destrutivo da Fase 4 (Usuário)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

mkdir -p "${HOME}/.local/bin" "${HOME}/.gradle"

install -m 0755 "${ROOT_DIR}/scripts/dev/easyarch-arcforge-env.sh" "${HOME}/.local/bin/easyarch-arcforge-env.sh"
install -m 0644 "${ROOT_DIR}/scripts/dev/easyarch-arcforge-env.fish" "${HOME}/.local/bin/easyarch-arcforge-env.fish"
install -m 0755 "${ROOT_DIR}/scripts/dev/easyarch-agents.sh" "${HOME}/.local/bin/easyarch-agents.sh"
install -m 0755 "${ROOT_DIR}/scripts/mobile/easyarch-phone.sh" "${HOME}/.local/bin/easyarch-phone.sh"
install -m 0755 "${ROOT_DIR}/scripts/perfis/easyarch-profile.sh" "${HOME}/.local/bin/easyarch-profile.sh"
install -m 0755 "${ROOT_DIR}/scripts/benchmarks/05-suite-benchmarks.sh" "${HOME}/.local/bin/05-suite-benchmarks.sh"
install -m 0755 "${ROOT_DIR}/scripts/manutencao/02-manutencao-rotina.sh" "${HOME}/.local/bin/02-manutencao-rotina.sh"

if [[ ! -f "${HOME}/.gradle/gradle.properties" ]]; then
    install -m 0644 "${ROOT_DIR}/config/gradle/gradle.properties.arcforge" "${HOME}/.gradle/gradle.properties"
    printf '[OK] ~/.gradle/gradle.properties instalado com limites de memória para ArcForge.\n'
else
    printf '[AVISO] ~/.gradle/gradle.properties já existe; modelo mantido em config/gradle/gradle.properties.arcforge.\n'
fi

printf '[EasyArch] Ferramentas da Fase 4 instaladas em ~/.local/bin/.\n'
