import Foundation

/// A layout anchor representing a single constraint variable (left, top, width, etc.)
/// Use operators to build constraints: `box.left == other.right + 10`
public struct LayoutAnchor: @unchecked Sendable {
    internal let variable: Variable

    internal init(_ variable: Variable) {
        self.variable = variable
    }

    /// Current solved value
    public var value: Double {
        variable.value
    }
}

/// An expression combining anchors and constants: `anchor + 10` or `anchor * 0.5`
public struct LayoutExpression: @unchecked Sendable {
    internal let expression: Expression

    internal init(_ expression: Expression) {
        self.expression = expression
    }

    internal init(_ variable: Variable) {
        self.expression = Expression(variable)
    }

    internal init(_ constant: Double) {
        self.expression = Expression(constant)
    }
}

/// A constraint between layout anchors/expressions.
/// Created using operators like `==`, `<=`, `>=`
public struct LayoutConstraint: @unchecked Sendable {
    internal let constraint: Constraint

    internal init(_ constraint: Constraint) {
        self.constraint = constraint
    }
}

// MARK: - LayoutAnchor Operators

/// anchor + constant
public func + (lhs: LayoutAnchor, rhs: Double) -> LayoutExpression {
    LayoutExpression(Expression(lhs.variable) + rhs)
}

/// constant + anchor
public func + (lhs: Double, rhs: LayoutAnchor) -> LayoutExpression {
    LayoutExpression(Expression(rhs.variable) + lhs)
}

/// anchor - constant
public func - (lhs: LayoutAnchor, rhs: Double) -> LayoutExpression {
    LayoutExpression(Expression(lhs.variable) - rhs)
}

/// anchor * constant
public func * (lhs: LayoutAnchor, rhs: Double) -> LayoutExpression {
    let term = lhs.variable * rhs  // Variable * Double -> Term
    return LayoutExpression(Expression([term]))
}

/// constant * anchor
public func * (lhs: Double, rhs: LayoutAnchor) -> LayoutExpression {
    let term = rhs.variable * lhs  // Variable * Double -> Term
    return LayoutExpression(Expression([term]))
}

/// anchor + anchor
public func + (lhs: LayoutAnchor, rhs: LayoutAnchor) -> LayoutExpression {
    LayoutExpression(Expression(lhs.variable) + rhs.variable)
}

/// anchor - anchor
public func - (lhs: LayoutAnchor, rhs: LayoutAnchor) -> LayoutExpression {
    LayoutExpression(Expression(lhs.variable) - rhs.variable)
}

// MARK: - LayoutExpression Operators

/// expression + constant
public func + (lhs: LayoutExpression, rhs: Double) -> LayoutExpression {
    LayoutExpression(lhs.expression + rhs)
}

/// expression - constant
public func - (lhs: LayoutExpression, rhs: Double) -> LayoutExpression {
    LayoutExpression(lhs.expression - rhs)
}

/// expression * constant
public func * (lhs: LayoutExpression, rhs: Double) -> LayoutExpression {
    // Scale each term's coefficient and the constant
    let scaledTerms = lhs.expression.terms.map { Term($0.variable, coefficient: $0.coefficient * rhs) }
    let scaledConstant = lhs.expression.constant * rhs
    return LayoutExpression(Expression(scaledTerms, constant: scaledConstant))
}

/// expression + anchor
public func + (lhs: LayoutExpression, rhs: LayoutAnchor) -> LayoutExpression {
    LayoutExpression(lhs.expression + rhs.variable)
}

/// expression - anchor
public func - (lhs: LayoutExpression, rhs: LayoutAnchor) -> LayoutExpression {
    LayoutExpression(lhs.expression - rhs.variable)
}

/// expression + expression
public func + (lhs: LayoutExpression, rhs: LayoutExpression) -> LayoutExpression {
    LayoutExpression(lhs.expression + rhs.expression)
}

/// expression - expression
public func - (lhs: LayoutExpression, rhs: LayoutExpression) -> LayoutExpression {
    LayoutExpression(lhs.expression - rhs.expression)
}

// MARK: - Constraint Creation (==)

/// anchor == anchor
public func == (lhs: LayoutAnchor, rhs: LayoutAnchor) -> LayoutConstraint {
    LayoutConstraint(lhs.variable == rhs.variable)
}

/// anchor == expression
public func == (lhs: LayoutAnchor, rhs: LayoutExpression) -> LayoutConstraint {
    LayoutConstraint(lhs.variable == rhs.expression)
}

/// expression == anchor
public func == (lhs: LayoutExpression, rhs: LayoutAnchor) -> LayoutConstraint {
    LayoutConstraint(lhs.expression == rhs.variable)
}

/// expression == expression
public func == (lhs: LayoutExpression, rhs: LayoutExpression) -> LayoutConstraint {
    LayoutConstraint(lhs.expression == rhs.expression)
}

/// anchor == constant
public func == (lhs: LayoutAnchor, rhs: Double) -> LayoutConstraint {
    LayoutConstraint(lhs.variable == rhs)
}

/// expression == constant
public func == (lhs: LayoutExpression, rhs: Double) -> LayoutConstraint {
    LayoutConstraint(lhs.expression == rhs)
}

// MARK: - Constraint Creation (<=)

/// anchor <= anchor
public func <= (lhs: LayoutAnchor, rhs: LayoutAnchor) -> LayoutConstraint {
    LayoutConstraint(lhs.variable <= rhs.variable)
}

/// anchor <= expression
public func <= (lhs: LayoutAnchor, rhs: LayoutExpression) -> LayoutConstraint {
    LayoutConstraint(lhs.variable <= rhs.expression)
}

/// anchor <= constant
public func <= (lhs: LayoutAnchor, rhs: Double) -> LayoutConstraint {
    LayoutConstraint(lhs.variable <= rhs)
}

// MARK: - Constraint Creation (>=)

/// anchor >= anchor
public func >= (lhs: LayoutAnchor, rhs: LayoutAnchor) -> LayoutConstraint {
    LayoutConstraint(lhs.variable >= rhs.variable)
}

/// anchor >= expression
public func >= (lhs: LayoutAnchor, rhs: LayoutExpression) -> LayoutConstraint {
    LayoutConstraint(lhs.variable >= rhs.expression)
}

/// anchor >= constant
public func >= (lhs: LayoutAnchor, rhs: Double) -> LayoutConstraint {
    LayoutConstraint(lhs.variable >= rhs)
}
