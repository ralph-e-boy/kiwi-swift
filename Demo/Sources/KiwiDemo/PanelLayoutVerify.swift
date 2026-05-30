import Foundation

/// One clamp expectation: a solved value that must equal a value derived from the inputs.
private struct Check {
    let label: String
    let actual: Double
    let expected: Double

    var passed: Bool { (actual - expected).magnitude <= 0.5 }
}

/// Step 0 self-test: confirm the solver clamps divider drags at the required minimums
/// before any rendering exists. Run with `swift run KiwiDemo verify`.
///
/// Expectations are derived from the layout's inputs (container size and minimums), never
/// from hardcoded literals, so each assertion expresses the constraint relationship itself.
func runVerify() -> Int32 {
    let minimums = PanelLayout.Minimums(left: 80, right: 120, top: 60, middle: 60, bottom: 60)
    let width = 800.0
    let height = 600.0
    let layout = PanelLayout(width: width, height: height, minimums: minimums)
    let beyondAnyEdge = max(width, height) * 100

    print("Verifying clamp behavior (width=\(format(width)) height=\(format(height)))")

    var checks: [Check] = []

    // Dragging splitX far right must clamp so the right column keeps its minimum width.
    layout.drag(.splitX, to: beyondAnyEdge)
    checks.append(Check(label: "splitX clamps to leave room for right minimum",
                        actual: layout.value(of: .splitX), expected: width - minimums.right))

    // Dragging splitX far left must clamp at the left minimum width.
    layout.drag(.splitX, to: -beyondAnyEdge)
    checks.append(Check(label: "splitX clamps at left minimum",
                        actual: layout.value(of: .splitX), expected: minimums.left))

    // Dragging splitY1 up must clamp at the top minimum height.
    layout.drag(.splitY1, to: -beyondAnyEdge)
    checks.append(Check(label: "splitY1 clamps at top minimum",
                        actual: layout.value(of: .splitY1), expected: minimums.top))

    // Dragging splitY2 down must clamp so the bottom panel keeps its minimum height.
    layout.drag(.splitY2, to: beyondAnyEdge)
    checks.append(Check(label: "splitY2 clamps to leave room for bottom minimum",
                        actual: layout.value(of: .splitY2), expected: height - minimums.bottom))

    // With both vertical dividers pushed apart, the middle panel keeps its minimum height.
    layout.drag(.splitY1, to: -beyondAnyEdge)
    layout.drag(.splitY2, to: beyondAnyEdge)
    checks.append(Check(label: "right-mid height stays at its minimum",
                        actual: layout.value(of: .splitY2) - layout.value(of: .splitY1),
                        expected: height - minimums.top - minimums.bottom))

    // The four panels must partition the container exactly.
    let panels = layout.panels
    checks.append(Check(label: "left panel meets the right column at splitX",
                        actual: panels[0].x + panels[0].width, expected: layout.value(of: .splitX)))
    checks.append(Check(label: "right column reaches the container width",
                        actual: panels[1].x + panels[1].width, expected: width))
    checks.append(Check(label: "bottom panel reaches the container height",
                        actual: panels[3].y + panels[3].height, expected: height))

    var failureCount = 0
    for check in checks {
        if check.passed {
            print("  ok   \(check.label): \(format(check.actual))")
        } else {
            print("  FAIL \(check.label): got \(format(check.actual)), expected \(format(check.expected))")
            failureCount += 1
        }
    }

    if failureCount == 0 {
        print("verify: all \(checks.count) checks passed")
        return 0
    }
    print("verify: \(failureCount)/\(checks.count) check(s) failed")
    return 1
}

func format(_ value: Double) -> String {
    String(format: "%.1f", value)
}
