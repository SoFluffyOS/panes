/// Cascade Resize Demo - IDE Layout
///
/// Demonstrates cascade resize in a realistic IDE-like layout.
library;

import 'package:flutter/material.dart';
import 'package:panes/panes.dart';

class CascadeDemo extends StatefulWidget {
  const CascadeDemo({super.key});

  @override
  State<CascadeDemo> createState() => _CascadeDemoState();
}

class _CascadeDemoState extends State<CascadeDemo> {
  late PaneController _horizontalController;
  late PaneController _verticalController;

  // Track dynamic entries for horizontal panes
  late List<PaneEntry> _horizontalEntries;
  int _editorCount = 2;

  @override
  void initState() {
    super.initState();
    _initEntries();
    _buildControllers();
  }

  void _initEntries() {
    _horizontalEntries = [
      // File Explorer - eager, will cascade
      PaneEntry(
        id: 'explorer',
        initialSize: PaneSize.pixel(200),
        minSize: PaneSize.pixel(150),
        maxSize: PaneSize.pixel(350),
        resizeBehavior: ResizeBehavior.eager,
      ),
      // Editor 1 - eager (default for fraction), absorbs cascade
      PaneEntry(
        id: 'editor1',
        initialSize: PaneSize.fraction(1.0),
        minSize: PaneSize.pixel(150),
      ),
      // Editor 2 - eager, absorbs cascade
      PaneEntry(
        id: 'editor2',
        initialSize: PaneSize.fraction(1.0),
        minSize: PaneSize.pixel(150),
      ),
      // Outline Panel - FIXED, won't participate in cascade
      PaneEntry(
        id: 'outline',
        initialSize: PaneSize.pixel(180),
        minSize: PaneSize.pixel(120),
        maxSize: PaneSize.pixel(300),
        resizeBehavior: ResizeBehavior.fixed,
      ),
    ];
    _editorCount = 2;
  }

  void _buildControllers() {
    // Horizontal: Explorer | Editors... | Outline
    _horizontalController = PaneController(entries: _horizontalEntries);

    // Vertical: Main Area / Terminal
    _verticalController = PaneController(
      entries: [
        // Main content area - fractional, eager
        PaneEntry(
          id: 'main',
          initialSize: PaneSize.fraction(1.0),
          minSize: PaneSize.pixel(200),
        ),
        // Terminal/Output - pixel, eager (can cascade)
        PaneEntry(
          id: 'terminal',
          initialSize: PaneSize.pixel(150),
          minSize: PaneSize.pixel(80),
          maxSize: PaneSize.pixel(400),
          resizeBehavior: ResizeBehavior.eager,
        ),
      ],
    );
  }

  void _addEditor() {
    setState(() {
      _editorCount++;
      final newEditor = PaneEntry(
        id: 'editor$_editorCount',
        initialSize: PaneSize.fraction(1.0),
        minSize: PaneSize.pixel(150),
      );
      // Insert before outline (last item)
      _horizontalEntries.insert(_horizontalEntries.length - 1, newEditor);
      _horizontalController.dispose();
      _horizontalController = PaneController(entries: _horizontalEntries);
    });
  }

  void _removeLastEditor() {
    // Keep at least one editor
    final editorCount = _horizontalEntries
        .where((e) => e.id.startsWith('editor'))
        .length;
    if (editorCount <= 1) return;

    setState(() {
      // Find and remove the last editor (before outline)
      final lastEditorIndex = _horizontalEntries.length - 2;
      if (_horizontalEntries[lastEditorIndex].id.startsWith('editor')) {
        _horizontalEntries.removeAt(lastEditorIndex);
        _horizontalController.dispose();
        _horizontalController = PaneController(entries: _horizontalEntries);
      }
    });
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _horizontalController.dispose();
      _verticalController.dispose();
      _initEntries();
      _buildControllers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1e1e1e),
      body: Column(
        children: [
          // Title bar
          _buildTitleBar(),
          // Instructions
          _buildInstructions(),
          // Size indicators for horizontal panels
          _buildSizeIndicators(),
          // Main IDE layout (vertical split: main area + terminal)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: MultiPane(
                controller: _verticalController,
                direction: Axis.vertical,
                paneBuilder: (context, id) => _buildVerticalPane(id),
              ),
            ),
          ),
          // Size indicator for terminal
          _buildTerminalSizeIndicator(),
        ],
      ),
    );
  }

  Widget _buildVerticalPane(String id) {
    return switch (id) {
      'main' => MultiPane(
          controller: _horizontalController,
          direction: Axis.horizontal,
          paneBuilder: (context, id) => _buildHorizontalPane(id),
        ),
      'terminal' => _buildTerminalPanel(),
      _ => const SizedBox(),
    };
  }

  Widget _buildTitleBar() {
    return Container(
      height: 40,
      color: const Color(0xFF323233),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            color: Colors.white70,
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Cascade Resize Demo - IDE Layout',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reset'),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF2d2d30),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Try: Drag Explorer panel past its max (350px)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Editor panels (eager) will shrink • Outline panel (fixed) stays unchanged',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _legendItem('eager', Colors.green),
          const SizedBox(width: 12),
          _legendItem('fixed', Colors.red),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
      ],
    );
  }

  Widget _buildSizeIndicators() {
    return ListenableBuilder(
      listenable: _horizontalController,
      builder: (context, _) {
        return Container(
          height: 32,
          color: const Color(0xFF252526),
          child: Row(
            children: [
              for (final entry in _horizontalController.entries)
                Expanded(child: _sizeChip(entry, _horizontalController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTerminalSizeIndicator() {
    return ListenableBuilder(
      listenable: _verticalController,
      builder: (context, _) {
        final entry = _verticalController.entries
            .firstWhere((e) => e.id == 'terminal');
        return Container(
          height: 24,
          color: const Color(0xFF252526),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(child: _sizeChip(entry, _verticalController)),
            ],
          ),
        );
      },
    );
  }

  Widget _sizeChip(PaneEntry entry, PaneController controller) {
    final size = controller.getPixelSize(entry.id) ??
        controller.getFractionalSize(entry.id);
    final behavior = entry.effectiveResizeBehavior;
    final color = behavior == ResizeBehavior.fixed ? Colors.red : Colors.green;

    final sizeText = controller.getPixelSize(entry.id) != null
        ? '${size!.toInt()}px'
        : controller.getFractionalSize(entry.id) != null
            ? 'flex: ${size!.toStringAsFixed(2)}'
            : entry.initialSize is PaneSizePixel
                ? '${entry.initialSize.size.toInt()}px'
                : 'flex';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _getPaneName(entry.id),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            sizeText,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  String _getPaneName(String id) {
    if (id.startsWith('editor')) {
      final num = id.replaceFirst('editor', '');
      return 'Editor $num';
    }
    return switch (id) {
      'explorer' => 'Explorer',
      'outline' => 'Outline',
      'terminal' => 'Terminal',
      'main' => 'Main',
      _ => id,
    };
  }

  Widget _buildHorizontalPane(String id) {
    if (id.startsWith('editor')) {
      final num = int.tryParse(id.replaceFirst('editor', '')) ?? 0;
      return _buildEditorPanel(num);
    }
    return switch (id) {
      'explorer' => _buildExplorerPanel(),
      'outline' => _buildOutlinePanel(),
      _ => const SizedBox(),
    };
  }

  Widget _buildExplorerPanel() {
    final entry =
        _horizontalController.entries.firstWhere((e) => e.id == 'explorer');
    return _panelContainer(
      color: Colors.green,
      header: 'EXPLORER',
      behavior: entry.effectiveResizeBehavior,
      constraints: 'min: 150 • max: 350',
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          _fileItem(Icons.folder, 'lib', isFolder: true),
          _fileItem(Icons.insert_drive_file, '  main.dart'),
          _fileItem(Icons.insert_drive_file, '  app.dart'),
          _fileItem(Icons.folder, 'test', isFolder: true),
          _fileItem(Icons.insert_drive_file, '  widget_test.dart'),
          _fileItem(Icons.description, 'pubspec.yaml'),
          _fileItem(Icons.description, 'README.md'),
        ],
      ),
    );
  }

  Widget _buildEditorPanel(int index) {
    final id = 'editor$index';
    final entry = _horizontalController.entries
        .where((e) => e.id == id)
        .firstOrNull;
    if (entry == null) return const SizedBox();

    return _panelContainer(
      color: Colors.green,
      header: 'EDITOR $index',
      behavior: entry.effectiveResizeBehavior,
      constraints: 'min: 150 • flex',
      child: Container(
        color: const Color(0xFF1e1e1e),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 1; i <= 15; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        '$i',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        i == 1
                            ? 'import \'package:flutter/material.dart\';'
                            : i == 3
                                ? 'void main() {'
                                : i == 4
                                    ? '  runApp(const MyApp());'
                                    : i == 5
                                        ? '}'
                                        : '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutlinePanel() {
    final entry =
        _horizontalController.entries.firstWhere((e) => e.id == 'outline');
    return _panelContainer(
      color: Colors.red,
      header: 'OUTLINE (FIXED)',
      behavior: entry.effectiveResizeBehavior,
      constraints: 'min: 120 • max: 300',
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          _outlineItem('MyApp', Icons.class_, 0),
          _outlineItem('build()', Icons.functions, 1),
          _outlineItem('HomePage', Icons.class_, 0),
          _outlineItem('_HomePageState', Icons.class_, 1),
          _outlineItem('initState()', Icons.functions, 2),
          _outlineItem('build()', Icons.functions, 2),
        ],
      ),
    );
  }

  Widget _buildTerminalPanel() {
    final entry =
        _verticalController.entries.firstWhere((e) => e.id == 'terminal');
    final editorCount =
        _horizontalEntries.where((e) => e.id.startsWith('editor')).length;

    return _panelContainer(
      color: Colors.green,
      header: 'TERMINAL',
      behavior: entry.effectiveResizeBehavior,
      constraints: 'min: 80 • max: 400',
      child: Container(
        color: const Color(0xFF1e1e1e),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dynamic panel controls
            Row(
              children: [
                Text(
                  '\$ ',
                  style: TextStyle(
                    color: Colors.green[300],
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                _terminalButton(
                  icon: Icons.add,
                  label: 'Add Editor',
                  onPressed: _addEditor,
                ),
                const SizedBox(width: 8),
                _terminalButton(
                  icon: Icons.remove,
                  label: 'Remove Editor',
                  onPressed: editorCount > 1 ? _removeLastEditor : null,
                ),
                const SizedBox(width: 16),
                Text(
                  '($editorCount editors)',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '\$ flutter run',
              style: TextStyle(
                color: Colors.green[300],
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Launching lib/main.dart on macOS in debug mode...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '✓ Built build/macos/Build/Products/Debug/example.app',
              style: TextStyle(
                color: Colors.green[300],
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _terminalButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.cyan[300],
        disabledForegroundColor: Colors.grey[700],
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _panelContainer({
    required Color color,
    required String header,
    required ResizeBehavior behavior,
    required String constraints,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252526),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            ),
            child: Row(
              children: [
                Text(
                  header,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    behavior.name,
                    style: TextStyle(color: color, fontSize: 9),
                  ),
                ),
                const Spacer(),
                Text(
                  constraints,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 9,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _fileItem(IconData icon, String name, {bool isFolder = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isFolder ? Colors.amber : Colors.blue[300],
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _outlineItem(String name, IconData icon, int depth) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 12.0, top: 2, bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.purple[300]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
