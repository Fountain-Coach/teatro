# Repository Guidelines

This repository contains the documentation for **Teatro View Engine**, a declarative Swift 6 framework for rendering text, music and screenplay artifacts. The README describes the envisioned architecture including protocols, view types, rendering backends, an animation system, LilyPond and MIDI integrations, and a Fountain screenplay parser.

## Contributing
- Keep new code modular and follow the structures laid out in `README.md`.
- Prefer Swift 6 and standard library constructs.
- When adding files, follow the suggested directory structure from the README (e.g. `Sources/`, `Tests/`, `CLI/`).
- Include tests under `Tests/` once implementation begins. For now this repository only contains documentation.
- Run `swift build` and `swift test` if a `Package.swift` manifest is present.

## Repo Tasks for Codex
- There are currently no automated tests. If you add code, provide appropriate tests and ensure they run via `swift test`.
- Maintain this `AGENTS.md` if repository structure changes.
