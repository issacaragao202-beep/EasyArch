# Auditoria e Correções — EasyArch v4.9

> **Escopo:** Correção mínima dos 4 bugs funcionais e 1 ajuste defensivo encontrados na varredura pós-v4.8.

## Correções Aplicadas
1. **`easyarch-setup.sh` (`cleanup_tmp`):** trocado `(( ${#TMP_FILES[@]} > 0 )) && rm -f ...` por `if (( ${#TMP_FILES[@]} > 0 )); then ... fi`, eliminando o retorno falso de erro (`exit 1`) em execuções normais sem arquivos temporários.
2. **`easyarch-setup.sh` (`ensure_multilib`):** bloco `awk` agora rastreia o estado dentro da seção `[multilib]` e descomenta especificamente a primeira linha `#Include =`, preservando comentários intermediários.
3. **`easyarch-kernel-params.sh` (`has_all_params` e `replace_first_line`):** `has_all_params` normaliza `TAB`, usa `set -f` e exige ocorrência única e exata de `lsm=` e `zswap.enabled=` (removendo parâmetros duplicados/conflitantes); `replace_first_line` garante limpeza do arquivo temporário mesmo em falha do `awk`.
4. **`easyarch-ai-assistant.sh`:** adicionada cobertura para remoção de kernels `linux-zen`, `linux-lts` e `linux-hardened`, e para `chmod 777`/`a+rwx` em diretórios críticos do sistema (`/etc`, `/boot`, `/usr`, `/var`, `/bin`, `/lib`, `/sbin`).
5. **`config/applications/easyarch-windows-safe.desktop`:** adicionado `--` antes de `"$1"` na invocação do `easyarch-win-run.sh`.
