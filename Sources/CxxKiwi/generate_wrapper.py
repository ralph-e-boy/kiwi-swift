#!/usr/bin/env python3
"""Generate Sources/CxxKiwi/include/KiwiWrapper.h from kiwi/ C++ headers.

Usage:
    python Sources/CxxKiwi/generate_wrapper.py                  # Regenerate
    python Sources/CxxKiwi/generate_wrapper.py --validate-only  # Check drift
    python Sources/CxxKiwi/generate_wrapper.py --diff           # Preview
"""

from __future__ import annotations

import argparse
import difflib
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Sequence

# ---------------------------------------------------------------------------
# Paths — derived from script location so any cwd works
# ---------------------------------------------------------------------------

SCRIPT_DIR = Path(__file__).resolve().parent          # Sources/CxxKiwi/
REPO_ROOT = SCRIPT_DIR.parent.parent                   # repo root
KIWI_DIR = REPO_ROOT / "kiwi" / "kiwi"
OUTPUT_PATH = SCRIPT_DIR / "include" / "KiwiWrapper.h"

# ---------------------------------------------------------------------------
# Import config (lives next to this script)
# ---------------------------------------------------------------------------

sys.path.insert(0, str(SCRIPT_DIR))
from wrapper_config import (
    ACCESSORS,
    CONSTRAINT_BUILDER_SECTIONS,
    OPERATOR_ORDER,
    OPERATORS,
    SKIP_METHODS,
    SKIP_STRENGTH_FUNCTIONS,
)

# ---------------------------------------------------------------------------
# Kiwi types that need kiwi:: qualification in the wrapper namespace
# ---------------------------------------------------------------------------

_KIWI_TYPES = ("Variable", "Constraint", "Term", "Expression", "RelationalOperator")


def _qualify_type(type_str: str) -> str:
    """Add kiwi:: prefix to bare kiwi type names."""
    for t in _KIWI_TYPES:
        type_str = re.sub(rf"(?<!kiwi::)\b{t}\b", f"kiwi::{t}", type_str)
    return type_str


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class ExceptionClass:
    name: str


@dataclass(frozen=True)
class SolverMethod:
    name: str
    return_type: str
    params: tuple[tuple[str, str], ...]   # ((type, name), ...)
    is_const: bool
    throws: tuple[str, ...]               # exception names, errors.h order


@dataclass(frozen=True)
class StrengthParam:
    type: str
    name: str
    default: str | None = None


@dataclass(frozen=True)
class StrengthFunction:
    name: str
    params: tuple[StrengthParam, ...]


@dataclass(frozen=True)
class StrengthConstant:
    name: str


# ---------------------------------------------------------------------------
# Parsers
# ---------------------------------------------------------------------------

def _read(header: str) -> str:
    path = KIWI_DIR / header
    if not path.exists():
        raise FileNotFoundError(f"Missing header: {path}")
    return path.read_text()


def parse_exceptions() -> tuple[ExceptionClass, ...]:
    """Parse kiwi/errors.h → exception class names in declaration order."""
    text = _read("errors.h")
    return tuple(
        ExceptionClass(m)
        for m in re.findall(r"class\s+(\w+)\s*:\s*public\s+std::exception", text)
    )


def parse_solver(exceptions: Sequence[ExceptionClass]) -> tuple[SolverMethod, ...]:
    """Parse kiwi/solver.h → public method info with Throws annotations."""
    text = _read("solver.h")

    pub = re.search(r"public:\s*\n", text)
    priv = re.search(r"private:\s*\n", text)
    if not pub or not priv:
        raise RuntimeError("Cannot locate public/private sections in solver.h")

    section = text[pub.end() : priv.start()]
    exc_order = {e.name: i for i, e in enumerate(exceptions)}

    block_re = re.compile(
        r"/\*(.*?)\*/\s*\n\s*"        # doc comment
        r"([\w:< >*&]+?)\s+"          # return type
        r"(\w+)\s*"                    # method name
        r"\(\s*(.*?)\s*\)"             # params
        r"(\s*const)?"                 # optional const
        r"\s*\{",
        re.DOTALL,
    )

    methods: list[SolverMethod] = []
    for m in block_re.finditer(section):
        comment, ret, name, params_raw, const_q = m.groups()
        if name in ("Solver", "~Solver"):
            continue

        # Parse Throws block
        throws_match = re.search(
            r"Throws\s*\n\s*-+\s*\n(.*?)(?=\n\s*$|\Z)", comment, re.DOTALL
        )
        throws_raw: list[str] = []
        if throws_match:
            throws_raw = re.findall(r"^\s*(\w+)\s*$", throws_match.group(1), re.MULTILINE)
        throws = tuple(sorted(throws_raw, key=lambda n: exc_order.get(n, 999)))

        # Parse params
        params: list[tuple[str, str]] = []
        if params_raw.strip():
            for p in re.split(r",\s*", params_raw.strip()):
                parts = p.rsplit(None, 1)
                if len(parts) == 2:
                    params.append((parts[0], parts[1]))

        methods.append(SolverMethod(
            name=name,
            return_type=ret.strip(),
            params=tuple(params),
            is_const=const_q is not None,
            throws=throws,
        ))

    return tuple(methods)


def parse_strength() -> tuple[tuple[StrengthConstant, ...], tuple[StrengthFunction, ...]]:
    """Parse kiwi/strength.h → constants and functions."""
    text = _read("strength.h")

    constants = tuple(
        StrengthConstant(m)
        for m in re.findall(r"const\s+double\s+(\w+)\s*=", text)
    )

    functions: list[StrengthFunction] = []
    for m in re.finditer(r"inline\s+double\s+(\w+)\s*\((.*?)\)", text):
        name, params_raw = m.group(1), m.group(2).strip()
        params: list[StrengthParam] = []
        for p in re.split(r",\s*", params_raw):
            p = p.strip()
            default = None
            if "=" in p:
                p, default = p.rsplit("=", 1)
                p, default = p.strip(), default.strip()
            parts = p.rsplit(None, 1)
            if len(parts) == 2:
                params.append(StrengthParam(parts[0], parts[1], default))
        functions.append(StrengthFunction(name, tuple(params)))

    return constants, tuple(functions)


def parse_relational_operators() -> tuple[str, ...]:
    """Parse kiwi/constraint.h → RelationalOperator enum values."""
    text = _read("constraint.h")
    enum_match = re.search(r"enum\s+RelationalOperator\s*\{(.*?)\}", text, re.DOTALL)
    if not enum_match:
        raise RuntimeError("Cannot find RelationalOperator enum in constraint.h")
    return tuple(re.findall(r"(\w+)", enum_match.group(1)))


# ---------------------------------------------------------------------------
# Renderers — each returns a complete section string (no trailing newline)
# ---------------------------------------------------------------------------

def _render_accessors() -> str:
    lines: list[str] = []
    for i, acc in enumerate(ACCESSORS):
        if i > 0:
            lines.append("")
        lines.append(acc["section_comment"])
        lines.append(
            f'inline {acc["return_type"]} {acc["func_name"]}'
            f'(const kiwi::{acc["class_name"]}& {acc["param_name"]}) {{'
        )
        lines.append(
            f'    return {acc["param_name"]}.{acc["method"]}();'
            f'  {acc["inline_comment"]}'
        )
        lines.append("}")
    return "\n".join(lines)


def _render_expression_builder() -> str:
    return "\n".join((
        "// Term builder for Swift (avoids std::vector template issues)",
        "class ExpressionBuilder {",
        "public:",
        "    ExpressionBuilder() : m_constant(0.0) {}",
        "",
        "    void addTerm(const kiwi::Variable& var, double coefficient) {",
        "        m_terms.push_back(kiwi::Term(var, coefficient));",
        "    }",
        "",
        "    void setConstant(double constant) {",
        "        m_constant = constant;",
        "    }",
        "",
        "    kiwi::Expression build() const {",
        "        return kiwi::Expression(m_terms, m_constant);",
        "    }",
        "",
        "    kiwi::Constraint buildConstraint(kiwi::RelationalOperator op, double strength) const {",
        "        return kiwi::Constraint(build(), op, strength);",
        "    }",
        "",
        "private:",
        "    std::vector<kiwi::Term> m_terms;",
        "    double m_constant;",
        "};",
    ))


def _render_constraint_method(
    method_name: str,
    description: str,
    params: Sequence[tuple[str, str]],
    terms: Sequence[str],
    constant_expr: str,
    op_enum: str,
    wrap_after: Sequence[int],
) -> list[str]:
    """Render one static ConstraintBuilder method."""
    lines: list[str] = []
    lines.append(f"    // {description}")

    # Full param list (pattern params + strength default)
    param_strs = [f"{t} {n}" for t, n in params]
    param_strs.append("double strength = kiwi::strength::required")

    prefix = f"    static kiwi::Constraint {method_name}("

    if wrap_after:
        indent = " " * len(prefix)
        groups: list[list[str]] = []
        current: list[str] = []
        for idx, ps in enumerate(param_strs):
            current.append(ps)
            if idx in wrap_after:
                groups.append(current)
                current = []
        if current:
            groups.append(current)

        for gi, group in enumerate(groups):
            joined = ", ".join(group)
            if gi == 0:
                lines.append(f"{prefix}{joined},")
            elif gi < len(groups) - 1:
                lines.append(f"{indent}{joined},")
            else:
                lines.append(f"{indent}{joined}) {{")
    else:
        all_params = ", ".join(param_strs)
        lines.append(f"{prefix}{all_params}) {{")

    # Body
    if len(terms) == 1:
        lines.append(
            f"        return kiwi::Constraint("
            f"kiwi::Expression({terms[0]}, {constant_expr}), "
            f"kiwi::{op_enum}, strength);"
        )
    else:
        terms_init = ", ".join(terms)
        lines.append(f"        std::vector<kiwi::Term> terms = {{{terms_init}}};")
        lines.append(
            f"        return kiwi::Constraint("
            f"kiwi::Expression(std::move(terms), {constant_expr}), "
            f"kiwi::{op_enum}, strength);"
        )

    lines.append("    }")
    return lines


def _render_constraint_builder() -> str:
    lines: list[str] = [
        "// Constraint builders for Swift (avoiding operator overloading issues)",
        "struct ConstraintBuilder {",
    ]

    for si, section in enumerate(CONSTRAINT_BUILDER_SECTIONS):
        lines.append(f'    // === {section["header"]} ===')

        for pattern in section["patterns"]:
            wrap_after = pattern.get("wrap_after", ())
            for op_key in OPERATOR_ORDER:
                if op_key not in pattern["methods"]:
                    continue
                lines.append("")
                lines.extend(_render_constraint_method(
                    method_name=pattern["methods"][op_key],
                    description=pattern["description"].replace("{op}", OPERATORS[op_key]["symbol"]),
                    params=pattern["params"],
                    terms=pattern["terms"],
                    constant_expr=pattern["constant_expr"],
                    op_enum=OPERATORS[op_key]["enum"],
                    wrap_after=wrap_after,
                ))

        if si < len(CONSTRAINT_BUILDER_SECTIONS) - 1:
            lines.append("")

    lines.append("};")
    return "\n".join(lines)


def _render_error_enum(exceptions: Sequence[ExceptionClass]) -> str:
    lines: list[str] = [
        "// Error codes for Swift",
        "enum class SolverError : int {",
        "    None = 0,",
    ]
    idx = 1
    for exc in exceptions:
        if exc.name == "InternalSolverError":
            continue
        lines.append(f"    {exc.name} = {idx},")
        idx += 1
    lines.append(f"    InternalError = {idx}")
    lines.append("};")
    return "\n".join(lines)


def _render_solver_result() -> str:
    return "\n".join((
        "// Result type for operations that can fail",
        "struct SolverResult {",
        "    SolverError error = SolverError::None;",
        "    std::string message;",
        "",
        "    bool ok() const { return error == SolverError::None; }",
        "",
        "    static SolverResult success() { return SolverResult{}; }",
        "",
        "    static SolverResult fromError(SolverError err, const char* msg) {",
        "        SolverResult r;",
        "        r.error = err;",
        "        r.message = msg;",
        "        return r;",
        "    }",
        "};",
    ))


def _render_solver_wrapper(
    methods: Sequence[SolverMethod],
    exceptions: Sequence[ExceptionClass],
) -> str:
    lines: list[str] = [
        "// Swift-friendly Solver (wraps kiwi::Solver which isn't directly importable)",
        "class Solver {",
        "public:",
        "    Solver() : m_solver(std::make_unique<kiwi::Solver>()) {}",
        "",
        "    // Non-throwing versions that return results",
    ]

    first = True
    for method in methods:
        if method.name in SKIP_METHODS:
            continue

        if not first:
            lines.append("")
        first = False

        params_str = ", ".join(
            f"{_qualify_type(t)} {n}" for t, n in method.params
        )
        const_suffix = " const" if method.is_const else ""
        args_str = ", ".join(n for _, n in method.params)

        if method.throws:
            lines.append(f"    SolverResult {method.name}({params_str}) {{")
            lines.append("        try {")
            lines.append(f"            m_solver->{method.name}({args_str});")
            lines.append("            return SolverResult::success();")

            for exc_name in method.throws:
                lines.append(f"        }} catch (const kiwi::{exc_name}& e) {{")
                lines.append(
                    f"            return SolverResult::fromError("
                    f"SolverError::{exc_name}, e.what());"
                )

            lines.append("        } catch (const std::exception& e) {")
            lines.append(
                "            return SolverResult::fromError("
                "SolverError::InternalError, e.what());"
            )
            lines.append("        }")
            lines.append("    }")
        else:
            ret = _qualify_type(method.return_type)
            lines.append(f"    {ret} {method.name}({params_str}){const_suffix} {{")
            if method.return_type == "void":
                lines.append(f"        m_solver->{method.name}({args_str});")
            else:
                lines.append(f"        return m_solver->{method.name}({args_str});")
            lines.append("    }")

    lines.append("")
    lines.append("private:")
    lines.append("    std::unique_ptr<kiwi::Solver> m_solver;")
    lines.append("};")
    return "\n".join(lines)


def _render_strength(
    constants: Sequence[StrengthConstant],
    functions: Sequence[StrengthFunction],
) -> str:
    lines: list[str] = [
        "// Strength constants for Swift",
        "struct Strength {",
    ]

    for c in constants:
        lines.append(f"    static double {c.name}() {{ return kiwi::strength::{c.name}; }}")

    for f in functions:
        if f.name in SKIP_STRENGTH_FUNCTIONS:
            continue
        param_parts = []
        for p in f.params:
            s = f"{p.type} {p.name}"
            if p.default is not None:
                s += f" = {p.default}"
            param_parts.append(s)
        params_str = ", ".join(param_parts)
        args_str = ", ".join(p.name for p in f.params)

        lines.append("")
        lines.append(f"    static double {f.name}({params_str}) {{")
        lines.append(f"        return kiwi::strength::{f.name}({args_str});")
        lines.append("    }")

    lines.append("};")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Full assembly
# ---------------------------------------------------------------------------

def render_full(
    exceptions: Sequence[ExceptionClass],
    solver_methods: Sequence[SolverMethod],
    strength_constants: Sequence[StrengthConstant],
    strength_functions: Sequence[StrengthFunction],
) -> str:
    sections = (
        "#pragma once",
        '#include "kiwi/kiwi.h"',
        "#include <memory>",
        "",
        "namespace kiwi_swift {",
        "",
        _render_accessors(),
        "",
        _render_expression_builder(),
        "",
        _render_constraint_builder(),
        "",
        _render_error_enum(exceptions),
        "",
        _render_solver_result(),
        "",
        _render_solver_wrapper(solver_methods, exceptions),
        "",
        _render_strength(strength_constants, strength_functions),
        "",
        "} // namespace kiwi_swift",
    )
    return "\n".join(sections) + "\n"


# ---------------------------------------------------------------------------
# Validator
# ---------------------------------------------------------------------------

def validate(
    exceptions: Sequence[ExceptionClass],
    solver_methods: Sequence[SolverMethod],
    strength_constants: Sequence[StrengthConstant],
    strength_functions: Sequence[StrengthFunction],
    rel_ops: Sequence[str],
) -> tuple[list[str], list[str]]:
    """Return (errors, warnings) from validating config against parsed headers."""
    errors: list[str] = []
    warnings: list[str] = []

    # Every solver method accounted for
    for method in solver_methods:
        if method.name not in SKIP_METHODS:
            for exc_name in method.throws:
                known = {e.name for e in exceptions}
                if exc_name not in known:
                    errors.append(
                        f"Solver.{method.name} throws {exc_name}"
                        f" which is not in errors.h"
                    )

    # RelationalOperator coverage
    config_ops = {
        OPERATORS[ok]["enum"]
        for section in CONSTRAINT_BUILDER_SECTIONS
        for pattern in section["patterns"]
        for ok in pattern["methods"]
    }
    parsed_ops = set(rel_ops)
    for op in config_ops - parsed_ops:
        errors.append(f"Config references {op} but not in RelationalOperator enum")
    for op in parsed_ops - config_ops:
        warnings.append(f"RelationalOperator {op} exists but unused in constraint builders")

    # Strength coverage
    wrapped_constants = {c.name for c in strength_constants}
    for c in strength_constants:
        if c.name not in wrapped_constants:
            warnings.append(f"Strength constant {c.name} not wrapped")

    return errors, warnings


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description="Generate KiwiWrapper.h")
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "--validate-only",
        action="store_true",
        help="Check for drift without writing; exit non-zero if stale",
    )
    group.add_argument(
        "--diff",
        action="store_true",
        help="Show what would change without writing",
    )
    args = parser.parse_args()

    # Parse headers
    exceptions = parse_exceptions()
    solver_methods = parse_solver(exceptions)
    strength_constants, strength_functions = parse_strength()
    rel_ops = parse_relational_operators()

    # Validate
    errs, warns = validate(
        exceptions, solver_methods, strength_constants, strength_functions, rel_ops
    )
    for w in warns:
        print(f"WARNING: {w}", file=sys.stderr)
    for e in errs:
        print(f"ERROR: {e}", file=sys.stderr)
    if errs:
        return 1

    # Render
    generated = render_full(
        exceptions, solver_methods, strength_constants, strength_functions
    )

    # Read existing
    existing = OUTPUT_PATH.read_text() if OUTPUT_PATH.exists() else ""

    if args.validate_only:
        if generated == existing:
            print("KiwiWrapper.h is up to date.")
            return 0
        else:
            print("KiwiWrapper.h is stale. Run generate_wrapper.py to update.")
            # Show a summary of differences
            diff = difflib.unified_diff(
                existing.splitlines(keepends=True),
                generated.splitlines(keepends=True),
                fromfile="current KiwiWrapper.h",
                tofile="generated KiwiWrapper.h",
            )
            sys.stdout.writelines(diff)
            return 1

    if args.diff:
        diff = list(difflib.unified_diff(
            existing.splitlines(keepends=True),
            generated.splitlines(keepends=True),
            fromfile="current KiwiWrapper.h",
            tofile="generated KiwiWrapper.h",
        ))
        if diff:
            sys.stdout.writelines(diff)
        else:
            print("No changes.")
        return 0

    # Write
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(generated)
    print(f"Generated {OUTPUT_PATH.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
