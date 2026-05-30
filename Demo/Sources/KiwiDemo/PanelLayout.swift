import KiwiSolver

/// A solved panel rectangle. Origin is top-left, y grows downward.
public struct Panel: Sendable {
    public let name: String
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
}

/// The single source of constraint truth shared by both the terminal and Metal renderers.
///
/// Layout: one tall LEFT panel, and a RIGHT column of three stacked sub-panels.
/// Three draggable dividers drive everything:
///   - `splitX`  : the vertical border between the left panel and the right column
///   - `splitY1` : the horizontal border between right-top and right-middle
///   - `splitY2` : the horizontal border between right-middle and right-bottom
///
/// The container size and the three dividers are Cassowary *edit variables*.
/// Dragging a border is just `suggestValue` on its divider; required minimum-size
/// constraints make the solver clamp the drag automatically.
public final class PanelLayout {
    public enum Divider {
        case splitX, splitY1, splitY2
    }

    /// Minimum panel extents, in the same units the caller solves in (pixels or character cells).
    public struct Minimums: Sendable {
        public var left: Double
        public var right: Double
        public var top: Double
        public var middle: Double
        public var bottom: Double

        public init(left: Double, right: Double, top: Double, middle: Double, bottom: Double) {
            self.left = left
            self.right = right
            self.top = top
            self.middle = middle
            self.bottom = bottom
        }
    }

    public let minimums: Minimums

    private let solver = Solver()

    private let containerWidth = Variable("containerWidth")
    private let containerHeight = Variable("containerHeight")
    private let splitXVariable = Variable("splitX")
    private let splitY1Variable = Variable("splitY1")
    private let splitY2Variable = Variable("splitY2")

    // Cached last-suggested values so the 60fps Metal loop can no-op when nothing changed.
    private var lastSuggestedWidth = Double.nan
    private var lastSuggestedHeight = Double.nan
    private var lastSuggestedSplitX = Double.nan
    private var lastSuggestedSplitY1 = Double.nan
    private var lastSuggestedSplitY2 = Double.nan

    public init(width: Double, height: Double, minimums: Minimums) {
        self.minimums = minimums

        // Container and dividers are all edit variables. The container is .strong so that a
        // divider suggestion (.medium) loses to the container size and gets clamped instead
        // of shrinking the window.
        do {
            try solver.addEditVariable(containerWidth, strength: .strong)
            try solver.addEditVariable(containerHeight, strength: .strong)
            try solver.addEditVariable(splitXVariable, strength: .medium)
            try solver.addEditVariable(splitY1Variable, strength: .medium)
            try solver.addEditVariable(splitY2Variable, strength: .medium)
        } catch {
            print("PanelLayout: failed to add edit variables: \(error)")
        }

        // Required minimum-size / ordering constraints. These win over the medium-strength
        // divider suggestions, so the solver clamps any drag that would violate them.
        let requiredConstraints: [Constraint] = [
            splitXVariable >= minimums.left,
            containerWidth - splitXVariable >= minimums.right,
            splitY1Variable >= minimums.top,
            splitY2Variable - splitY1Variable >= minimums.middle,
            containerHeight - splitY2Variable >= minimums.bottom,
        ]
        for constraint in requiredConstraints {
            do {
                try solver.addConstraint(constraint)
            } catch {
                print("PanelLayout: failed to add constraint: \(error)")
            }
        }

        // Seed sensible defaults: left column 30% wide, the right column split into thirds.
        let leftColumnFraction = 0.3
        resize(width: width, height: height)
        drag(.splitX, to: width * leftColumnFraction)
        drag(.splitY1, to: height / 3.0)
        drag(.splitY2, to: height * 2.0 / 3.0)
    }

    /// Update the container size (call on window / terminal resize). No-op if unchanged.
    public func resize(width: Double, height: Double) {
        guard width != lastSuggestedWidth || height != lastSuggestedHeight else { return }
        lastSuggestedWidth = width
        lastSuggestedHeight = height
        do {
            try solver.suggestValue(containerWidth, value: width)
            try solver.suggestValue(containerHeight, value: height)
        } catch {
            print("PanelLayout: resize failed: \(error)")
        }
        solver.updateVariables()
    }

    /// Drag a divider to an absolute value (clamped by the required minimums). No-op if unchanged.
    public func drag(_ divider: Divider, to value: Double) {
        switch divider {
        case .splitX:
            guard value != lastSuggestedSplitX else { return }
            lastSuggestedSplitX = value
            suggest(splitXVariable, value)
        case .splitY1:
            guard value != lastSuggestedSplitY1 else { return }
            lastSuggestedSplitY1 = value
            suggest(splitY1Variable, value)
        case .splitY2:
            guard value != lastSuggestedSplitY2 else { return }
            lastSuggestedSplitY2 = value
            suggest(splitY2Variable, value)
        }
    }

    /// Nudge a divider by a relative delta (used by the keyboard terminal mode).
    public func nudge(_ divider: Divider, by delta: Double) {
        drag(divider, to: value(of: divider) + delta)
    }

    public func value(of divider: Divider) -> Double {
        switch divider {
        case .splitX: return splitXVariable.value
        case .splitY1: return splitY1Variable.value
        case .splitY2: return splitY2Variable.value
        }
    }

    public var width: Double { containerWidth.value }
    public var height: Double { containerHeight.value }

    /// The four solved panels, in draw order.
    public var panels: [Panel] {
        let width = containerWidth.value
        let height = containerHeight.value
        let splitX = splitXVariable.value
        let splitY1 = splitY1Variable.value
        let splitY2 = splitY2Variable.value
        let rightColumnWidth = width - splitX
        return [
            Panel(name: "left", x: 0, y: 0, width: splitX, height: height),
            Panel(name: "right-top", x: splitX, y: 0, width: rightColumnWidth, height: splitY1),
            Panel(name: "right-mid", x: splitX, y: splitY1, width: rightColumnWidth, height: splitY2 - splitY1),
            Panel(name: "right-bot", x: splitX, y: splitY2, width: rightColumnWidth, height: height - splitY2),
        ]
    }

    /// Hit-test a point (model coordinates, top-left origin) against the dividers.
    /// Returns the nearest divider within `tolerance`, or nil.
    public func dividerHit(x: Double, y: Double, tolerance: Double) -> Divider? {
        let splitX = splitXVariable.value
        let splitY1 = splitY1Variable.value
        let splitY2 = splitY2Variable.value

        // The vertical divider spans the full height.
        if abs(x - splitX) <= tolerance {
            return .splitX
        }
        // The horizontal dividers only exist within the right column.
        if x >= splitX {
            if abs(y - splitY1) <= tolerance { return .splitY1 }
            if abs(y - splitY2) <= tolerance { return .splitY2 }
        }
        return nil
    }

    private func suggest(_ variable: Variable, _ value: Double) {
        do {
            try solver.suggestValue(variable, value: value)
        } catch {
            print("PanelLayout: drag failed: \(error)")
        }
        solver.updateVariables()
    }
}
