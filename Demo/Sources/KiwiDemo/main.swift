import Foundation

func printUsage() {
    print("""
    KiwiDemo — constraint-driven layout demo (AutoLayout for Metal)

    USAGE:
      swift run KiwiDemo [mode]

    MODES:
      terminal   Interactive ASCII layout. Drag dividers with the keyboard. (default)
      metal      Resizable macOS Metal window with draggable panel borders.
      verify     Run the constraint clamp self-test and exit.
      --help     Show this help.

    The same PanelLayout constraint model drives both renderers.
    """)
}

let mode = CommandLine.arguments.dropFirst().first ?? "terminal"

switch mode {
case "verify":
    exit(runVerify())
case "metal":
    runMetalDemo()
case "terminal":
    runTerminalDemo()
case "--help", "-h", "help":
    printUsage()
default:
    print("Unknown mode: \(mode)\n")
    printUsage()
    exit(2)
}
