import Foundation

/// Manages constraint-based layout for a collection of LayoutBoxes.
///
/// Example:
/// ```swift
/// let solver = LayoutSolver()
/// let header = LayoutBox("header")
/// let content = LayoutBox("content")
///
/// solver.addBox(header)
/// solver.addBox(content)
///
/// solver.addConstraints([
///     header.top == solver.container.top + 20,
///     header.left == solver.container.left + 20,
///     header.right == solver.container.right - 20,
///     header.height == 80,
///
///     content.top == header.bottom + 10,
///     content.pinHorizontal(to: header),
///     content.bottom == solver.container.bottom - 20,
/// ])
///
/// solver.setContainerSize(width: 800, height: 600)
/// solver.solve()
///
/// print(header.frame)  // CGRect with solved values
/// ```
public final class LayoutSolver {
    private let solver: Solver
    private var boxes: [LayoutBox] = []
    private var userConstraints: [Constraint] = []

    /// The root container box - set its size to define the layout bounds
    public let container: LayoutBox

    public init() {
        self.solver = Solver()
        self.container = LayoutBox("container")

        // Add container's internal constraints
        do {
            for constraint in container.internalConstraints {
                try solver.addConstraint(constraint)
            }
        } catch {
            print("LayoutSolver: Failed to add container constraints: \(error)")
        }
    }

    /// Set the container size (call this when bounds change)
    public func setContainerSize(width: Double, height: Double) {
        do {
            // Add as edit variables so we can update them
            if !solver.hasEditVariable(container._left) {
                try solver.addEditVariable(container._left, strength: .strong)
                try solver.addEditVariable(container._top, strength: .strong)
                try solver.addEditVariable(container._width, strength: .strong)
                try solver.addEditVariable(container._height, strength: .strong)
            }

            try solver.suggestValue(container._left, value: 0)
            try solver.suggestValue(container._top, value: 0)
            try solver.suggestValue(container._width, value: width)
            try solver.suggestValue(container._height, value: height)

            solver.updateVariables()
        } catch {
            print("LayoutSolver: Failed to set container size: \(error)")
        }
    }

    /// Add a box to be managed by this solver
    @discardableResult
    public func addBox(_ box: LayoutBox) -> LayoutBox {
        guard !boxes.contains(where: { $0 === box }) else { return box }

        boxes.append(box)

        // Add the box's internal constraints
        do {
            for constraint in box.internalConstraints {
                try solver.addConstraint(constraint)
            }
        } catch {
            print("LayoutSolver: Failed to add box '\(box.name)' internal constraints: \(error)")
        }

        return box
    }

    /// Add a single constraint
    public func addConstraint(_ constraint: LayoutConstraint) {
        userConstraints.append(constraint.constraint)
        do {
            try solver.addConstraint(constraint.constraint)
        } catch {
            print("LayoutSolver: Failed to add constraint: \(error)")
        }
    }

    /// Add multiple constraints
    public func addConstraints(_ constraints: [LayoutConstraint]) {
        for constraint in constraints {
            addConstraint(constraint)
        }
    }

    /// Update all variables after constraint changes
    public func solve() {
        solver.updateVariables()
    }

    /// Reset the solver and remove all boxes and constraints
    public func reset() {
        solver.reset()
        boxes.removeAll()
        userConstraints.removeAll()

        // Re-add container constraints
        do {
            for constraint in container.internalConstraints {
                try solver.addConstraint(constraint)
            }
        } catch {
            print("LayoutSolver: Failed to re-add container constraints: \(error)")
        }
    }

    /// Get all managed boxes
    public var allBoxes: [LayoutBox] {
        boxes
    }
}

// MARK: - Convenience methods for common layouts

public extension LayoutSolver {
    /// Create a vertical stack of boxes with spacing
    func verticalStack(_ boxes: [LayoutBox], spacing: Double = 0, insets: Double = 0) {
        guard !boxes.isEmpty else { return }

        for box in boxes {
            addBox(box)
        }

        // First box pins to top
        addConstraints([
            boxes[0].top == container.top + insets,
            boxes[0].left == container.left + insets,
            boxes[0].right == container.right - insets,
        ])

        // Each subsequent box below the previous
        for i in 1..<boxes.count {
            addConstraints([
                boxes[i].top == boxes[i-1].bottom + spacing,
                boxes[i].left == container.left + insets,
                boxes[i].right == container.right - insets,
            ])
        }
    }

    /// Create a horizontal stack of boxes with spacing
    func horizontalStack(_ boxes: [LayoutBox], spacing: Double = 0, insets: Double = 0) {
        guard !boxes.isEmpty else { return }

        for box in boxes {
            addBox(box)
        }

        // First box pins to left
        addConstraints([
            boxes[0].left == container.left + insets,
            boxes[0].top == container.top + insets,
            boxes[0].bottom == container.bottom - insets,
        ])

        // Each subsequent box to the right of the previous
        for i in 1..<boxes.count {
            addConstraints([
                boxes[i].left == boxes[i-1].right + spacing,
                boxes[i].top == container.top + insets,
                boxes[i].bottom == container.bottom - insets,
            ])
        }
    }

    /// Distribute boxes evenly in a row (equal widths)
    func distributeHorizontally(_ boxes: [LayoutBox], spacing: Double = 0, insets: Double = 0) {
        guard boxes.count > 1 else {
            if let box = boxes.first {
                addBox(box)
                addConstraints(box.pinEdges(to: container, inset: insets))
            }
            return
        }

        horizontalStack(boxes, spacing: spacing, insets: insets)

        // Make all boxes equal width
        for i in 1..<boxes.count {
            addConstraint(boxes[i].width == boxes[0].width)
        }

        // Last box pins to right
        addConstraint(boxes.last!.right == container.right - insets)
    }

    /// Distribute boxes evenly in a column (equal heights)
    func distributeVertically(_ boxes: [LayoutBox], spacing: Double = 0, insets: Double = 0) {
        guard boxes.count > 1 else {
            if let box = boxes.first {
                addBox(box)
                addConstraints(box.pinEdges(to: container, inset: insets))
            }
            return
        }

        verticalStack(boxes, spacing: spacing, insets: insets)

        // Make all boxes equal height
        for i in 1..<boxes.count {
            addConstraint(boxes[i].height == boxes[0].height)
        }

        // Last box pins to bottom
        addConstraint(boxes.last!.bottom == container.bottom - insets)
    }
}
