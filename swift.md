# Swift Package

KiwiSolver is available as a Swift package wrapping the C++ kiwi constraint solver.
It targets iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, and visionOS 1+.

## Adding to your project

In Xcode, add the package dependency pointing at this repo. Or in `Package.swift`:

```swift
.package(url: "https://github.com/nucleic/kiwi", from: "1.4.0")
```

Then import the `KiwiSolver` product `import KiwiSolver` 

## Building

The Swift package plugs into the existing CMake build. Enable it with:

```
cmake -DKIWI_SWIFT_WRAPPER=ON .
```

This gives you:

```
make swift-build                 # debug build (macOS)
make swift-build-release         # release build (macOS)
make swift-test                  # run tests
make swift-run                   # build and run KiwiTest example
make swift-clean                 # clean swift build artifacts
```

Cross-platform builds use xcodebuild under the hood:

```
make swift-build-ios             # iOS device
make swift-build-ios-simulator   # iOS Simulator
make swift-build-tvos            # tvOS (requires SDK)
make swift-build-watchos         # watchOS (requires SDK)
make swift-build-visionos        # visionOS (requires SDK)
make swift-build-all-platforms   # macOS + iOS + iOS Simulator
```

You can also use `swift build` and `xcodebuild` directly if you prefer.
The CMake targets are just convenience wrappers.

## Architecture

There are three layers:

```
kiwi/              C++ header-only library (upstream)
  |
Sources/CxxKiwi/   C++ wrapper for Swift interop
  |
Sources/KiwiSolver/ Idiomatic Swift API
```

**kiwi/** is the core C++ solver. It knows nothing about Swift.

**CxxKiwi** bridges the C++ API to something Swift's C++ interop can consume.
Swift can't handle C++ exceptions, const references as return types, or
`std::vector` in templates directly, so this layer provides:

- Return-by-value accessor functions (copies the value out of const refs)
- An `ExpressionBuilder` class that avoids exposing `std::vector<Term>` to Swift
- A `ConstraintBuilder` struct with static convenience methods
- A `Solver` wrapper that catches exceptions and returns error codes
- A `Strength` struct wrapping the namespace constants

**KiwiSolver** is the public Swift API. It wraps the C++ types in Swift classes
and structs, and provides operator overloading so you can write constraints
naturally:

```swift
let x = Variable("x")
let y = Variable("y")

let solver = Solver()
try solver.addConstraint(x + y == 100)
try solver.addConstraint(x >= 30 | .strong)
solver.updateVariables()
```

## The wrapper generator

`Sources/CxxKiwi/include/KiwiWrapper.h` is generated, not hand-maintained.
The generator lives at `Sources/CxxKiwi/generate_wrapper.py` and parses
the upstream `kiwi/` headers to produce the wrapper.

```
make generate-swift-wrapper      # regenerate KiwiWrapper.h
make validate-swift-wrapper      # check if it's stale (for CI)
```

Or run directly:

```
python Sources/CxxKiwi/generate_wrapper.py             # regenerate
python Sources/CxxKiwi/generate_wrapper.py --diff       # preview changes
python Sources/CxxKiwi/generate_wrapper.py --validate-only  # exit 1 if stale
```

### What it generates

Most of the wrapper is derived mechanically from the C++ headers:

- **Error enum**: one case per exception class in `kiwi/errors.h`
- **Solver wrapper**: try/catch blocks derived from the `Throws` doc annotations in `kiwi/solver.h`
- **Accessors**: generated for every const-ref return method on Variable, Term, Expression, Constraint
- **Strength struct**: mirrors constants and functions from `kiwi/strength.h`

### What comes from config

The `ConstraintBuilder` convenience methods are defined in
`Sources/CxxKiwi/wrapper_config.py`. This is because they're a convenience
API, not a 1:1 mapping of the C++ interface. Each entry defines a constraint
pattern that gets expanded across all three relational operators (==, >=, <=).

The current patterns:

| Pattern | Example | Methods generated |
|---------|---------|-------------------|
| Single variable | `x == 10` | `equalTo`, `greaterOrEqual`, `lessOrEqual` |
| Two variable | `x == y` | `equal`, `greaterOrEqualVar`, `lessOrEqualVar` |
| Two variable + offset | `x == y + 5` | `equalWithOffset`, `greaterOrEqualWithOffset`, `lessOrEqualWithOffset` |
| Sum | `x + y == 10` | `sumEqual`, `sumGreaterOrEqual`, `sumLessOrEqual` |
| Linear combination | `2*x + 3*y == 10` | `linearEqual`, `linearGreaterOrEqual`, `linearLessOrEqual` |

To add a new pattern, add an entry to `CONSTRAINT_BUILDER_SECTIONS` in
`wrapper_config.py` and run the generator.

### Validation

The generator validates that:

- Every exception class in `kiwi/errors.h` has a corresponding error enum value
- Every public Solver method is wrapped or explicitly skipped
- `RelationalOperator` enum values used in the config exist in the C++ headers

If upstream adds a new solver method or exception class, the validator
catches it.

## Documentation

DocC documentation can be generated with:

```
make swift-doc                   # generate .doccarchive
make swift-doc-preview           # live preview in browser
make swift-api                   # emit .swiftinterface to docs/build/
```

## File layout

Everything Swift-related lives under `Sources/` and doesn't interfere with
the C++/Python build:

```
Sources/
  CxxKiwi/
    include/
      KiwiWrapper.h              generated C++ wrapper
      CxxKiwi.h                  module header
      module.modulemap            clang module map
      kiwi -> ../../../kiwi       symlink to C++ headers
    CxxKiwi.cpp                   placeholder (header-only)
    generate_wrapper.py           wrapper generator
    wrapper_config.py             constraint builder config
  KiwiSolver/
    KiwiSolver.swift              public Swift API
  KiwiTest/
    main.swift                    example / smoke test
Package.swift                     Swift package manifest
```

