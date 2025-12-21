"""Configuration for KiwiWrapper.h generation.

Defines convenience APIs and accessor mappings that the generator
combines with parsed kiwi/ headers to produce KiwiWrapper.h.
"""

# Relational operators: key → (C++ enum value, display symbol)
OPERATORS = {
    "eq": {"enum": "OP_EQ", "symbol": "=="},
    "ge": {"enum": "OP_GE", "symbol": ">="},
    "le": {"enum": "OP_LE", "symbol": "<="},
}

OPERATOR_ORDER = ("eq", "ge", "le")

# Return-by-value accessors for const-ref methods Swift can't handle.
# Each entry generates one inline free function in kiwi_swift namespace.
ACCESSORS = (
    {
        "class_name": "Variable",
        "method": "name",
        "return_type": "std::string",
        "param_name": "var",
        "func_name": "getVariableName",
        "section_comment": (
            "// Return-by-value accessors for methods that return"
            " const refs (blocked by Swift safety)"
        ),
        "inline_comment": "// copies the string",
    },
    {
        "class_name": "Term",
        "method": "variable",
        "return_type": "kiwi::Variable",
        "param_name": "term",
        "func_name": "getTermVariable",
        "section_comment": "// Term accessors",
        "inline_comment": (
            "// copies the Variable"
            " (lightweight, uses shared_ptr internally)"
        ),
    },
    {
        "class_name": "Expression",
        "method": "terms",
        "return_type": "std::vector<kiwi::Term>",
        "param_name": "expr",
        "func_name": "getExpressionTerms",
        "section_comment": "// Expression accessors",
        "inline_comment": "// copies the vector",
    },
    {
        "class_name": "Constraint",
        "method": "expression",
        "return_type": "kiwi::Expression",
        "param_name": "constraint",
        "func_name": "getConstraintExpression",
        "section_comment": "// Constraint accessors",
        "inline_comment": "// copies the Expression",
    },
)

# Constraint builder patterns, grouped into sections.
# Each pattern × each operator → one static method on ConstraintBuilder.
# "wrap_after": list of param indices after which to insert a line break
#               (indices into the FULL param list including the appended strength param).
CONSTRAINT_BUILDER_SECTIONS = (
    {
        "header": "Single variable constraints",
        "patterns": (
            {
                "description": "Variable {op} constant",
                "params": (("const kiwi::Variable&", "var"), ("double", "constant")),
                "terms": ("kiwi::Term(var)",),
                "constant_expr": "-constant",
                "methods": {"eq": "equalTo", "ge": "greaterOrEqual", "le": "lessOrEqual"},
            },
        ),
    },
    {
        "header": "Two variable constraints",
        "patterns": (
            {
                "description": "var1 {op} var2",
                "params": (
                    ("const kiwi::Variable&", "var1"),
                    ("const kiwi::Variable&", "var2"),
                ),
                "terms": ("kiwi::Term(var1, 1.0)", "kiwi::Term(var2, -1.0)"),
                "constant_expr": "0.0",
                "methods": {"eq": "equal", "ge": "greaterOrEqualVar", "le": "lessOrEqualVar"},
            },
            {
                "description": "var1 {op} var2 + offset",
                "params": (
                    ("const kiwi::Variable&", "var1"),
                    ("const kiwi::Variable&", "var2"),
                    ("double", "offset"),
                ),
                "terms": ("kiwi::Term(var1, 1.0)", "kiwi::Term(var2, -1.0)"),
                "constant_expr": "-offset",
                "methods": {
                    "eq": "equalWithOffset",
                    "ge": "greaterOrEqualWithOffset",
                    "le": "lessOrEqualWithOffset",
                },
            },
        ),
    },
    {
        "header": "Sum constraints",
        "patterns": (
            {
                "description": "var1 + var2 {op} constant",
                "params": (
                    ("const kiwi::Variable&", "var1"),
                    ("const kiwi::Variable&", "var2"),
                    ("double", "constant"),
                ),
                "terms": ("kiwi::Term(var1, 1.0)", "kiwi::Term(var2, 1.0)"),
                "constant_expr": "-constant",
                "methods": {"eq": "sumEqual", "ge": "sumGreaterOrEqual", "le": "sumLessOrEqual"},
            },
        ),
    },
    {
        "header": "Linear combination constraints",
        "patterns": (
            {
                "description": "coef1*var1 + coef2*var2 {op} constant",
                "params": (
                    ("const kiwi::Variable&", "var1"),
                    ("double", "coef1"),
                    ("const kiwi::Variable&", "var2"),
                    ("double", "coef2"),
                    ("double", "constant"),
                ),
                "terms": ("kiwi::Term(var1, coef1)", "kiwi::Term(var2, coef2)"),
                "constant_expr": "-constant",
                "wrap_after": (1, 3),
                "methods": {
                    "eq": "linearEqual",
                    "ge": "linearGreaterOrEqual",
                    "le": "linearLessOrEqual",
                },
            },
        ),
    },
)

# Solver methods intentionally not wrapped (std::ostream doesn't interop with Swift).
SKIP_METHODS = frozenset({"dump", "dumps"})

# Strength functions intentionally not wrapped.
SKIP_STRENGTH_FUNCTIONS = frozenset({"clip"})
