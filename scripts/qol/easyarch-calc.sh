#!/usr/bin/env bash
# ==============================================================================
# EasyArch v5.4 — Calculadora Instantânea HUD (SUPER + C · Avaliação Segura)
# Destino: ~/.local/bin/easyarch-calc.sh
# Avalia expressões matemáticas sem eval arbitrário (AST seguro) e copia resultado.
# ==============================================================================

set -uo pipefail

safe_eval() {
    local expr="$1"
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$expr" <<'PY'
import ast, math, operator, sys

OPS = {
    ast.Add: operator.add, ast.Sub: operator.sub,
    ast.Mult: operator.mul, ast.Div: operator.truediv,
    ast.FloorDiv: operator.floordiv, ast.Mod: operator.mod,
    ast.Pow: operator.pow, ast.USub: operator.neg, ast.UAdd: operator.pos,
}
FUNCS = {
    "sqrt": math.sqrt, "abs": abs, "round": round,
    "sin": math.sin, "cos": math.cos, "tan": math.tan,
    "log": math.log10, "ln": math.log, "floor": math.floor, "ceil": math.ceil,
}
CONSTS = {"pi": math.pi, "e": math.e}

def ev(node):
    if isinstance(node, ast.Expression):
        return ev(node.body)
    if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
        return node.value
    if isinstance(node, ast.Name) and node.id in CONSTS:
        return CONSTS[node.id]
    if isinstance(node, ast.UnaryOp) and type(node.op) in OPS:
        return OPS[type(node.op)](ev(node.operand))
    if isinstance(node, ast.BinOp) and type(node.op) in OPS:
        left, right = ev(node.left), ev(node.right)
        if isinstance(node.op, ast.Pow) and abs(right) > 1000:
            raise ValueError("expoente alto demais")
        return OPS[type(node.op)](left, right)
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id in FUNCS:
        return FUNCS[node.func.id](*[ev(a) for a in node.args])
    raise ValueError("expressão não permitida")

try:
    expr = sys.argv[1].replace(",", ".").replace("^", "**")
    tree = ast.parse(expr, mode="eval")
    val = ev(tree)
    if isinstance(val, float) and val.is_integer():
        print(int(val))
    else:
        print(f"{val:.6g}")
except Exception as exc:
    print(f"[ERRO] {exc}", file=sys.stderr)
    sys.exit(1)
PY
    else
        if [[ "$expr" =~ ^[0-9[:space:].+\-*/()]+$ ]]; then
            awk "BEGIN { print ($expr) }" 2>/dev/null
        else
            return 1
        fi
    fi
}

if [[ "${1:-}" == "--eval" ]]; then
    shift
    [[ -z "${*:-}" ]] && exit 1
    safe_eval "$*"
    exit $?
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    printf 'Uso: easyarch-calc.sh [--eval "<expressao>"]\n'
    exit 0
fi

expr="${*:-}"
if [[ -z "$expr" ]]; then
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v rofi >/dev/null 2>&1; then
        expr="$(printf '' | rofi -dmenu -p "Calc HUD" -theme-str 'listview { lines: 0; }')"
    else
        read -r -p "Expressão matemática: " expr
    fi
fi
[[ -z "$expr" ]] && exit 0

if res="$(safe_eval "$expr" 2>/dev/null)" && [[ -n "$res" ]]; then
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy >/dev/null 2>&1; then
        printf '%s' "$res" | wl-copy
    fi
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v notify-send >/dev/null 2>&1; then
        notify-send "Calc HUD (copiado)" "${expr} = ${res}" || true
    fi
    printf '%s = %s\n' "$expr" "$res"
else
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v notify-send >/dev/null 2>&1; then
        notify-send "Calc HUD" "Expressão inválida: ${expr}" || true
    fi
    printf '[ERRO] Expressão inválida: %s\n' "$expr" >&2
    exit 1
fi
