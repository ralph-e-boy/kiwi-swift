import Foundation
#if canImport(Glibc)
import Glibc
#endif

// MARK: - Entry

func runTerminalDemo() {
    if isatty(STDIN_FILENO) != 0 && isatty(STDOUT_FILENO) != 0 {
        InteractiveTerminal().run()
    } else {
        runSweep()
    }
}

// Minimum panel extents for the character-cell layouts, in cells.
private let terminalMinimums = PanelLayout.Minimums(left: 12, right: 16, top: 3, middle: 3, bottom: 3)
private let statusLineCount = 1

// MARK: - Character-grid renderer (shared by interactive + sweep)

private struct CharacterGrid {
    let columns: Int
    let rows: Int
    private var cells: [Character]

    init(columns: Int, rows: Int) {
        self.columns = max(columns, 1)
        self.rows = max(rows, 1)
        self.cells = Array(repeating: " ", count: self.columns * self.rows)
    }

    mutating func put(_ character: Character, column: Int, row: Int) {
        guard column >= 0, column < columns, row >= 0, row < rows else { return }
        cells[row * columns + column] = character
    }

    func character(atColumn column: Int, row: Int) -> Character {
        guard column >= 0, column < columns, row >= 0, row < rows else { return " " }
        return cells[row * columns + column]
    }

    mutating func write(_ string: String, column: Int, row: Int) {
        var currentColumn = column
        for character in string {
            put(character, column: currentColumn, row: row)
            currentColumn += 1
        }
    }

    func render() -> String {
        var output = ""
        output.reserveCapacity((columns + 1) * rows)
        for row in 0..<rows {
            let start = row * columns
            output += String(cells[start..<start + columns])
            if row < rows - 1 { output += "\n" }
        }
        return output
    }
}

/// Draw the four panels onto a character grid. `highlightedDivider` outlines the active divider.
private func drawLayout(_ layout: PanelLayout, highlightedDivider: PanelLayout.Divider?) -> String {
    let columns = Int(layout.width.rounded())
    let rows = Int(layout.height.rounded())
    var grid = CharacterGrid(columns: columns, rows: rows)

    let panels = layout.panels

    // Pass 1: borders for each panel.
    for panel in panels {
        let left = Int(panel.x.rounded())
        let top = Int(panel.y.rounded())
        let right = Int((panel.x + panel.width).rounded()) - 1
        let bottom = Int((panel.y + panel.height).rounded()) - 1
        guard right > left, bottom > top else { continue }
        strokeBox(&grid, left: left, top: top, right: right, bottom: bottom)
    }

    // Pass 2: labels centered in each panel.
    for panel in panels {
        let centerColumn = Int((panel.x + panel.width / 2).rounded())
        let centerRow = Int((panel.y + panel.height / 2).rounded())
        let sizeLabel = "\(Int(panel.width.rounded()))x\(Int(panel.height.rounded()))"
        grid.write(panel.name, column: centerColumn - panel.name.count / 2, row: centerRow)
        grid.write(sizeLabel, column: centerColumn - sizeLabel.count / 2, row: centerRow + 1)
    }

    // Pass 3: highlight the active divider with a doubled line.
    if let divider = highlightedDivider {
        highlightDivider(&grid, layout: layout, divider: divider)
    }

    return grid.render()
}

private func strokeBox(_ grid: inout CharacterGrid, left: Int, top: Int, right: Int, bottom: Int) {
    for column in (left + 1)..<right {
        mergeJoint(&grid, "─", column: column, row: top)
        mergeJoint(&grid, "─", column: column, row: bottom)
    }
    for row in (top + 1)..<bottom {
        mergeJoint(&grid, "│", column: left, row: row)
        mergeJoint(&grid, "│", column: right, row: row)
    }
    mergeJoint(&grid, "┌", column: left, row: top)
    mergeJoint(&grid, "┐", column: right, row: top)
    mergeJoint(&grid, "└", column: left, row: bottom)
    mergeJoint(&grid, "┘", column: right, row: bottom)
}

/// Merge a box-drawing glyph with what's already there so shared panel edges form clean joints.
private func mergeJoint(_ grid: inout CharacterGrid, _ incoming: Character, column: Int, row: Int) {
    let existing = grid.character(atColumn: column, row: row)
    grid.put(joinedGlyph(existing, incoming), column: column, row: row)
}

/// Combine two box-drawing characters into the glyph that carries both their strokes.
private func joinedGlyph(_ first: Character, _ second: Character) -> Character {
    if first == " " { return second }
    if first == second { return first }
    let combined = strokeMask(first) | strokeMask(second)
    return glyphForMask[combined] ?? second
}

// Stroke directions encoded as a bitmask: up | down | left | right.
private let strokeUp = 1
private let strokeDown = 2
private let strokeLeft = 4
private let strokeRight = 8

private func strokeMask(_ character: Character) -> Int {
    switch character {
    case "─": return strokeLeft | strokeRight
    case "│": return strokeUp | strokeDown
    case "┌": return strokeDown | strokeRight
    case "┐": return strokeDown | strokeLeft
    case "└": return strokeUp | strokeRight
    case "┘": return strokeUp | strokeLeft
    case "├": return strokeUp | strokeDown | strokeRight
    case "┤": return strokeUp | strokeDown | strokeLeft
    case "┬": return strokeDown | strokeLeft | strokeRight
    case "┴": return strokeUp | strokeLeft | strokeRight
    case "┼": return strokeUp | strokeDown | strokeLeft | strokeRight
    default: return 0
    }
}

private let glyphForMask: [Int: Character] = [
    strokeLeft | strokeRight: "─",
    strokeUp | strokeDown: "│",
    strokeDown | strokeRight: "┌",
    strokeDown | strokeLeft: "┐",
    strokeUp | strokeRight: "└",
    strokeUp | strokeLeft: "┘",
    strokeUp | strokeDown | strokeRight: "├",
    strokeUp | strokeDown | strokeLeft: "┤",
    strokeDown | strokeLeft | strokeRight: "┬",
    strokeUp | strokeLeft | strokeRight: "┴",
    strokeUp | strokeDown | strokeLeft | strokeRight: "┼",
]

private func highlightDivider(_ grid: inout CharacterGrid, layout: PanelLayout, divider: PanelLayout.Divider) {
    let rows = Int(layout.height.rounded())
    let columns = Int(layout.width.rounded())
    let splitXColumn = Int(layout.value(of: .splitX).rounded())
    switch divider {
    case .splitX:
        for row in 1..<(rows - 1) { grid.put("║", column: splitXColumn, row: row) }
    case .splitY1, .splitY2:
        let row = Int(layout.value(of: divider).rounded())
        for column in (splitXColumn + 1)..<(columns - 1) { grid.put("═", column: column, row: row) }
    }
}

// MARK: - Interactive (raw-mode keyboard)

private final class InteractiveTerminal {
    private let layout: PanelLayout
    private var activeDivider: PanelLayout.Divider = .splitX
    private var originalTerminalSettings = termios()
    private let nudgeStep = 2.0
    private let resizeStep = 2.0

    init() {
        let size = terminalSize()
        layout = PanelLayout(
            width: Double(size.columns),
            height: Double(size.rows - statusLineCount),
            minimums: terminalMinimums
        )
    }

    func run() {
        enableRawMode()
        defer { disableRawMode() }
        hideCursor()
        defer { showCursor() }

        draw()
        // 8 bytes is enough for the longest sequence we parse: a modified arrow,
        // ESC [ 1 ; <mod> <letter> (6 bytes).
        var inputBuffer = [UInt8](repeating: 0, count: 8)
        while true {
            let bytesRead = read(STDIN_FILENO, &inputBuffer, 8)
            guard bytesRead > 0 else { continue }
            if handleInput(inputBuffer, count: bytesRead) { break }
            draw()
        }
    }

    /// Returns true when the user asked to quit.
    ///
    /// Every divider is directly addressable — no need to cycle a selection:
    ///   - ← →            move splitX (left | right column)
    ///   - ↑ ↓            move splitY1 (right-top | right-mid border)
    ///   - Shift+Option ↑ ↓  move splitY2 (right-mid | right-bot border)
    /// hjkl / JK mirror these for keyboards without convenient modified arrows.
    private func handleInput(_ buffer: [UInt8], count: Int) -> Bool {
        if let arrow = parseArrow(buffer, count: count) {
            switch (arrow.key, arrow.modified) {
            case (.left, _):      move(.splitX, by: -nudgeStep)
            case (.right, _):     move(.splitX, by: nudgeStep)
            case (.up, false):    move(.splitY1, by: -nudgeStep)
            case (.down, false):  move(.splitY1, by: nudgeStep)
            case (.up, true):     move(.splitY2, by: -nudgeStep)
            case (.down, true):   move(.splitY2, by: nudgeStep)
            }
            return false
        }
        switch buffer[0] {
        case UInt8(ascii: "q"), 0x03: return true // q or Ctrl-C
        case UInt8(ascii: "h"): move(.splitX, by: -nudgeStep)
        case UInt8(ascii: "l"): move(.splitX, by: nudgeStep)
        case UInt8(ascii: "k"): move(.splitY1, by: -nudgeStep)
        case UInt8(ascii: "j"): move(.splitY1, by: nudgeStep)
        case UInt8(ascii: "K"): move(.splitY2, by: -nudgeStep)
        case UInt8(ascii: "J"): move(.splitY2, by: nudgeStep)
        case UInt8(ascii: "+"), UInt8(ascii: "="): resizeWindow(by: resizeStep)
        case UInt8(ascii: "-"), UInt8(ascii: "_"): resizeWindow(by: -resizeStep)
        default: break
        }
        return false
    }

    /// Move a divider and make it the highlighted one, so the highlight follows your last action.
    private func move(_ divider: PanelLayout.Divider, by delta: Double) {
        activeDivider = divider
        layout.nudge(divider, by: delta)
    }

    private enum ArrowKey { case up, down, left, right }

    /// Parse an arrow-key escape sequence, distinguishing plain from modified arrows.
    /// Plain:    ESC [ A/B/C/D
    /// Modified: ESC [ 1 ; <mod> A/B/C/D   (mod == 1 means no modifier)
    private func parseArrow(_ buffer: [UInt8], count: Int) -> (key: ArrowKey, modified: Bool)? {
        guard count >= 3, buffer[0] == 0x1B, buffer[1] == UInt8(ascii: "[") else { return nil }
        if count == 3 {
            return arrowKey(buffer[2]).map { ($0, false) }
        }
        if count == 6, buffer[2] == UInt8(ascii: "1"), buffer[3] == UInt8(ascii: ";") {
            let modified = buffer[4] != UInt8(ascii: "1")
            return arrowKey(buffer[5]).map { ($0, modified) }
        }
        return nil
    }

    private func arrowKey(_ byte: UInt8) -> ArrowKey? {
        switch byte {
        case 0x41: return .up
        case 0x42: return .down
        case 0x43: return .right
        case 0x44: return .left
        default: return nil
        }
    }

    private func resizeWindow(by delta: Double) {
        layout.resize(width: layout.width + delta, height: layout.height + delta)
    }

    private func draw() {
        let clearAndHome = "\u{1B}[2J\u{1B}[H"
        let invertColors = "\u{1B}[7m"
        let resetColors = "\u{1B}[0m"
        var output = clearAndHome
        output += drawLayout(layout, highlightedDivider: activeDivider)
        output += "\n\(invertColors) last: \(describe(activeDivider))  "
            + "[←→] left|right  [↑↓] top|mid  [⇧⌥↑↓] mid|bot  [+/-] resize  [q] quit \(resetColors)"
        FileHandle.standardOutput.write(Data(output.utf8))
    }

    private func describe(_ divider: PanelLayout.Divider) -> String {
        switch divider {
        case .splitX: return "splitX (left|right)"
        case .splitY1: return "splitY1 (top|mid)"
        case .splitY2: return "splitY2 (mid|bot)"
        }
    }

    // MARK: termios. Clean exit is `q`, which lets `defer` restore the terminal.
    // A SIGINT kill may leave the terminal dirty; recover with `reset`.

    private func enableRawMode() {
        tcgetattr(STDIN_FILENO, &originalTerminalSettings)
        var rawSettings = originalTerminalSettings
        rawSettings.c_lflag &= ~(UInt(ECHO) | UInt(ICANON))
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &rawSettings)
    }

    private func disableRawMode() {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTerminalSettings)
        FileHandle.standardOutput.write(Data("\u{1B}[2J\u{1B}[H".utf8))
    }

    private func hideCursor() { FileHandle.standardOutput.write(Data("\u{1B}[?25l".utf8)) }
    private func showCursor() { FileHandle.standardOutput.write(Data("\u{1B}[?25h".utf8)) }
}

// MARK: - Non-TTY animated sweep

private func runSweep() {
    print("KiwiDemo terminal (non-interactive sweep)\n")
    print("Constraints: splitX>=left, width-splitX>=right, splitY1>=top,")
    print("             splitY2-splitY1>=middle, height-splitY2>=bottom\n")

    let columns = 70.0
    let rows = 24.0
    let layout = PanelLayout(width: columns, height: rows, minimums: terminalMinimums)

    // Sweep splitX left→right (watch it clamp), then the two vertical dividers.
    let splitXFrames = stride(from: 5.0, through: columns - 5.0, by: 6.0).map { (PanelLayout.Divider.splitX, $0) }
    let splitY1Frames = stride(from: 1.0, through: rows - 2.0, by: 3.0).map { (PanelLayout.Divider.splitY1, $0) }
    let splitY2Frames = stride(from: rows - 2.0, through: 1.0, by: -3.0).map { (PanelLayout.Divider.splitY2, $0) }
    let frames = splitXFrames + splitY1Frames + splitY2Frames

    let frameDelayMicroseconds: UInt32 = 120_000
    for (divider, value) in frames {
        layout.drag(divider, to: value)
        print("\u{1B}[2J\u{1B}[H", terminator: "")
        print(drawLayout(layout, highlightedDivider: divider))
        fflush(stdout)
        usleep(frameDelayMicroseconds)
    }
    print("\nsweep complete")
}

// MARK: - Terminal size

private func terminalSize() -> (columns: Int, rows: Int) {
    let fallback = (columns: 80, rows: 24)
    var windowSize = winsize()
    if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &windowSize) == 0,
       windowSize.ws_col > 0, windowSize.ws_row > 0 {
        return (Int(windowSize.ws_col), Int(windowSize.ws_row))
    }
    return fallback
}
