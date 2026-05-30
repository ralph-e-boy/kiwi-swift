# KiwiSolver Swift

A high-performance constraint solver for Swift, based on the [Kiwi](https://github.com/nucleic/kiwi) C++ implementation of the Cassowary algorithm. Solves linear constraint systems 40x faster than the original Cassowary with significantly lower memory usage.

**Use case:** Constraint-based layout that works anywhere — Metal graphics, custom rendering, game engines, or any graphics context where you need to compute positions and sizes from constraints.

## Why KiwiSolver?

Constraint-based layout is powerful but usually locked into UIKit/SwiftUI. KiwiSolver brings that power to graphics programming:

- **Metal-friendly**: Solve layout constraints, render with Metal at 60 fps
- **High performance**: 10-500x faster than original Cassowary (typical: 40x gain)
- **Memory efficient**: >5x lower memory overhead
- **Operator syntax**: Build constraints naturally with Swift operators
- **Strength-based resolution**: Constraints can be required or weighted (strong, medium, weak)

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/nucleic/kiwi-swift.git", branch: "main"),
]
```

For Xcode projects, use File → Add Packages and enter the repository URL.

## Quick Start

### Basic Constraint Solving

```swift
import KiwiSolver

let solver = Solver()

let x = Variable("x")
let y = Variable("y")

try solver.addConstraint(x + y == 100)
try solver.addConstraint(x == 40)

solver.updateVariables()

print(x.value)  // 40
print(y.value)  // 60
```

### Constraint Strengths

Constraints can be weighted to resolve conflicts:

```swift
try solver.addConstraint((y >= 70) | .weak)
solver.updateVariables()
// y stays 60, not 70, because the required constraints win

try solver.addConstraint(x >= 50)  // Conflict!
// Throws SolverError.DuplicateConstraint
```

Strength levels: `.required` (default), `.strong`, `.medium`, `.weak`, or custom `Double`.

### Linear Expressions

Constraints can use arithmetic:

```swift
let a = Variable("a")
let b = Variable("b")
let c = Variable("c")

try solver.addConstraint(a == 2 * b)
try solver.addConstraint(c == b + 10)
try solver.addConstraint(a + b + c == 100)

solver.updateVariables()
// Solves: 2b + b + (b + 10) = 100 → b = 22.5
// a = 45, b = 22.5, c = 32.5
```

## Layout API (AutoLayout for Graphics)

Use `LayoutBox`, `LayoutSolver`, and `LayoutAnchor` for constraint-based layout of drawable elements:

```swift
import KiwiSolver

let solver = LayoutSolver()

let header = LayoutBox("header")
let content = LayoutBox("content")
let footer = LayoutBox("footer")

solver.addBox(header)
solver.addBox(content)
solver.addBox(footer)

// Build a simple layout
solver.addConstraints([
    // Header: 80 points tall, full width, 20pt margin
    header.top == solver.container.top + 20,
    header.left == solver.container.left + 20,
    header.right == solver.container.right - 20,
    header.height == 80,
    
    // Content: below header, fills width, grows to footer
    content.top == header.bottom + 10,
    content.left == header.left,
    content.right == header.right,
    content.bottom == footer.top - 10,
    
    // Footer: 50 points tall at bottom
    footer.left == solver.container.left + 20,
    footer.right == solver.container.right - 20,
    footer.bottom == solver.container.bottom - 20,
    footer.height == 50,
])

// Solve for a 800×600 container
solver.setContainerSize(width: 800, height: 600)
solver.solve()

// Get solved frames for rendering
let headerFrame = header.floatFrame
let contentFrame = content.floatFrame
let footerFrame = footer.floatFrame

// Use with Metal or any graphics context
// renderHeader(at: headerFrame)
// renderContent(at: contentFrame)
// renderFooter(at: footerFrame)
```

### Layout Anchors

Each `LayoutBox` has anchors you can constrain:

```swift
public var left: LayoutAnchor      // Left edge
public var top: LayoutAnchor       // Top edge
public var width: LayoutAnchor     // Width
public var height: LayoutAnchor    // Height
public var right: LayoutAnchor     // Derived: left + width
public var bottom: LayoutAnchor    // Derived: top + height
public var centerX: LayoutAnchor   // Derived: left + width/2
public var centerY: LayoutAnchor   // Derived: top + height/2
```

### Convenience Methods

```swift
// Stack elements vertically
solver.verticalStack([box1, box2, box3], spacing: 10, insets: 20)

// Stack elements horizontally
solver.horizontalStack([box1, box2, box3], spacing: 10, insets: 20)

// Distribute boxes evenly (equal widths or heights)
solver.distributeHorizontally([col1, col2, col3])
solver.distributeVertically([row1, row2, row3])

// Position relative to other boxes
solver.addConstraint(box.below(header, spacing: 10))
solver.addConstraint(box.after(sibling, spacing: 5))

// Center alignment
solver.addConstraints(box.center(in: parent))
solver.addConstraints(box.centerHorizontally(in: parent))
solver.addConstraints(box.centerVertically(in: parent))

// Size constraints
solver.addConstraints(box.size(200, 100))
solver.addConstraint(box.fixedWidth(150))
solver.addConstraint(box.fixedHeight(50))

// Edge pinning
solver.addConstraints(box.pinEdges(to: parent, inset: 10))
solver.addConstraints(box.pinHorizontal(to: parent))
solver.addConstraints(box.pinVertical(to: parent))
```

## Demo

Run the included example:

```bash
swift run KiwiTest
```

This demonstrates basic constraint solving with variables and expressions.

## Building

```bash
swift build              # Debug build
swift build -c release   # Release build
swift test               # Run tests
```

## Performance

KiwiSolver inherits the speed of the Kiwi C++ library:

- **10-500x faster** than original Cassowary
- **Typical case**: 40x faster
- **Memory**: >5x more efficient

For graphics workloads, this means you can solve complex layouts every frame without impacting performance.

## Platforms

- iOS 13+
- macOS 10.15+
- tvOS 13+
- watchOS 6+
- visionOS 1+

## How It Works

KiwiSolver uses the Simplex algorithm to solve linear constraint systems. You define variables and relationships between them, then the solver finds values that satisfy all constraints while respecting their strengths.

This is the same constraint-solving approach used by CSS flexbox, NSLayoutConstraint, and constraint-based UI frameworks — now available for graphics programming.

## License

BSD-3-Clause (same as Kiwi)

## References

- [Kiwi C++ solver](https://github.com/nucleic/kiwi)
- [Cassowary constraint solving paper](https://constraints.cs.washington.edu/solvers/cassowary-tochi.pdf)
