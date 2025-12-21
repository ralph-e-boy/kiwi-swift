import KiwiSolver

// Create variables
let x = Variable("x")
let y = Variable("y")

print("Variables: \(x.name), \(y.name)")

// Create solver
let solver = Solver()

do {
    // Add constraints using nice operator syntax
    try solver.addConstraint(x + y == 100)
    try solver.addConstraint(x == 40)

    solver.updateVariables()

    print("After solving: x = \(x.value), y = \(y.value)")
    // Expected: x = 40, y = 60

    // Test with strength modifier
    try solver.addConstraint((y >= 70) | .weak)

    solver.updateVariables()
    print("With weak constraint y >= 70: x = \(x.value), y = \(y.value)")
    // Still x = 40, y = 60 because required constraints take precedence

    // Test error handling
    do {
        try solver.addConstraint(x == 50)  // Conflicts with x == 40
        print("ERROR: Should have thrown!")
    } catch let error as SolverError {
        print("Caught expected error: \(error)")
    }

    // More complex expression
    solver.reset()
    let a = Variable("a")
    let b = Variable("b")
    let c = Variable("c")

    try solver.addConstraint(a + b + c == 100)
    try solver.addConstraint(a == 2 * b)
    try solver.addConstraint(c == b + 10)

    solver.updateVariables()
    print("\nComplex: a=\(a.value), b=\(b.value), c=\(c.value)")
    // a = 2b, c = b + 10, a + b + c = 100
    // 2b + b + (b + 10) = 100 -> 4b = 90 -> b = 22.5
    // a = 45, b = 22.5, c = 32.5

} catch {
    print("Unexpected error: \(error)")
}
