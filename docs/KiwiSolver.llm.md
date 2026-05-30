# KiwiSolver — LLM reference

Auto-generated from symbol graph. Public surface only; signatures + doc-comments verbatim. Regenerate via the `generate-llm-ref` SPM command plugin.

**Module:** KiwiSolver  •  **Symbols:** 196

---

## Constraint  _(struct)_

`struct Constraint`

- `var op: RelationalOperator { get }`
- `var strength: Double { get }`
- `var violated: Bool { get }`
- `func with(strength: Strength) -> Constraint`

## Expression  _(struct)_

`struct Expression`

- `init(_ variable: Variable)`
- `init(_ term: Term)`
- `init(_ constant: Double)`
- `init(_ terms: [Term] = [], constant: Double = 0)`
- `var constant: Double`
- `var terms: [Term]`

## LayoutAnchor  _(struct)_

`struct LayoutAnchor`

A layout anchor representing a single constraint variable (left, top, width, etc.)
Use operators to build constraints: `box.left == other.right + 10`

- `var value: Double { get }`
  Current solved value

## LayoutBox  _(class)_

`final class LayoutBox`

A layoutable box with constraint anchors for position and size.
Use with LayoutSolver to define constraint-based layouts.

Example:
```swift
let header = LayoutBox("header")
let content = LayoutBox("content")

solver.addConstraints([
    header.top == solver.container.top + 20,
    header.left == solver.container.left + 20,
    header.right == solver.container.right - 20,
    header.height == 80,

    content.top == header.bottom + 10,
    content.left == header.left,
    content.right == header.right,
])
```

- `init(_ name: String = "box")`
- `var bottom: LayoutAnchor { get }`
  Bottom edge anchor (derived: top + height)
- `var centerX: LayoutAnchor { get }`
  Horizontal center anchor (derived: left + width/2)
- `var centerY: LayoutAnchor { get }`
  Vertical center anchor (derived: top + height/2)
- `var floatFrame: (x: Float, y: Float, width: Float, height: Float) { get }`
  Convenience for getting frame as Floats for drawing
- `var frame: CGRect { get }`
  The computed frame after solving constraints
- `var height: LayoutAnchor { get }`
  Height anchor
- `var left: LayoutAnchor { get }`
  Left edge anchor
- `let name: String`
- `var right: LayoutAnchor { get }`
  Right edge anchor (derived: left + width)
- `var top: LayoutAnchor { get }`
  Top edge anchor
- `var width: LayoutAnchor { get }`
  Width anchor
- `func above(_ other: LayoutBox, spacing: Double = 0) -> LayoutConstraint`
  Position above another box with spacing
- `func after(_ other: LayoutBox, spacing: Double = 0) -> LayoutConstraint`
  Position to the right of another box with spacing
- `func before(_ other: LayoutBox, spacing: Double = 0) -> LayoutConstraint`
  Position to the left of another box with spacing
- `func below(_ other: LayoutBox, spacing: Double = 0) -> LayoutConstraint`
  Position below another box with spacing
- `func center(in other: LayoutBox) -> [LayoutConstraint]`
  Center within another box
- `func centerHorizontally(in other: LayoutBox) -> [LayoutConstraint]`
  Center horizontally within another box
- `func centerVertically(in other: LayoutBox) -> [LayoutConstraint]`
  Center vertically within another box
- `func fixedHeight(_ value: Double) -> LayoutConstraint`
  Set fixed height
- `func fixedWidth(_ value: Double) -> LayoutConstraint`
  Set fixed width
- `func pinEdges(to other: LayoutBox, inset: Double = 0) -> [LayoutConstraint]`
  Pin all edges to another box with optional inset
- `func pinHorizontal(to other: LayoutBox, inset: Double = 0) -> [LayoutConstraint]`
  Pin horizontal edges (left and right)
- `func pinVertical(to other: LayoutBox, inset: Double = 0) -> [LayoutConstraint]`
  Pin vertical edges (top and bottom)
- `func size(_ width: Double, _ height: Double) -> [LayoutConstraint]`
  Set fixed size

## LayoutConstraint  _(struct)_

`struct LayoutConstraint`

A constraint between layout anchors/expressions.
Created using operators like `==`, `<=`, `>=`

## LayoutExpression  _(struct)_

`struct LayoutExpression`

An expression combining anchors and constants: `anchor + 10` or `anchor * 0.5`

## LayoutSolver  _(class)_

`final class LayoutSolver`

Manages constraint-based layout for a collection of LayoutBoxes.

Example:
```swift
let solver = LayoutSolver()
let header = LayoutBox("header")
let content = LayoutBox("content")

solver.addBox(header)
solver.addBox(content)

solver.addConstraints([
    header.top == solver.container.top + 20,
    header.left == solver.container.left + 20,
    header.right == solver.container.right - 20,
    header.height == 80,

    content.top == header.bottom + 10,
    content.pinHorizontal(to: header),
    content.bottom == solver.container.bottom - 20,
])

solver.setContainerSize(width: 800, height: 600)
solver.solve()

print(header.frame)  // CGRect with solved values
```

- `init()`
- `var allBoxes: [LayoutBox] { get }`
  Get all managed boxes
- `let container: LayoutBox`
  The root container box - set its size to define the layout bounds
- `@discardableResult func addBox(_ box: LayoutBox) -> LayoutBox`
  Add a box to be managed by this solver
- `func addConstraint(_ constraint: LayoutConstraint)`
  Add a single constraint
- `func addConstraints(_ constraints: [LayoutConstraint])`
  Add multiple constraints
- `func distributeHorizontally(_ boxes: [LayoutBox], spacing: Double = 0, insets: Double = 0)`
  Distribute boxes evenly in a row (equal widths)
- `func distributeVertically(_ boxes: [LayoutBox], spacing: Double = 0, insets: Double = 0)`
  Distribute boxes evenly in a column (equal heights)
- `func horizontalStack(_ boxes: [LayoutBox], spacing: Double = 0, insets: Double = 0)`
  Create a horizontal stack of boxes with spacing
- `func reset()`
  Reset the solver and remove all boxes and constraints
- `func setContainerSize(width: Double, height: Double)`
  Set the container size (call this when bounds change)
- `func solve()`
  Update all variables after constraint changes
- `func verticalStack(_ boxes: [LayoutBox], spacing: Double = 0, insets: Double = 0)`
  Create a vertical stack of boxes with spacing

## RelationalOperator  _(enum)_

`enum RelationalOperator`

- `case equal`
- `case greaterOrEqual`
- `case lessOrEqual`

## Solver  _(class)_

`final class Solver`

- `init()`
- `func addConstraint(_ constraint: Constraint) throws`
- `func addEditVariable(_ variable: Variable, strength: Strength) throws`
- `func hasConstraint(_ constraint: Constraint) -> Bool`
- `func hasEditVariable(_ variable: Variable) -> Bool`
- `func removeConstraint(_ constraint: Constraint) throws`
- `func removeEditVariable(_ variable: Variable) throws`
- `func reset()`
- `func suggestValue(_ variable: Variable, value: Double) throws`
- `func updateVariables()`

## SolverError  _(enum)_

`enum SolverError`

- `var description: String { get }`
  A textual representation of this instance.
  
  Calling this property directly is discouraged. Instead, convert an
  instance of any type to a string by using the `String(describing:)`
  initializer. This initializer works with any type, and uses the custom
  `description` property for types that conform to
  `CustomStringConvertible`:
  
      struct Point: CustomStringConvertible {
          let x: Int, y: Int
  
          var description: String {
              return "(\(x), \(y))"
          }
      }
  
      let p = Point(x: 21, y: 30)
      let s = String(describing: p)
      print(s)
      // Prints "(21, 30)"
  
  The conversion of `p` to a string in the assignment to `s` uses the
  `Point` type's `description` property.
- `case badRequiredStrength(String)`
- `case duplicateConstraint(String)`
- `case duplicateEditVariable(String)`
- `case internalError(String)`
- `case unknownConstraint(String)`
- `case unknownEditVariable(String)`
- `case unsatisfiableConstraint(String)`

## Strength  _(enum)_

`enum Strength`

- `var rawValue: Double { get }`
- `case custom(Double)`
- `case medium`
- `case required`
- `case strong`
- `case weak`

## Term  _(struct)_

`struct Term`

- `init(_ variable: Variable, coefficient: Double = 1.0)`
- `let coefficient: Double`
- `let variable: Variable`

## Variable  _(class)_

`final class Variable`

- `init(_ name: String)`
- `var name: String { get }`
- `var value: Double { get }`

- `func * (lhs: Variable, rhs: Double) -> Term`

- `func * (lhs: Double, rhs: Variable) -> Term`

- `func * (lhs: Term, rhs: Double) -> Term`

- `func * (lhs: Double, rhs: Term) -> Term`

- `func * (lhs: LayoutAnchor, rhs: Double) -> LayoutExpression`
  anchor * constant

- `func * (lhs: Double, rhs: LayoutAnchor) -> LayoutExpression`
  constant * anchor

- `func * (lhs: LayoutExpression, rhs: Double) -> LayoutExpression`
  expression * constant

- `func + (lhs: Variable, rhs: Variable) -> Expression`

- `func + (lhs: Variable, rhs: Double) -> Expression`

- `func + (lhs: Double, rhs: Variable) -> Expression`

- `func + (lhs: Term, rhs: Term) -> Expression`

- `func + (lhs: Term, rhs: Double) -> Expression`

- `func + (lhs: Double, rhs: Term) -> Expression`

- `func + (lhs: Expression, rhs: Term) -> Expression`

- `func + (lhs: Term, rhs: Expression) -> Expression`

- `func + (lhs: Expression, rhs: Variable) -> Expression`

- `func + (lhs: Variable, rhs: Expression) -> Expression`

- `func + (lhs: Expression, rhs: Double) -> Expression`

- `func + (lhs: Double, rhs: Expression) -> Expression`

- `func + (lhs: Expression, rhs: Expression) -> Expression`

- `func + (lhs: LayoutAnchor, rhs: Double) -> LayoutExpression`
  anchor + constant

- `func + (lhs: Double, rhs: LayoutAnchor) -> LayoutExpression`
  constant + anchor

- `func + (lhs: LayoutAnchor, rhs: LayoutAnchor) -> LayoutExpression`
  anchor + anchor

- `func + (lhs: LayoutExpression, rhs: Double) -> LayoutExpression`
  expression + constant

- `func + (lhs: LayoutExpression, rhs: LayoutAnchor) -> LayoutExpression`
  expression + anchor

- `func + (lhs: LayoutExpression, rhs: LayoutExpression) -> LayoutExpression`
  expression + expression

- `func - (variable: Variable) -> Term`

- `func - (term: Term) -> Term`

- `func - (expr: Expression) -> Expression`

- `func - (lhs: Variable, rhs: Variable) -> Expression`

- `func - (lhs: Variable, rhs: Double) -> Expression`

- `func - (lhs: Double, rhs: Variable) -> Expression`

- `func - (lhs: Term, rhs: Term) -> Expression`

- `func - (lhs: Term, rhs: Double) -> Expression`

- `func - (lhs: Expression, rhs: Term) -> Expression`

- `func - (lhs: Expression, rhs: Variable) -> Expression`

- `func - (lhs: Expression, rhs: Double) -> Expression`

- `func - (lhs: Expression, rhs: Expression) -> Expression`

- `func - (lhs: LayoutAnchor, rhs: Double) -> LayoutExpression`
  anchor - constant

- `func - (lhs: LayoutAnchor, rhs: LayoutAnchor) -> LayoutExpression`
  anchor - anchor

- `func - (lhs: LayoutExpression, rhs: Double) -> LayoutExpression`
  expression - constant

- `func - (lhs: LayoutExpression, rhs: LayoutAnchor) -> LayoutExpression`
  expression - anchor

- `func - (lhs: LayoutExpression, rhs: LayoutExpression) -> LayoutExpression`
  expression - expression

- `func / (lhs: Variable, rhs: Double) -> Term`

- `func <= (lhs: Expression, rhs: Expression) -> Constraint`

- `func <= (lhs: Variable, rhs: Double) -> Constraint`

- `func <= (lhs: Double, rhs: Variable) -> Constraint`

- `func <= (lhs: Variable, rhs: Variable) -> Constraint`

- `func <= (lhs: Expression, rhs: Double) -> Constraint`

- `func <= (lhs: Double, rhs: Expression) -> Constraint`

- `func <= (lhs: Expression, rhs: Variable) -> Constraint`

- `func <= (lhs: Variable, rhs: Expression) -> Constraint`

- `func <= (lhs: Variable, rhs: Term) -> Constraint`

- `func <= (lhs: Term, rhs: Variable) -> Constraint`

- `func <= (lhs: Term, rhs: Term) -> Constraint`

- `func <= (lhs: Term, rhs: Double) -> Constraint`

- `func <= (lhs: Expression, rhs: Term) -> Constraint`

- `func <= (lhs: Term, rhs: Expression) -> Constraint`

- `func <= (lhs: LayoutAnchor, rhs: LayoutAnchor) -> LayoutConstraint`
  anchor <= anchor

- `func <= (lhs: LayoutAnchor, rhs: LayoutExpression) -> LayoutConstraint`
  anchor <= expression

- `func <= (lhs: LayoutAnchor, rhs: Double) -> LayoutConstraint`
  anchor <= constant

- `func == (lhs: Expression, rhs: Expression) -> Constraint`

- `func == (lhs: Variable, rhs: Double) -> Constraint`

- `func == (lhs: Double, rhs: Variable) -> Constraint`

- `func == (lhs: Variable, rhs: Variable) -> Constraint`

- `func == (lhs: Expression, rhs: Double) -> Constraint`

- `func == (lhs: Double, rhs: Expression) -> Constraint`

- `func == (lhs: Expression, rhs: Variable) -> Constraint`

- `func == (lhs: Variable, rhs: Expression) -> Constraint`

- `func == (lhs: Variable, rhs: Term) -> Constraint`

- `func == (lhs: Term, rhs: Variable) -> Constraint`

- `func == (lhs: Term, rhs: Term) -> Constraint`

- `func == (lhs: Term, rhs: Double) -> Constraint`

- `func == (lhs: Double, rhs: Term) -> Constraint`

- `func == (lhs: Expression, rhs: Term) -> Constraint`

- `func == (lhs: Term, rhs: Expression) -> Constraint`

- `func == (lhs: LayoutAnchor, rhs: LayoutAnchor) -> LayoutConstraint`
  anchor == anchor

- `func == (lhs: LayoutAnchor, rhs: LayoutExpression) -> LayoutConstraint`
  anchor == expression

- `func == (lhs: LayoutExpression, rhs: LayoutAnchor) -> LayoutConstraint`
  expression == anchor

- `func == (lhs: LayoutExpression, rhs: LayoutExpression) -> LayoutConstraint`
  expression == expression

- `func == (lhs: LayoutAnchor, rhs: Double) -> LayoutConstraint`
  anchor == constant

- `func == (lhs: LayoutExpression, rhs: Double) -> LayoutConstraint`
  expression == constant

- `func >= (lhs: Expression, rhs: Expression) -> Constraint`

- `func >= (lhs: Variable, rhs: Double) -> Constraint`

- `func >= (lhs: Double, rhs: Variable) -> Constraint`

- `func >= (lhs: Variable, rhs: Variable) -> Constraint`

- `func >= (lhs: Expression, rhs: Double) -> Constraint`

- `func >= (lhs: Double, rhs: Expression) -> Constraint`

- `func >= (lhs: Expression, rhs: Variable) -> Constraint`

- `func >= (lhs: Variable, rhs: Expression) -> Constraint`

- `func >= (lhs: Variable, rhs: Term) -> Constraint`

- `func >= (lhs: Term, rhs: Variable) -> Constraint`

- `func >= (lhs: Term, rhs: Term) -> Constraint`

- `func >= (lhs: Term, rhs: Double) -> Constraint`

- `func >= (lhs: Expression, rhs: Term) -> Constraint`

- `func >= (lhs: Term, rhs: Expression) -> Constraint`

- `func >= (lhs: LayoutAnchor, rhs: LayoutAnchor) -> LayoutConstraint`
  anchor >= anchor

- `func >= (lhs: LayoutAnchor, rhs: LayoutExpression) -> LayoutConstraint`
  anchor >= expression

- `func >= (lhs: LayoutAnchor, rhs: Double) -> LayoutConstraint`
  anchor >= constant

- `func | (lhs: Constraint, rhs: Strength) -> Constraint`

- `func | (lhs: Strength, rhs: Constraint) -> Constraint`

