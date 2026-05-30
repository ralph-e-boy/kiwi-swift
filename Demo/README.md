# KiwiDemo — "AutoLayout for Metal"

A self-contained command-line demo of the [Kiwi](../) Cassowary constraint solver, driving a
four-panel resizable layout (one tall left panel + a right column of three stacked sub-panels).

The **same constraint model** (`PanelLayout`) feeds two renderers:

- **`terminal`** — an interactive ASCII layout you resize with the keyboard.
- **`metal`** — a resizable macOS Metal window whose panel borders you drag with the mouse.

The only dependency is the local `KiwiSolver` library. No other packages.

## How it works

Three draggable dividers are Cassowary **edit variables**:

| Variable  | Border it controls            |
|-----------|-------------------------------|
| `splitX`  | left panel ↔ right column     |
| `splitY1` | right-top ↔ right-mid         |
| `splitY2` | right-mid ↔ right-bot         |

Dragging a border calls `suggestValue` on its divider. **Required** minimum-size constraints
(`splitX >= minLeft`, `containerWidth - splitX >= minRight`, …) outrank the divider suggestions,
so the solver **clamps** any drag that would collapse a panel — exactly how a browser frame
behaves. The container size is a stronger edit variable, so resizing the window re-solves while
the minimums still hold.

See `Sources/KiwiDemo/PanelLayout.swift` — it's the single source of constraint truth.

## Running

```bash
cd Demo
swift build

swift run KiwiDemo terminal   # interactive ASCII (default)
swift run KiwiDemo metal      # macOS Metal window
swift run KiwiDemo verify     # constraint clamp self-test
swift run KiwiDemo --help
```

### Terminal mode keys

Every border is directly addressable — no need to cycle a selection. The highlight follows
whichever border you moved last.

| Key            | Border moved                       |
|----------------|------------------------------------|
| `←` / `→`      | splitX — left panel ↔ right column  |
| `↑` / `↓`      | splitY1 — right-top ↔ right-mid     |
| `⇧⌥↑` / `⇧⌥↓`  | splitY2 — right-mid ↔ right-bot     |
| `h` / `l`      | splitX (plain-keyboard alias)      |
| `k` / `j`      | splitY1 (plain-keyboard alias)     |
| `K` / `J`      | splitY2 (plain-keyboard alias)     |
| `+` / `-`      | grow / shrink the window           |
| `q`            | quit                               |

Plain `↑`/`↓` already drive splitY1, so splitY2 uses the `⇧⌥` (Shift+Option) modified arrows;
`K`/`J` are the fallback for keyboards without convenient modified arrows.

If stdout isn't a TTY (e.g. piped or redirected), terminal mode runs a non-interactive
**animated sweep** instead, so you can watch the panels adapt and hit their limits:

```bash
swift run KiwiDemo terminal | cat
```

> If a `SIGINT` (Ctrl-C) ever leaves the terminal in raw mode, run `reset` to restore it.
> Quitting with `q` always restores it cleanly.

### Metal mode

Drag any panel border to resize; the cursor switches to the resize shape over a divider.
Resizing the OS window re-solves the layout. Metal mode requires macOS 13+ with MetalKit.

## Verification status

- `swift build` — clean (0 warnings).
- `swift run KiwiDemo verify` — all 8 clamp checks pass (expectations derived from the inputs).
- Non-TTY sweep — renders 23 box-drawing frames and exits cleanly.
- `terminal` (interactive) — all three dividers verified end-to-end over a pty: `←→` move
  splitX, `↑↓` move splitY1, `⇧⌥↑↓` move splitY2, each in the correct direction.
- `metal` mode is build-verified; it requires a live window and is meant to be driven by hand.

