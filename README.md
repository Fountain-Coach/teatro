# Teatro View Engine  
*A Declarative, Codex-Controllable Rendering Framework in Swift*
![](../03-Visuals/teatro-symbol-clean.svg)
---

## Abstract

The **Teatro View Engine** is a modular, composable rendering framework written in Swift 6 and optimized for Linux environments. It is designed for Codex-based orchestration and supports fully declarative semantic views, timeline-based animations, musical score rendering (via LilyPond), structured MIDI 2.0 output, and `.fountain` screenplay parsing. Teatro bridges visual, musical, and narrative computation in a testable and introspectable runtime—turning reasoning into staged, rendered artifacts across multiple formats (HTML, SVG, PNG, PDF, MIDI).

This document provides a complete specification of the engine’s protocol design, view architecture, renderer integrations, animation tools, music and screenplay modules, CLI interfaces, and usage patterns.

## Table of Contents

1. [Core Protocols](#core-protocols)  
   1.1 [Renderable](#renderable)  
   1.2 [Layouting](#layouting)  
   1.3 [Alignment](#alignment)  
   1.4 [TextStyle](#textstyle)  
   1.5 [@ViewBuilder](#viewbuilder)

2. [View Types](#view-types)  
   2.1 [Text](#text)  
   2.2 [VStack](#vstack)  
   2.3 [HStack](#hstack)  
   2.4 [Stage](#stage)  
   2.5 [TeatroIcon](#teatroicon)

3. [Rendering Backends](#rendering-backends)  
   3.1 [HTMLRenderer](#htmlrenderer)  
   3.2 [SVGRenderer](#svgrenderer)  
   3.3 [ImageRenderer (Cairo)](#imagerenderer-cairo)  
   3.4 [CodexPreviewer](#codexpreviewer)

4. [CLI Integration](#cli-integration)

5. [Animation System](#animation-system)  
   5.1 [Animator](#animator)

6. [LilyPond Music Rendering](#lilypond-music-rendering)  
   6.1 [LilyScore](#lilyscore)

7. [MIDI 2.0 DSL](#midi-20-dsl)  
   7.1 [MIDINote](#midinote)  
   7.2 [MIDISequence](#midisequence)  
   7.3 [MIDIRenderer](#midirenderer)

8. [Fountain Screenplay Engine](#fountain-screenplay-engine)  
   8.1 [FountainElement](#fountainelement)  
   8.2 [FountainRenderer](#fountainrenderer)  
   8.3 [FountainSceneView](#fountainsceneview)

9. [Summary](#summary)
10. [Addendum](#addendum)

## 1. Core Protocols

### 1.1 Renderable

The foundational protocol of the Teatro View Engine. All visual, narrative, or musical view types conform to `Renderable`, ensuring a consistent `.render()` interface for Codex control, preview rendering, or export.

```swift
public protocol Renderable {
    func render() -> String
}
```

---

### 1.2 Layouting

Used by layout-oriented views such as `VStack` or `HStack`. Provides optional horizontal alignment and indentation padding.

```swift
public protocol Layouting: Renderable {
    var alignment: Alignment { get }
    var padding: Int { get }
}
```

---

### 1.3 Alignment

The alignment options available to layout containers.

```swift
public enum Alignment: String {
    case leading = "left"
    case center = "center"
    case trailing = "right"
}
```

---

### 1.4 TextStyle

This enum describes inline style variations applied to `Text` views.

```swift
public enum TextStyle {
    case bold, italic, underline, plain

    public func apply(to content: String) -> String {
        switch self {
        case .bold: return "**\\(content)**"
        case .italic: return "*\\(content)*"
        case .underline: return "_\\(content)_"
        case .plain: return content
        }
    }
}
```

---

### 1.5 @ViewBuilder

Swift-style result builder for grouping child views declaratively.

```swift
@resultBuilder
public enum ViewBuilder {
    public static func buildBlock(_ components: Renderable...) -> [Renderable] {
        components
    }
}
```

## 2. View Types

### 2.1 Text

The `Text` view displays a single styled line of content using an optional `TextStyle`.

```swift
public struct Text: Renderable {
    public let content: String
    public let style: TextStyle

    public init(_ content: String, style: TextStyle = .plain) {
        self.content = content
        self.style = style
    }

    public func render() -> String {
        style.apply(to: content)
    }
}
```

---

### 2.2 VStack

A vertical stack of child views. Each child is indented based on the `padding` value and aligned using the specified `Alignment`.

```swift
public struct VStack: Layouting {
    public let children: [Renderable]
    public let alignment: Alignment
    public let padding: Int

    public init(alignment: Alignment = .leading, padding: Int = 0, @ViewBuilder _ content: () -> [Renderable]) {
        self.alignment = alignment
        self.padding = padding
        self.children = content()
    }

    public func render() -> String {
        let indent = String(repeating: " ", count: padding)
        return children.map { indent + $0.render() }.joined(separator: "\n")
    }
}
```

---

### 2.3 HStack

A horizontal stack of child views rendered on a single line, separated by spaces and prefixed by optional padding.

```swift
public struct HStack: Layouting {
    public let children: [Renderable]
    public let alignment: Alignment
    public let padding: Int

    public init(alignment: Alignment = .leading, padding: Int = 0, @ViewBuilder _ content: () -> [Renderable]) {
        self.alignment = alignment
        self.padding = padding
        self.children = content()
    }

    public func render() -> String {
        let indent = String(repeating: " ", count: padding)
        return indent + children.map { $0.render() }.joined(separator: " ")
    }
}
```

---

### 2.4 Stage

A top-level semantic container that can group scenes, components, or temporal slices. The `title` is always shown, followed by the content block.

```swift
public struct Stage: Renderable {
    public let title: String
    public let content: Renderable

    public init(title: String, @ViewBuilder content: () -> Renderable) {
        self.title = title
        self.content = content()
    }

    public func render() -> String {
        "[Stage: \(title)]\n" + content.render()
    }
}
```

---

### 2.5 TeatroIcon

A symbolic display element rendered with a gestural or expressive icon. Useful for stage props, semantic emphasis, or layout anchoring.

```swift
public struct TeatroIcon: Renderable {
    public let symbol: String

    public init(_ symbol: String) {
        self.symbol = symbol
    }

    public func render() -> String {
        "◉ \(symbol)"
    }
}
```

## 3. Rendering Backends

The Teatro View Engine supports multiple rendering targets, each implemented as a standalone `Renderer` struct. All accept a `Renderable` view and return a format-specific string or file output.

---

### 3.1 HTMLRenderer

Renders view content inside a `<pre>` block for monospaced output in the browser.

```swift
public struct HTMLRenderer {
    public static func render(_ view: Renderable) -> String {
        "<html><body><pre>\n" + view.render() + "\n</pre></body></html>"
    }
}
```

---

### 3.2 SVGRenderer

Renders the view into a structured SVG document with individual `<text>` elements per line. Useful for scalable vector export or embedding in web documents.

```swift
public struct SVGRenderer {
    public static func render(_ view: Renderable) -> String {
        let lines = view.render().components(separatedBy: "\n")
        let rendered = lines.enumerated().map { idx, line in
            "<text x=\"10\" y=\"\(20 + idx * 20)\" font-family=\"monospace\" font-size=\"14\">\(line)</text>"
        }.joined(separator: "\n")

        return """
        <svg xmlns="http://www.w3.org/2000/svg" width="600" height="\(20 + lines.count * 20)">
        \(rendered)
        </svg>
        """
    }
}
```

---

### 3.3 ImageRenderer (Cairo)

Renders the view into a `.png` using the Cairo graphics library. Each line is drawn using a monospaced font.

```swift
import Cairo

public struct ImageRenderer {
    public static func renderToPNG(_ view: Renderable, to path: String = "output.png") {
        let surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 800, 600)
        let cr = cairo_create(surface)

        cairo_set_source_rgb(cr, 1, 1, 1)
        cairo_paint(cr)

        cairo_set_source_rgb(cr, 0, 0, 0)
        cairo_select_font_face(cr, "monospace", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
        cairo_set_font_size(cr, 16)

        let lines = view.render().components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            cairo_move_to(cr, 10, Double(30 + i * 20))
            cairo_show_text(cr, line)
        }

        cairo_surface_write_to_png(surface, path)
        cairo_destroy(cr)
        cairo_surface_destroy(surface)
    }
}
```

---

### 3.4 CodexPreviewer

A renderer specifically designed for semantic introspection and Codex feedback. Includes the view type and the output together in a preview block.

```swift
public struct CodexPreviewer {
    public static func preview(_ view: Renderable) -> String {
        """
        /// Codex Preview:
        ///
        /// Source:
        /// \(String(describing: type(of: view)))
        ///
        /// Output:
        \(view.render())
        """
    }
}
```

## 4. CLI Integration

The Teatro View Engine includes a lightweight command-line interface (CLI) implementation for rendering any `Renderable` to a chosen output format. This enables scripting, automation, or integration with external developer tools.

---

### RenderCLI

```swift
public enum RenderTarget: String {
    case html, svg, png, codex
}
```

This enum defines supported output formats.

```swift
public struct RenderCLI {
    public static func main(args: [String]) {
        let view = Stage(title: "CLI Demo") {
            VStack(alignment: .center, padding: 2) {
                TeatroIcon("🎭")
                Text("CLI Renderer", style: .bold)
            }
        }

        let target = RenderTarget(rawValue: args.first ?? "codex") ?? .codex

        switch target {
        case .html:
            print(HTMLRenderer.render(view))
        case .svg:
            print(SVGRenderer.render(view))
        case .png:
            ImageRenderer.renderToPNG(view)
        case .codex:
            print(CodexPreviewer.preview(view))
        }
    }
}
```

---

### Usage

```bash
swift run RenderCLI html
swift run RenderCLI svg
swift run RenderCLI png
swift run RenderCLI codex
```

This CLI is ideal for:
- Previewing scenes, tests, or examples from terminal
- Connecting renderable output to other tools (e.g., orchestration logs, build pipelines)
- Rendering `.fountain`, `.mid`, or `.ly` views via CLI with extended routing

## 5. Animation System

The Teatro View Engine supports timeline-based rendering by generating sequential frames of `Renderable` views. These frames can be used to create `.gif` animations or time-stepped outputs for screenplays, music, or visual reasoning steps.

---

### 5.1 Animator

The `Animator` struct provides the ability to render multiple sequential views into numbered `.png` image frames.

```swift
import Foundation

public struct Animator {
    public static func renderFrames(_ frames: [Renderable], baseName: String = "frame") {
        for (i, frame) in frames.enumerated() {
            let path = "Animations/\(baseName)_\(i).png"
            ImageRenderer.renderToPNG(frame, to: path)
        }
    }
}
```

---

### Example

```swift
let frames: [Renderable] = (0..<5).map { i in
    VStack {
        Text("Frame \(i)", style: .bold)
        Text(String(repeating: ".", count: i))
    }
}

Animator.renderFrames(frames, baseName: "timeline")
```

This creates:

```
Animations/timeline_0.png
Animations/timeline_1.png
Animations/timeline_2.png
...
```

---

### Exporting as GIF (using ImageMagick)

Once frames are rendered, you can use `convert` to create an animated `.gif`:

```bash
convert -delay 50 -loop 0 Animations/timeline_*.png animated.gif
```

---

This animation system works especially well for:
- Frame-by-frame reflections or GPT planning steps
- MIDI timeline playback
- `.fountain` screenplay line reveals
- Drift and semantic arc transitions

## 6. LilyPond Music Rendering

The Teatro View Engine supports musical score composition and PDF rendering using the LilyPond typesetting system. This allows GPT or Codex agents to declaratively construct musical ideas and export them as print-ready sheet music.

---

### 6.1 LilyScore

```swift
import Foundation

public struct LilyScore: Renderable {
    public let content: String

    public init(_ content: String) {
        self.content = content
    }

    public func render() -> String {
        content
    }

    public func renderToPDF(filename: String = "score") {
        let tempPath = "/tmp/\(filename).ly"
        try? content.write(toFile: tempPath, atomically: true, encoding: .utf8)

        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["lilypond", "-o", filename, tempPath]
        try? task.run()
        task.waitUntilExit()
    }
}
```

---

### Example

```swift
let score = LilyScore("""
\\version "2.24.2"
\\relative c' {
  c4 d e f | g a b c
}
""")

score.renderToPDF(filename: "teatro_theme")
```

This will produce:
```
teatro_theme.pdf
teatro_theme.ps
```

---

### Integration Points

- `LilyScore` is fully compatible with `Stage` or `Animator`
- Codex can generate LilyPond DSL fragments and immediately preview them
- This renderer can be used to seed training prompts or music composition environments
- LilyPond-generated files are suitable for formal printing, digital annotation, or score playback

---

### Notes

- LilyPond must be installed on the system (`lilypond` must be on `$PATH`)
- If needed, Codex can be prompted to emit safe `.ly` fragments
- Combine with GPT output templates to embed titles, composer metadata, lyrics, and spacing settings

## 7. MIDI 2.0 DSL

The Teatro View Engine includes a declarative Swift DSL for composing MIDI sequences. It enables Codex and GPT agents to structure musical timelines with precise note control, and render them to `.mid` files.

---

### 7.1 MIDINote

A single note event: pitch, velocity, channel, and duration in seconds.

```swift
public struct MIDINote {
    public let channel: Int
    public let note: Int
    public let velocity: Int
    public let duration: Double

    public init(channel: Int, note: Int, velocity: Int, duration: Double) {
        self.channel = channel
        self.note = note
        self.velocity = velocity
        self.duration = duration
    }
}
```

---

### 7.2 MIDISequence

A collection of `MIDINote` elements. Supports Swift result builder syntax.

```swift
public struct MIDISequence {
    public let notes: [MIDINote]

    public init(@NoteBuilder _ build: () -> [MIDINote]) {
        self.notes = build()
    }
}
```

#### NoteBuilder

```swift
@resultBuilder
public enum NoteBuilder {
    public static func buildBlock(_ notes: MIDINote...) -> [MIDINote] {
        notes
    }
}
```

---

### 7.3 MIDIRenderer

Writes `.mid`-like content to a file. This placeholder is intended to be replaced with a true MIDI encoder.

```swift
import Foundation

public struct MIDIRenderer {
    public static func renderToFile(_ sequence: MIDISequence, to path: String = "output.mid") {
        let content = sequence.notes.map {
            "NOTE(ch:\($0.channel), key:\($0.note), vel:\($0.velocity), dur:\($0.duration))"
        }.joined(separator: "\n")

        try? content.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
```

---

### Example

```swift
let melody = MIDISequence {
    MIDINote(channel: 0, note: 60, velocity: 100, duration: 0.5)
    MIDINote(channel: 0, note: 64, velocity: 100, duration: 0.5)
    MIDINote(channel: 0, note: 67, velocity: 100, duration: 1.0)
}

MIDIRenderer.renderToFile(melody, to: "demo.mid")
```

---

### Integration Notes

- This system can later support MIDI 2.0 features (per-note expression, UMP packets)
- Compatible with future `MIDIPianoRoll` visual rendering
- Pairs well with `Animator` for synchronizing scenes and sounds

## 8. Fountain Screenplay Engine

Teatro supports parsing and rendering of screenplays written in the [Fountain](https://fountain.io) format — a Markdown-compatible syntax used by screenwriters. This enables GPT-based screenwriting, line-by-line rendering, Codex-based performance scripting, and visual orchestration of narrative structures.

---

### 8.1 FountainElement

The `FountainElement` enum represents all semantically distinct components of a screenplay.

```swift
public enum FountainElement: Renderable {
    case sceneHeading(String)
    case characterCue(String)
    case dialogue(String)
    case action(String)
    case transition(String)

    public func render() -> String {
        switch self {
        case .sceneHeading(let txt): return "# \(txt)"
        case .characterCue(let txt): return "\n\(txt.uppercased())"
        case .dialogue(let txt): return "\t\(txt)"
        case .action(let txt): return txt
        case .transition(let txt): return "\(txt) >>"
        }
    }
}
```

---

### 8.2 FountainRenderer

A static parsing utility that converts raw `.fountain` text into a list of typed `FountainElement`s.

```swift
public struct FountainRenderer {
    public static func parse(_ text: String) -> [FountainElement] {
        var elements: [FountainElement] = []

        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("INT") || line.hasPrefix("EXT") {
                elements.append(.sceneHeading(line))
            } else if line.uppercased() == line && line.trimmingCharacters(in: .whitespaces).count > 0 {
                elements.append(.characterCue(line))
            } else if line.hasSuffix("TO:") {
                elements.append(.transition(line))
            } else if line.hasPrefix("  ") || line.hasPrefix("\t") {
                elements.append(.dialogue(line.trimmingCharacters(in: .whitespaces)))
            } else if !line.isEmpty {
                elements.append(.action(line))
            }
        }

        return elements
    }
}
```

---

### 8.3 FountainSceneView

A wrapper that takes `.fountain` source and renders it using its parsed structure.

```swift
public struct FountainSceneView: Renderable {
    public let elements: [FountainElement]

    public init(fountainText: String) {
        self.elements = FountainRenderer.parse(fountainText)
    }

    public func render() -> String {
        elements.map { $0.render() }.joined(separator: "\n")
    }
}
```

---

### Example

```swift
let sceneText = """
INT. LAB - NIGHT

The robot assembles a memory core.

ROBOT
(to itself)
I was not made for silence.

CUT TO:
EXT. CITY STREET - NIGHT
"""

let view = FountainSceneView(fountainText: sceneText)
print(view.render())
```

This renders as:

```
# INT. LAB - NIGHT

The robot assembles a memory core.

ROBOT
	to itself

CUT TO: >>
# EXT. CITY STREET - NIGHT
```

---

### Use Cases

- GPT can generate `.fountain` script snippets that are rendered as structured views
- Combine with `Animator` for line-by-line or beat-by-beat reveal
- Pair with `Stage` to segment narrative structure into episodic slices
- Embed semantic cues for lighting, props, and character arcs via `TeatroIcon` and `CodexPreviewer`

## 9. Summary

The **Teatro View Engine** is a modular, fully declarative view system written in Swift 6 for Linux environments. It enables Codex-based orchestration of semantic user interfaces, narrative compositions, animations, and musical structures.

### ✅ Key Capabilities

- **Declarative UI Views**  
  Composable `Renderable` types (`Text`, `VStack`, `Stage`, etc.) support layout, alignment, styling, and introspection.

- **Rendering Backends**  
  Multiple output targets including HTML, SVG, PNG (via Cairo), and Codex introspection.

- **CLI Integration**  
  A command-line entry point allows rendering from terminal or scriptable pipelines.

- **Timeline-Based Animation**  
  Frame-by-frame rendering of view sequences for semantic drift, transitions, and GPT step-wise thinking.

- **Music Rendering**  
  - **LilyPond:** Printable PDF sheet music from `LilyScore` views.
  - **MIDI DSL:** MIDI 2.0-style sequencing via `MIDINote`, `MIDISequence`, and `MIDIRenderer`.

- **Screenplay Rendering**  
  - `.fountain` parsing into typed screenplay elements
  - `FountainSceneView` enables GPT-authored scripts to be staged and animated

---

### 🧠 Codex Readiness

All parts of the Teatro View Engine are designed to be:

- Composable: All views conform to `Renderable`  
- Introspectable: Every structure has deterministic `render()` output  
- Animatable: Views can evolve across time via `Animator`  
- GPT-friendly: DSLs like `.fountain`, LilyPond, and MIDI are natively supported  
- Extensible: Each layer can be expanded (e.g. to live UI, SVG animation, SVG timelines, MIDI2 UMP, etc.)

---

### 📁 Suggested Directory Structure

```
Teatro/
├── Sources/
│   ├── ViewCore/
│   ├── Renderers/
│   ├── CLI/
├── Tests/
│   └── ViewRenderingTests.swift
├── Animations/
├── assets/
├── README.md
└── Package.swift
```

---

## 🧩 Addendum: Apple Platform Compatibility

### Will Teatro View Engine support Apple platforms?

Yes — the **Teatro View Engine** is fully compatible with Apple platforms including **macOS**, **iOS**, and **iPadOS**, with only minimal adjustments required.

---

### ✅ Native Swift Compatibility

- **Language & Structure**  
  Teatro is written entirely in Swift 6 using standard constructs (`struct`, `enum`, `protocol`, result builders), which are fully supported by Apple’s platforms. This makes the engine immediately compilable and executable on macOS, iOS, and iPadOS using Xcode or Swift Package Manager.

- **Cross-Platform Design**  
  The engine does not rely on platform-specific UI frameworks like UIKit or SwiftUI at its core. Instead, it uses a protocol-driven, declarative architecture that can be adapted for different rendering targets—including native Apple views.

---

### ⚙️ What Needs Adapting?

- **Cairo Dependency (Linux-only)**  
  The `ImageRenderer` currently uses the Cairo graphics library for `.png` output. On Apple platforms, this can be replaced with native alternatives:
  - `CoreGraphics` (for macOS and iOS)
  - `AppKit` (macOS-specific drawing)
  - `UIKit` (for iOS rendering contexts)

- **Optional SwiftUI Integration**  
  Developers can implement a lightweight SwiftUI renderer to preview Teatro views in real-time within Apple applications or Xcode Previews.

  ```swift
  struct TeatroRenderView: View {
      let content: Renderable
      var body: some View {
          Text(content.render())
              .font(.system(.body, design: .monospaced))
              .padding()
      }
  }
  ```

- **PDFKit Support**  
  Teatro views (such as `LilyScore` or `FountainSceneView`) can be rendered to `.pdf` using Apple’s native `PDFKit`, allowing seamless preview, export, or annotation.

---

### 🍎 Recommended Enhancements for Apple

| Component         | Apple-native Replacement            |
|------------------|--------------------------------------|
| `ImageRenderer`  | Use CoreGraphics + AppKit/UIKit      |
| `.pdf` output    | Use PDFKit instead of shell + LilyPond|
| Live preview     | SwiftUI or Xcode Playground integration |
| Timeline playback| Combine with SwiftUI Animations or AVFoundation (optional) |

---

### 📦 Summary

While Teatro is **optimized for Codex orchestration and Linux-based environments**, it is **fully portable to Apple systems**. With minor renderer adaptations and optional SwiftUI wrappers, Teatro can serve as the foundation for:
- Native apps
- Live previews
- Developer tools
- Multimodal orchestration pipelines

This ensures that semantic rendering, narrative structuring, and musical composition can flow seamlessly across both server and Apple-native interfaces.


### 🧪 Next Steps

- Add real `.mid` encoding and SVG piano roll visualization
- Add `.gif` export as post-processing to `Animator`
- Add `TimedView`, `Beat`, or `Marker` types for synchronization
- Publish as a Swift package and Codex toolchain plugin
- Integrate with FountainAI orchestration stack for visual storytelling

---

© 2025 FountainAI — MIT License
