import Foundation
import CoreGraphics

/// A layoutable box with constraint anchors for position and size.
/// Use with LayoutSolver to define constraint-based layouts.
///
/// Example:
/// ```swift
/// let header = LayoutBox("header")
/// let content = LayoutBox("content")
///
/// solver.addConstraints([
///     header.top == solver.container.top + 20,
///     header.left == solver.container.left + 20,
///     header.right == solver.container.right - 20,
///     header.height == 80,
///
///     content.top == header.bottom + 10,
///     content.left == header.left,
///     content.right == header.right,
/// ])
/// ```
public final class LayoutBox: @unchecked Sendable {
    public let name: String

    // Internal variables (not exposed)
    internal let _left: Variable
    internal let _top: Variable
    internal let _width: Variable
    internal let _height: Variable
    internal let _right: Variable
    internal let _bottom: Variable
    internal let _centerX: Variable
    internal let _centerY: Variable

    // Internal constraints linking derived to primary
    internal var internalConstraints: [Constraint] = []

    public init(_ name: String = "box") {
        self.name = name

        // Primary variables
        self._left = Variable("\(name).left")
        self._top = Variable("\(name).top")
        self._width = Variable("\(name).width")
        self._height = Variable("\(name).height")

        // Derived variables
        self._right = Variable("\(name).right")
        self._bottom = Variable("\(name).bottom")
        self._centerX = Variable("\(name).centerX")
        self._centerY = Variable("\(name).centerY")

        // Create internal constraints:
        // right = left + width
        // bottom = top + height
        // centerX = left + width/2
        // centerY = top + height/2
        internalConstraints = [
            _right == _left + _width,
            _bottom == _top + _height,
            _centerX == Expression(_left) + _width * 0.5,
            _centerY == Expression(_top) + _height * 0.5,
        ]
    }

    // MARK: - Public Anchors

    /// Left edge anchor
    public var left: LayoutAnchor { LayoutAnchor(_left) }

    /// Top edge anchor
    public var top: LayoutAnchor { LayoutAnchor(_top) }

    /// Width anchor
    public var width: LayoutAnchor { LayoutAnchor(_width) }

    /// Height anchor
    public var height: LayoutAnchor { LayoutAnchor(_height) }

    /// Right edge anchor (derived: left + width)
    public var right: LayoutAnchor { LayoutAnchor(_right) }

    /// Bottom edge anchor (derived: top + height)
    public var bottom: LayoutAnchor { LayoutAnchor(_bottom) }

    /// Horizontal center anchor (derived: left + width/2)
    public var centerX: LayoutAnchor { LayoutAnchor(_centerX) }

    /// Vertical center anchor (derived: top + height/2)
    public var centerY: LayoutAnchor { LayoutAnchor(_centerY) }

    // MARK: - Computed Properties

    /// The computed frame after solving constraints
    public var frame: CGRect {
        CGRect(
            x: _left.value,
            y: _top.value,
            width: _width.value,
            height: _height.value
        )
    }

    /// Convenience for getting frame as Floats for drawing
    public var floatFrame: (x: Float, y: Float, width: Float, height: Float) {
        (
            x: Float(_left.value),
            y: Float(_top.value),
            width: Float(_width.value),
            height: Float(_height.value)
        )
    }
}

// MARK: - Convenience constraint builders

public extension LayoutBox {
    /// Pin all edges to another box with optional inset
    func pinEdges(to other: LayoutBox, inset: Double = 0) -> [LayoutConstraint] {
        [
            left == other.left + inset,
            top == other.top + inset,
            right == other.right - inset,
            bottom == other.bottom - inset,
        ]
    }

    /// Pin horizontal edges (left and right)
    func pinHorizontal(to other: LayoutBox, inset: Double = 0) -> [LayoutConstraint] {
        [
            left == other.left + inset,
            right == other.right - inset,
        ]
    }

    /// Pin vertical edges (top and bottom)
    func pinVertical(to other: LayoutBox, inset: Double = 0) -> [LayoutConstraint] {
        [
            top == other.top + inset,
            bottom == other.bottom - inset,
        ]
    }

    /// Center within another box
    func center(in other: LayoutBox) -> [LayoutConstraint] {
        [
            centerX == other.centerX,
            centerY == other.centerY,
        ]
    }

    /// Center horizontally within another box
    func centerHorizontally(in other: LayoutBox) -> [LayoutConstraint] {
        [centerX == other.centerX]
    }

    /// Center vertically within another box
    func centerVertically(in other: LayoutBox) -> [LayoutConstraint] {
        [centerY == other.centerY]
    }

    /// Set fixed size
    func size(_ width: Double, _ height: Double) -> [LayoutConstraint] {
        [
            self.width == width,
            self.height == height,
        ]
    }

    /// Set fixed width
    func fixedWidth(_ value: Double) -> LayoutConstraint {
        width == value
    }

    /// Set fixed height
    func fixedHeight(_ value: Double) -> LayoutConstraint {
        height == value
    }

    /// Position below another box with spacing
    func below(_ other: LayoutBox, spacing: Double = 0) -> LayoutConstraint {
        top == other.bottom + spacing
    }

    /// Position above another box with spacing
    func above(_ other: LayoutBox, spacing: Double = 0) -> LayoutConstraint {
        bottom == other.top - spacing
    }

    /// Position to the right of another box with spacing
    func after(_ other: LayoutBox, spacing: Double = 0) -> LayoutConstraint {
        left == other.right + spacing
    }

    /// Position to the left of another box with spacing
    func before(_ other: LayoutBox, spacing: Double = 0) -> LayoutConstraint {
        right == other.left - spacing
    }
}
