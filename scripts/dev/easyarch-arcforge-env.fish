# ==============================================================================
# EasyArch v5.4 — Ambiente Isolado Java 17 para Fish Shell (Minecraft 1.20.1 / ArcForge)
# Uso no Fish: source ~/.local/bin/easyarch-arcforge-env.fish
# ==============================================================================

if test -d /usr/lib/jvm/java-17-openjdk
    set -gx JAVA_HOME /usr/lib/jvm/java-17-openjdk
    fish_add_path -p "$JAVA_HOME/bin"
    set -gx GRADLE_OPTS "-Xmx2048m -XX:+UseG1GC"
    printf '[EasyArch] Ambiente ArcForge (Java 17) ativado nesta sessão Fish.\n'
    java -version
else
    printf '[ERRO] /usr/lib/jvm/java-17-openjdk não encontrado. Instale jdk17-openjdk.\n' >&2
    return 1
end
