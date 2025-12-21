import CxxKiwi

// MARK: - Swift Error Types

public enum SolverError: Error, CustomStringConvertible {
    case unsatisfiableConstraint(String)
    case unknownConstraint(String)
    case duplicateConstraint(String)
    case unknownEditVariable(String)
    case duplicateEditVariable(String)
    case badRequiredStrength(String)
    case internalError(String)

    public var description: String {
        switch self {
        case .unsatisfiableConstraint(let msg): return msg
        case .unknownConstraint(let msg): return msg
        case .duplicateConstraint(let msg): return msg
        case .unknownEditVariable(let msg): return msg
        case .duplicateEditVariable(let msg): return msg
        case .badRequiredStrength(let msg): return msg
        case .internalError(let msg): return msg
        }
    }

    init(from result: kiwi_swift.SolverResult) {
        let msg = String(result.message)
        switch result.error {
        case .UnsatisfiableConstraint: self = .unsatisfiableConstraint(msg)
        case .UnknownConstraint: self = .unknownConstraint(msg)
        case .DuplicateConstraint: self = .duplicateConstraint(msg)
        case .UnknownEditVariable: self = .unknownEditVariable(msg)
        case .DuplicateEditVariable: self = .duplicateEditVariable(msg)
        case .BadRequiredStrength: self = .badRequiredStrength(msg)
        case .InternalError: self = .internalError(msg)
        case .None: self = .internalError("Unknown error")
        @unknown default: self = .internalError("Unknown error")
        }
    }
}

// MARK: - Strength

public enum Strength {
    case required
    case strong
    case medium
    case weak
    case custom(Double)

    public var rawValue: Double {
        switch self {
        case .required: return kiwi_swift.Strength.required()
        case .strong: return kiwi_swift.Strength.strong()
        case .medium: return kiwi_swift.Strength.medium()
        case .weak: return kiwi_swift.Strength.weak()
        case .custom(let value): return value
        }
    }
}

// MARK: - Variable

public final class Variable {
    let cxxVar: kiwi.Variable

    public init(_ name: String) {
        self.cxxVar = kiwi.Variable(std.string(name), nil)
    }

    public var name: String {
        String(kiwi_swift.getVariableName(cxxVar))
    }

    public var value: Double {
        cxxVar.value()
    }
}

// MARK: - Term (coefficient * variable)

public struct Term {
    public let variable: Variable
    public let coefficient: Double

    public init(_ variable: Variable, coefficient: Double = 1.0) {
        self.variable = variable
        self.coefficient = coefficient
    }
}

// MARK: - Expression (sum of terms + constant)

public struct Expression {
    public var terms: [Term]
    public var constant: Double

    public init(_ terms: [Term] = [], constant: Double = 0) {
        self.terms = terms
        self.constant = constant
    }

    public init(_ variable: Variable) {
        self.terms = [Term(variable)]
        self.constant = 0
    }

    public init(_ term: Term) {
        self.terms = [term]
        self.constant = 0
    }

    public init(_ constant: Double) {
        self.terms = []
        self.constant = constant
    }
}

// MARK: - Constraint

public struct Constraint {
    let cxxConstraint: kiwi.Constraint

    init(_ cxxConstraint: kiwi.Constraint) {
        self.cxxConstraint = cxxConstraint
    }

    init(expression: Expression, op: kiwi.RelationalOperator, strength: Strength) {
        var builder = kiwi_swift.ExpressionBuilder()
        for term in expression.terms {
            builder.addTerm(term.variable.cxxVar, term.coefficient)
        }
        builder.setConstant(expression.constant)
        self.cxxConstraint = builder.buildConstraint(op, strength.rawValue)
    }

    public func with(strength: Strength) -> Constraint {
        Constraint(kiwi.Constraint(cxxConstraint, strength.rawValue))
    }

    public var op: RelationalOperator {
        switch cxxConstraint.op() {
        case kiwi.OP_EQ: return .equal
        case kiwi.OP_LE: return .lessOrEqual
        case kiwi.OP_GE: return .greaterOrEqual
        default: return .equal
        }
    }

    public var strength: Double {
        cxxConstraint.strength()
    }

    public var violated: Bool {
        cxxConstraint.violated()
    }
}

public enum RelationalOperator {
    case equal
    case lessOrEqual
    case greaterOrEqual
}

// MARK: - Solver

public final class Solver {
    private var cxxSolver: kiwi_swift.Solver

    public init() {
        self.cxxSolver = kiwi_swift.Solver()
    }

    public func addConstraint(_ constraint: Constraint) throws {
        let result = cxxSolver.addConstraint(constraint.cxxConstraint)
        if !result.ok() {
            throw SolverError(from: result)
        }
    }

    public func removeConstraint(_ constraint: Constraint) throws {
        let result = cxxSolver.removeConstraint(constraint.cxxConstraint)
        if !result.ok() {
            throw SolverError(from: result)
        }
    }

    public func hasConstraint(_ constraint: Constraint) -> Bool {
        cxxSolver.hasConstraint(constraint.cxxConstraint)
    }

    public func addEditVariable(_ variable: Variable, strength: Strength) throws {
        let result = cxxSolver.addEditVariable(variable.cxxVar, strength.rawValue)
        if !result.ok() {
            throw SolverError(from: result)
        }
    }

    public func removeEditVariable(_ variable: Variable) throws {
        let result = cxxSolver.removeEditVariable(variable.cxxVar)
        if !result.ok() {
            throw SolverError(from: result)
        }
    }

    public func hasEditVariable(_ variable: Variable) -> Bool {
        cxxSolver.hasEditVariable(variable.cxxVar)
    }

    public func suggestValue(_ variable: Variable, value: Double) throws {
        let result = cxxSolver.suggestValue(variable.cxxVar, value)
        if !result.ok() {
            throw SolverError(from: result)
        }
    }

    public func updateVariables() {
        cxxSolver.updateVariables()
    }

    public func reset() {
        cxxSolver.reset()
    }
}

// MARK: - Operators for building expressions

// Variable * coefficient
public func * (lhs: Variable, rhs: Double) -> Term {
    Term(lhs, coefficient: rhs)
}

public func * (lhs: Double, rhs: Variable) -> Term {
    Term(rhs, coefficient: lhs)
}

// Variable / coefficient
public func / (lhs: Variable, rhs: Double) -> Term {
    Term(lhs, coefficient: 1.0 / rhs)
}

// Term * coefficient
public func * (lhs: Term, rhs: Double) -> Term {
    Term(lhs.variable, coefficient: lhs.coefficient * rhs)
}

public func * (lhs: Double, rhs: Term) -> Term {
    Term(rhs.variable, coefficient: rhs.coefficient * lhs)
}

// Negation
public prefix func - (variable: Variable) -> Term {
    Term(variable, coefficient: -1.0)
}

public prefix func - (term: Term) -> Term {
    Term(term.variable, coefficient: -term.coefficient)
}

public prefix func - (expr: Expression) -> Expression {
    Expression(expr.terms.map { -$0 }, constant: -expr.constant)
}

// Variable + Variable
public func + (lhs: Variable, rhs: Variable) -> Expression {
    Expression([Term(lhs), Term(rhs)])
}

// Variable - Variable
public func - (lhs: Variable, rhs: Variable) -> Expression {
    Expression([Term(lhs), Term(rhs, coefficient: -1.0)])
}

// Variable + constant
public func + (lhs: Variable, rhs: Double) -> Expression {
    Expression([Term(lhs)], constant: rhs)
}

public func + (lhs: Double, rhs: Variable) -> Expression {
    Expression([Term(rhs)], constant: lhs)
}

// Variable - constant
public func - (lhs: Variable, rhs: Double) -> Expression {
    Expression([Term(lhs)], constant: -rhs)
}

public func - (lhs: Double, rhs: Variable) -> Expression {
    Expression([Term(rhs, coefficient: -1.0)], constant: lhs)
}

// Term + Term
public func + (lhs: Term, rhs: Term) -> Expression {
    Expression([lhs, rhs])
}

// Term - Term
public func - (lhs: Term, rhs: Term) -> Expression {
    Expression([lhs, -rhs])
}

// Term + constant
public func + (lhs: Term, rhs: Double) -> Expression {
    Expression([lhs], constant: rhs)
}

public func + (lhs: Double, rhs: Term) -> Expression {
    Expression([rhs], constant: lhs)
}

// Term - constant
public func - (lhs: Term, rhs: Double) -> Expression {
    Expression([lhs], constant: -rhs)
}

// Expression + Term
public func + (lhs: Expression, rhs: Term) -> Expression {
    Expression(lhs.terms + [rhs], constant: lhs.constant)
}

public func + (lhs: Term, rhs: Expression) -> Expression {
    Expression([lhs] + rhs.terms, constant: rhs.constant)
}

// Expression - Term
public func - (lhs: Expression, rhs: Term) -> Expression {
    Expression(lhs.terms + [-rhs], constant: lhs.constant)
}

// Expression + Variable
public func + (lhs: Expression, rhs: Variable) -> Expression {
    lhs + Term(rhs)
}

public func + (lhs: Variable, rhs: Expression) -> Expression {
    Term(lhs) + rhs
}

// Expression - Variable
public func - (lhs: Expression, rhs: Variable) -> Expression {
    lhs - Term(rhs)
}

// Expression + constant
public func + (lhs: Expression, rhs: Double) -> Expression {
    Expression(lhs.terms, constant: lhs.constant + rhs)
}

public func + (lhs: Double, rhs: Expression) -> Expression {
    Expression(rhs.terms, constant: rhs.constant + lhs)
}

// Expression - constant
public func - (lhs: Expression, rhs: Double) -> Expression {
    Expression(lhs.terms, constant: lhs.constant - rhs)
}

// Expression + Expression
public func + (lhs: Expression, rhs: Expression) -> Expression {
    Expression(lhs.terms + rhs.terms, constant: lhs.constant + rhs.constant)
}

// Expression - Expression
public func - (lhs: Expression, rhs: Expression) -> Expression {
    lhs + (-rhs)
}

// MARK: - Constraint operators

// Helper to create normalized expression (expr - rhs = 0 form)
private func makeConstraint(_ lhs: Expression, _ op: kiwi.RelationalOperator, _ rhs: Expression, strength: Strength = .required) -> Constraint {
    let combined = lhs - rhs
    return Constraint(expression: combined, op: op, strength: strength)
}

// Expression == Expression
public func == (lhs: Expression, rhs: Expression) -> Constraint {
    makeConstraint(lhs, kiwi.OP_EQ, rhs)
}

// Expression <= Expression
public func <= (lhs: Expression, rhs: Expression) -> Constraint {
    makeConstraint(lhs, kiwi.OP_LE, rhs)
}

// Expression >= Expression
public func >= (lhs: Expression, rhs: Expression) -> Constraint {
    makeConstraint(lhs, kiwi.OP_GE, rhs)
}

// Variable == constant
public func == (lhs: Variable, rhs: Double) -> Constraint {
    Expression(lhs) == Expression(rhs)
}

public func == (lhs: Double, rhs: Variable) -> Constraint {
    Expression(lhs) == Expression(rhs)
}

// Variable <= constant
public func <= (lhs: Variable, rhs: Double) -> Constraint {
    Expression(lhs) <= Expression(rhs)
}

public func <= (lhs: Double, rhs: Variable) -> Constraint {
    Expression(lhs) <= Expression(rhs)
}

// Variable >= constant
public func >= (lhs: Variable, rhs: Double) -> Constraint {
    Expression(lhs) >= Expression(rhs)
}

public func >= (lhs: Double, rhs: Variable) -> Constraint {
    Expression(lhs) >= Expression(rhs)
}

// Variable == Variable
public func == (lhs: Variable, rhs: Variable) -> Constraint {
    Expression(lhs) == Expression(rhs)
}

// Variable <= Variable
public func <= (lhs: Variable, rhs: Variable) -> Constraint {
    Expression(lhs) <= Expression(rhs)
}

// Variable >= Variable
public func >= (lhs: Variable, rhs: Variable) -> Constraint {
    Expression(lhs) >= Expression(rhs)
}

// Expression == constant
public func == (lhs: Expression, rhs: Double) -> Constraint {
    lhs == Expression(rhs)
}

public func == (lhs: Double, rhs: Expression) -> Constraint {
    Expression(lhs) == rhs
}

// Expression <= constant
public func <= (lhs: Expression, rhs: Double) -> Constraint {
    lhs <= Expression(rhs)
}

public func <= (lhs: Double, rhs: Expression) -> Constraint {
    Expression(lhs) <= rhs
}

// Expression >= constant
public func >= (lhs: Expression, rhs: Double) -> Constraint {
    lhs >= Expression(rhs)
}

public func >= (lhs: Double, rhs: Expression) -> Constraint {
    Expression(lhs) >= rhs
}

// Expression == Variable
public func == (lhs: Expression, rhs: Variable) -> Constraint {
    lhs == Expression(rhs)
}

public func == (lhs: Variable, rhs: Expression) -> Constraint {
    Expression(lhs) == rhs
}

// Expression <= Variable
public func <= (lhs: Expression, rhs: Variable) -> Constraint {
    lhs <= Expression(rhs)
}

public func <= (lhs: Variable, rhs: Expression) -> Constraint {
    Expression(lhs) <= rhs
}

// Expression >= Variable
public func >= (lhs: Expression, rhs: Variable) -> Constraint {
    lhs >= Expression(rhs)
}

public func >= (lhs: Variable, rhs: Expression) -> Constraint {
    Expression(lhs) >= rhs
}

// Term constraint operators
public func == (lhs: Variable, rhs: Term) -> Constraint {
    Expression(lhs) == Expression(rhs)
}

public func == (lhs: Term, rhs: Variable) -> Constraint {
    Expression(lhs) == Expression(rhs)
}

public func == (lhs: Term, rhs: Term) -> Constraint {
    Expression(lhs) == Expression(rhs)
}

public func == (lhs: Term, rhs: Double) -> Constraint {
    Expression(lhs) == Expression(rhs)
}

public func == (lhs: Double, rhs: Term) -> Constraint {
    Expression(lhs) == Expression(rhs)
}

public func <= (lhs: Variable, rhs: Term) -> Constraint {
    Expression(lhs) <= Expression(rhs)
}

public func <= (lhs: Term, rhs: Variable) -> Constraint {
    Expression(lhs) <= Expression(rhs)
}

public func <= (lhs: Term, rhs: Term) -> Constraint {
    Expression(lhs) <= Expression(rhs)
}

public func <= (lhs: Term, rhs: Double) -> Constraint {
    Expression(lhs) <= Expression(rhs)
}

public func >= (lhs: Variable, rhs: Term) -> Constraint {
    Expression(lhs) >= Expression(rhs)
}

public func >= (lhs: Term, rhs: Variable) -> Constraint {
    Expression(lhs) >= Expression(rhs)
}

public func >= (lhs: Term, rhs: Term) -> Constraint {
    Expression(lhs) >= Expression(rhs)
}

public func >= (lhs: Term, rhs: Double) -> Constraint {
    Expression(lhs) >= Expression(rhs)
}

// Expression with Term
public func == (lhs: Expression, rhs: Term) -> Constraint {
    lhs == Expression(rhs)
}

public func == (lhs: Term, rhs: Expression) -> Constraint {
    Expression(lhs) == rhs
}

public func <= (lhs: Expression, rhs: Term) -> Constraint {
    lhs <= Expression(rhs)
}

public func <= (lhs: Term, rhs: Expression) -> Constraint {
    Expression(lhs) <= rhs
}

public func >= (lhs: Expression, rhs: Term) -> Constraint {
    lhs >= Expression(rhs)
}

public func >= (lhs: Term, rhs: Expression) -> Constraint {
    Expression(lhs) >= rhs
}

// MARK: - Strength modifier (using | operator like kiwi)

public func | (lhs: Constraint, rhs: Strength) -> Constraint {
    lhs.with(strength: rhs)
}

public func | (lhs: Strength, rhs: Constraint) -> Constraint {
    rhs.with(strength: lhs)
}
