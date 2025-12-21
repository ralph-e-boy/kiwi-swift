# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kiwi is a C++ implementation of the Cassowary constraint solving algorithm with Python bindings. The package is published to PyPI as `kiwisolver`.

## Build and Development Commands

```bash
# Install the package in development mode
pip install -e .

# Run tests
pip install pytest
python -X dev -m pytest py -W error

# Run a single test file
python -m pytest py/tests/test_solver.py

# Run a specific test
python -m pytest py/tests/test_solver.py::test_solver_creation

# Lint and format
pip install -r lint_requirements.txt
ruff format py --check    # Check formatting
ruff format py            # Apply formatting
ruff check py             # Lint

# Type checking
mypy py
```

## Architecture

### Directory Structure

- `kiwi/` - Header-only C++ constraint solver library
- `py/` - Python bindings and package
  - `py/src/` - CPython extension module (C++ code using cppy)
  - `py/kiwisolver/` - Python package with type stubs and exceptions
  - `py/tests/` - pytest test suite
- `benchmarks/` - C++ benchmarking code

### Core Components

The solver implements these key types (exposed in both C++ and Python):

- **Variable** - A variable in the constraint system with a mutable value
- **Term** - A variable multiplied by a coefficient
- **Expression** - A sum of terms plus a constant
- **Constraint** - An expression with a relational operator (==, <=, >=) and strength
- **Solver** - The main constraint solver that manages variables and constraints
- **strength** - Namespace containing `required`, `strong`, `medium`, `weak` constraint strengths

### Python Extension

The Python bindings are implemented as a C extension (`kiwisolver._cext`) using the `cppy` library for CPython API helpers. The extension wraps the C++ types with Python-compatible interfaces including operator overloading for building constraints (e.g., `v1 + v2 == 0` creates a Constraint).

Constraints can have strength applied using the `|` operator: `(v >= 0) | "weak"`.
