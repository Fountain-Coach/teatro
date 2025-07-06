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

