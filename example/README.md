# Panes Example

A comprehensive demonstration of the `panes` package, featuring a modern, JetBrains Fleet-inspired "Islands UI" layout.

## Features Demonstrated

- **IdeLayout & IdeController**: Complete IDE-like setup with Left, Right, Center, and Bottom panels.
- **Islands UI Aesthetics**: Floating panels with rounded corners and consistent spacing.
- **Dynamic Split Terminals**: Use the "Split" button in the terminal panel to add/remove resizable terminal instances at runtime using `addPane` and `removePane`.
- **Dynamic Split Editors**: Split the main editor area horizontally to work on multiple files simultaneously.
- **Cascade Resize**: Demonstrates how resizing one pane can affect neighbors when constraints are hit.
- **Zero-Space Resizers**: Ultra-thin resizers that expand their hit-test area for better usability.
- **State Serialization**: Save and load the entire layout configuration.
- **Auto-Hide & Drag-to-Reveal**: Panels automatically collapse when small and can be revealed by dragging from the edge.

## Running the Example

```bash
flutter run
```

This example works best on Desktop (macOS, Windows, Linux) or Web.
