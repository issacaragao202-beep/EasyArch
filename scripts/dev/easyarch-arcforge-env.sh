#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Ambiente Isolado Java 17 para Minecraft 1.20.1 / Fabric / ArcForge
# Uso: source ~/.local/bin/easyarch-arcforge-env.sh
# ==============================================================================

if [[ -d /usr/lib/jvm/java-17-openjdk ]]; then
    export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
    export PATH="${JAVA_HOME}/bin:${PATH}"
    export GRADLE_OPTS="-Xmx2048m -XX:+UseG1GC"
    printf '[EasyArch] Ambiente ArcForge (Java 17) ativado nesta sessão.\n'
    java -version
else
    printf '[ERRO] /usr/lib/jvm/java-17-openjdk não encontrado. Instale jdk17-openjdk.\n' >&2
    return 1 2>/dev/null || exit 1
fi
