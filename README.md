# KiwiSolver

Swift bindings for the [Kiwi](https://github.com/nucleic/kiwi) C++ implementation of the Cassowary constraint solving algorithm.

## Installation

SPM doesn't clone git submodules, so this package must be used as a local dependency:

```
git clone --recurse-submodules https://github.com/nucleic/kiwi-swift.git
```

Or if already cloned:

```
git submodule update --init
```

Then add it as a local package in your `Package.swift`:

```swift
dependencies: [
    .package(path: "../kiwi-swift"),
]
```

## Usage

```swift
import KiwiSolver

let solver = Solver()

let x = Variable("x")
let y = Variable("y")

try solver.addConstraint(x + y == 100)
try solver.addConstraint(x == 40)
solver.updateVariables()
// x.value == 40, y.value == 60

// Constraint strengths
try solver.addConstraint((y >= 70) | .weak)
// Required constraints still win — y stays 60

// Linear expressions
let a = Variable("a")
let b = Variable("b")
try solver.addConstraint(a == 2 * b)
try solver.addConstraint(a + b == 90)
solver.updateVariables()
// a.value == 60, b.value == 30
```

Strengths: `.required`, `.strong`, `.medium`, `.weak`, or a custom `Double`.

## Building

```
make              # debug build
make release      # release build
make test         # run tests
make run          # run KiwiTest example
make generate     # regenerate C++ wrapper from kiwi headers
make help         # list all targets
```

## Platforms

iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+

## License

BSD-3-Clause (same as Kiwi)
