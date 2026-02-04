/// Panes Package - Complete API Demonstration
///
/// This example showcases ALL available APIs of the panes package:
///
/// ## IdeLayout & IdeController (High-Level API)
/// - `IdeController` - Manages IDE-like layout with left, right, center, bottom panes
/// - `leftSize`, `rightSize`, `bottomSize` - Initial panel sizing with PaneSize
/// - `toggleLeft()`, `toggleRight()`, `toggleBottom()` - Panel visibility toggles
/// - `save()`, `load()` - Serialize/deserialize layout state
/// - `animationDuration` - Animation timing for panel transitions
///
/// ## MultiPane (Low-Level API)
/// - Core resizable pane widget for custom layouts
/// - `direction` - Axis.horizontal or Axis.vertical
/// - `controller` - PaneController for managing state
/// - `paneBuilder` - Builder for each pane by ID
/// - `animationDuration`, `animationCurve` - Animation configuration
///
/// ## PaneController APIs (via IdeController.rootController & centerController)
/// - `show(id)`, `hide(id)`, `toggle(id)` - Panel visibility control
/// - `isVisible(id)` - Check panel visibility
/// - `maximize(id)`, `restore()`, `toggleMaximize(id)` - Maximize/restore panels
/// - `isMaximized`, `maximizedPaneId` - Maximization state
/// - `updateSize(id, size)` - Programmatic size changes
/// - `resetSize(id)`, `resetAll()` - Reset sizes to initial values
/// - `getPixelSize(id)`, `getFractionalSize(id)` - Query current sizes
/// - `entries` - Access pane configuration list
/// - `dispose()` - Clean up resources (via IdeController.dispose())
///
/// ## PaneSize
/// - `PaneSize.pixel(value)` - Fixed pixel sizing
/// - `PaneSize.fraction(value)` - Flexible/fractional sizing (like Expanded flex)
///
/// ## PaneEntry Configuration
/// - `id`, `initialSize` - Required pane identifiers and sizing
/// - `visible` - Initial visibility state
/// - `minSize`, `maxSize` - Size constraints
/// - `autoHide`, `autoHideThreshold` - Auto-collapse when resized too small
/// - `copyWith()` - Create modified copies
///
/// ## PaneThemeData (full configuration)
/// - `resizerColor`, `resizerHoverColor`, `resizerFocusedColor` - Resizer states
/// - `resizerThickness`, `resizerHitTestThickness` - Resizer dimensions
/// - `tabHeaderColor`, `tabBackground`, `tabSelectedBackground` - Tab colors
/// - `tabLabelColor`, `tabSelectedLabelColor` - Tab text colors
/// - `copyWith()`, `lerp()` - Theme manipulation
/// - Can be used as ThemeExtension or via PaneTheme inherited widget
///
/// ## TabbedPane
/// - `icons`, `labels` - Tab configuration
/// - `selectedIndex`, `onTabSelected` - Tab selection handling
/// - `tabBuilder` - Content builder per tab index
/// - `actions` - Header action widgets (buttons, etc.)
///
/// ## Interactive Features Demonstrated
/// - Drag resizers to resize panels (mouse & keyboard accessibility)
/// - Double-tap resizers to reset sizes to initial values
/// - Resize beyond threshold triggers auto-hide (all panels have autoHide enabled)
/// - Drag-to-reveal: drag resizer from edge to reveal hidden panels
/// - Tab key to focus resizers, arrow keys to resize
/// - Title bar buttons for save/load, reset, and maximize features
/// - Panel headers with maximize and close buttons
library;

import 'package:flutter/material.dart';
import 'package:panes/panes.dart';

import 'cascade_demo.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Panes Example',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF181818),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF181818),
          foregroundColor: Color(0xFFE8E8E8),
          elevation: 0,
        ),
      ),
      home: const IdeExample(),
    );
  }
}

// JetBrains Fleet-inspired color palette (Islands UI)
class IdeColors {
  // Base backgrounds - Fleet uses darker, more neutral tones
  static const background = Color(0xFF181818);
  static const surface = Color(0xFF1E1E1E);
  static const panel = Color(0xFF232324);
  static const panelBorder = Color(0xFF2E2E30);
  static const sidebar = Color(0xFF1E1E1E);
  static const activityBar = Color(0xFF181818);
  static const activityBarActive = Color(0xFF6C6CFF);
  static const tabBar = Color(0xFF232324);
  static const tabActive = Color(0xFF2A2A2C);
  static const tabInactive = Color(0xFF232324);
  static const border = Color(0xFF2E2E30);
  static const statusBar = Color(0xFF181818);
  static const text = Color(0xFFE8E8E8);
  static const textMuted = Color(0xFF7A7A7D);
  static const accent = Color(0xFF6C6CFF);
  static const accentHover = Color(0xFF8585FF);
  static const selection = Color(0xFF3D3D6B);
  static const lineNumber = Color(0xFF5A5A5D);
  static const lineHighlight = Color(0xFF252528);
  static const hover = Color(0xFF2A2A2C);

  // Fleet syntax colors - slightly more vibrant
  static const keyword = Color(0xFFCF8E6D);
  static const string = Color(0xFF6AAB73);
  static const comment = Color(0xFF7A7A7D);
  static const function = Color(0xFF56A8F5);
  static const type = Color(0xFF2AACB8);
  static const number = Color(0xFF2AACB8);
  static const variable = Color(0xFFE8E8E8);
}

class IdeExample extends StatefulWidget {
  const IdeExample({super.key});

  @override
  State<IdeExample> createState() => _IdeExampleState();
}

class _IdeExampleState extends State<IdeExample> {
  late final IdeController _ideController;
  final Duration _animationDuration = const Duration(milliseconds: 200);

  // Tab States
  int _bottomTabIndex = 0;
  int _activityIndex = 0;

  // Editor state
  int _activeEditorTab = 0;
  String _selectedFile = 'main.dart';

  // File tree expansion state
  final Set<String> _expandedFolders = {'lib', 'lib/src'};

  // Saved layout state for demonstrating save/load
  Map<String, dynamic>? _savedLayoutState;

  // Pane visibility state (updated via onPaneStateChanged callback)
  bool _isLeftVisible = true;
  bool _isRightVisible = true;
  bool _isBottomVisible = true;

  // Maximize state (updated via onMaximizeStateChanged callback)
  bool _isEditorMaximized = false;
  bool _isTerminalMaximized = false;

  @override
  void initState() {
    super.initState();
    _ideController = IdeController(
      leftSize: PaneSize.pixel(250),
      leftMinSize: PaneSize.pixel(150),
      leftMaxSize: PaneSize.pixel(500),
      leftResizeBehavior: ResizeBehavior.eager,
      rightSize: PaneSize.pixel(300),
      rightMinSize: PaneSize.pixel(150),
      rightMaxSize: PaneSize.pixel(500),
      rightResizeBehavior: ResizeBehavior.eager,
      bottomSize: PaneSize.fraction(0.5),
      bottomMinSize: PaneSize.pixel(50),
      bottomAutoHide: true,
      bottomAutoHideThreshold: PaneSize.fraction(0.5),
      bottomResizeBehavior: ResizeBehavior.eager,
    );
    // Show panels by default
    _ideController.rootController.show(IdePane.right.id);
    _ideController.centerController.show(IdePane.bottom.id);
  }

  @override
  void dispose() {
    _ideController.dispose();
    super.dispose();
  }

  void _onPaneStateChanged(IdePane pane, bool isVisible) {
    setState(() {
      switch (pane) {
        case IdePane.left:
          _isLeftVisible = isVisible;
        case IdePane.right:
          _isRightVisible = isVisible;
        case IdePane.bottom:
          _isBottomVisible = isVisible;
        case IdePane.center:
        case IdePane.centerContainer:
          // These don't need tracking for toggle icons
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PaneTheme(
      data: const PaneThemeData(
        resizerColor: Colors.transparent,
        resizerHoverColor: IdeColors.accent,
        // Demonstrates keyboard accessibility focus color
        resizerFocusedColor: IdeColors.accentHover,
        resizerThickness: 4.0,
        resizerHitTestThickness: 8.0,
        tabHeaderColor: IdeColors.panel,
        tabBackground: IdeColors.panel,
        tabSelectedBackground: IdeColors.surface,
        tabLabelColor: IdeColors.textMuted,
        tabSelectedLabelColor: IdeColors.text,
      ),
      child: Scaffold(
        body: Container(
          color: IdeColors.background,
          child: Column(
            children: [
              // Title bar - Fleet style (minimal)
              _buildTitleBar(),
              // Main layout with Fleet Islands UI padding
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Row(
                    children: [
                      // Slim navigation rail (Fleet style)
                      _buildNavigationRail(),
                      const SizedBox(width: 8),
                      // Main IDE Layout
                      Expanded(
                        child: IdeLayout(
                          controller: _ideController,
                          animationDuration: _animationDuration,
                          // Use callbacks to update UI state
                          onPaneStateChanged: _onPaneStateChanged,
                          onMaximizeStateChanged: (isMaximized) {
                            setState(() {
                              // Determine which pane is maximized based on
                              // which pane ID is set in each controller
                              if (isMaximized) {
                                final centerMaxId = _ideController
                                    .centerController.maximizedPaneId;
                                if (centerMaxId == IdePane.bottom.id) {
                                  _isTerminalMaximized = true;
                                  _isEditorMaximized = false;
                                } else {
                                  _isEditorMaximized = true;
                                  _isTerminalMaximized = false;
                                }
                              } else {
                                _isEditorMaximized = false;
                                _isTerminalMaximized = false;
                              }
                            });
                          },
                          // Use onSizeChanged callback for realtime size updates
                          onSizeChanged: (pane, size) {
                            setState(() {
                              // Rebuild to update size indicators in title bar
                            });
                          },
                          leftPanelBuilder: (context) => _buildLeftPanel(),
                          rightPanelBuilder: (context) => _buildRightPanel(),
                          bottomPanelBuilder: (context) => _buildBottomPanel(),
                          centerBuilder: (context) => _buildCenterPanel(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar() {
    // Fleet style: minimal title bar integrated with window
    return Container(
      height: 38,
      color: IdeColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const SizedBox(width: 72), // macOS window controls space
          // Layout control buttons demonstrating pane APIs
          _titleBarAction(Icons.save_outlined, 'Save Layout', () {
            _savedLayoutState = _ideController.save();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Layout saved!'),
                duration: Duration(seconds: 1),
              ),
            );
          }),
          _titleBarAction(
            Icons.restore_outlined,
            'Restore Layout',
            _savedLayoutState != null
                ? () {
                    _ideController.load(_savedLayoutState!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Layout restored!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                : null,
          ),
          _titleBarAction(Icons.restart_alt, 'Reset Sizes', () {
            _ideController.rootController.resetSize(IdePane.left.id);
            _ideController.rootController.resetSize(IdePane.right.id);
            _ideController.centerController.resetSize(IdePane.bottom.id);
          }),
          // Fleet uses a command palette style search in the title bar
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                height: 28,
                decoration: BoxDecoration(
                  color: IdeColors.panel,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: IdeColors.border, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.search,
                      size: 14,
                      color: IdeColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedFile,
                      style: const TextStyle(
                        color: IdeColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Cascade demo button
          _titleBarAction(
            Icons.swap_horiz,
            'Cascade Resize Demo',
            () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CascadeDemo()),
            ),
          ),
          const SizedBox(width: 8),
          // Toggle buttons for panels (right side)
          _titleBarAction(
            Icons.terminal,
            _isBottomVisible ? 'Hide Terminal' : 'Show Terminal',
            () => _ideController.toggleBottom(),
          ),
          _titleBarAction(
            Icons.account_tree_outlined,
            _isRightVisible ? 'Hide Structure' : 'Show Structure',
            () => _ideController.toggleRight(),
          ),
          const SizedBox(width: 4),
          // Show current pane sizes (demonstrates getPixelSize API)
          _buildPaneSizeIndicator(),
        ],
      ),
    );
  }

  Widget _titleBarAction(IconData icon, String tooltip, VoidCallback? onTap) {
    final isEnabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 16,
            color: isEnabled ? IdeColors.textMuted : IdeColors.border,
          ),
        ),
      ),
    );
  }

  Widget _buildPaneSizeIndicator() {
    // Demonstrates getPixelSize and getFractionalSize APIs
    final leftSize = _ideController.rootController.getPixelSize(
      IdePane.left.id,
    );
    final rightSize = _ideController.rootController.getPixelSize(
      IdePane.right.id,
    );
    final bottomSize = _ideController.centerController.getPixelSize(
      IdePane.bottom.id,
    );
    final leftVisible = _ideController.rootController.isVisible(
      IdePane.left.id,
    );
    final rightVisible = _ideController.rootController.isVisible(
      IdePane.right.id,
    );
    final bottomVisible = _ideController.centerController.isVisible(
      IdePane.bottom.id,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leftVisible && leftSize != null)
          _sizeChip('L: ${leftSize.toInt()}px'),
        if (rightVisible && rightSize != null)
          _sizeChip('R: ${rightSize.toInt()}px'),
        if (bottomVisible && bottomSize != null)
          _sizeChip('B: ${bottomSize.toInt()}px'),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _sizeChip(String text) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: IdeColors.panel,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: IdeColors.border, width: 1),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: IdeColors.textMuted,
          fontSize: 10,
          fontFamily: 'JetBrains Mono',
        ),
      ),
    );
  }

  Widget _buildNavigationRail() {
    // Fleet style: slim, minimal navigation rail with rounded corners
    return Container(
      width: 44,
      decoration: BoxDecoration(
        color: IdeColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: IdeColors.panelBorder, width: 1),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _navRailItem(Icons.folder_outlined, 0, 'Files'),
          _navRailItem(Icons.search, 1, 'Search'),
          _navRailItem(Icons.account_tree_outlined, 2, 'Git'),
          _navRailItem(Icons.play_arrow_outlined, 3, 'Run'),
          const Spacer(),
          _navRailItem(Icons.settings_outlined, 5, 'Settings'),
        ],
      ),
    );
  }

  Widget _navRailItem(IconData icon, int index, String tooltip) {
    // Nav item is active if it's selected AND the left pane is visible
    final isActive = _activityIndex == index && index < 5 && _isLeftVisible;
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: () {
          setState(() {
            if (index < 5) {
              if (_activityIndex == index) {
                _ideController.toggleLeft();
              } else {
                _activityIndex = index;
                if (!_isLeftVisible) {
                  _ideController.toggleLeft();
                }
              }
            }
          });
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: isActive ? IdeColors.selection : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? IdeColors.text : IdeColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildLeftPanel() {
    // Fleet style: panel with rounded corners (island effect)
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: IdeColors.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: IdeColors.panelBorder, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panel header - Fleet style (simpler)
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(
                    _getActivityTitle(),
                    style: const TextStyle(
                      color: IdeColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  _panelAction(Icons.add, 'New'),
                  _panelAction(Icons.refresh, 'Refresh'),
                  // Demonstrate maximize for left panel
                  Tooltip(
                    message: _ideController.rootController.isMaximized
                        ? 'Restore'
                        : 'Maximize',
                    child: InkWell(
                      onTap: () => _ideController.rootController.toggleMaximize(
                        IdePane.left.id,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          _ideController.rootController.isMaximized
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          size: 16,
                          color: IdeColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  // Demonstrate hide API
                  Tooltip(
                    message: 'Close Panel',
                    child: InkWell(
                      onTap: () => _ideController.toggleLeft(),
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: IdeColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // File tree
            Expanded(child: _buildFileTree()),
          ],
        ),
      ),
    );
  }

  String _getActivityTitle() {
    switch (_activityIndex) {
      case 0:
        return 'Files';
      case 1:
        return 'Search';
      case 2:
        return 'Git';
      case 3:
        return 'Run';
      case 4:
        return 'Extensions';
      default:
        return 'Files';
    }
  }

  Widget _panelAction(IconData icon, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: IdeColors.textMuted),
        ),
      ),
    );
  }

  Widget _buildFileTree() {
    return ListView(
      padding: const EdgeInsets.only(left: 8),
      children: [
        _folderItem('lib', 0),
        if (_expandedFolders.contains('lib')) ...[
          _folderItem('src', 1, parent: 'lib'),
          if (_expandedFolders.contains('lib/src')) ...[
            _fileItem('ide_layout.dart', 2),
            _fileItem('multi_pane.dart', 2),
            _fileItem('pane_controller.dart', 2),
            _fileItem('pane_entry.dart', 2),
            _fileItem('pane_size.dart', 2),
            _fileItem('pane_theme.dart', 2),
            _fileItem('resizer.dart', 2),
            _fileItem('tabbed_pane.dart', 2),
          ],
          _fileItem('main.dart', 1),
        ],
        _folderItem('test', 0),
        _fileItem('pubspec.yaml', 0),
        _fileItem('README.md', 0),
        _fileItem('.gitignore', 0),
      ],
    );
  }

  Widget _folderItem(String name, int depth, {String? parent}) {
    final fullPath = parent != null ? '$parent/$name' : name;
    final isExpanded = _expandedFolders.contains(fullPath);

    return InkWell(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedFolders.remove(fullPath);
          } else {
            _expandedFolders.add(fullPath);
          }
        });
      },
      child: Container(
        height: 22,
        padding: EdgeInsets.only(left: depth * 16.0 + 4),
        child: Row(
          children: [
            Icon(
              isExpanded ? Icons.expand_more : Icons.chevron_right,
              size: 16,
              color: IdeColors.textMuted,
            ),
            const SizedBox(width: 4),
            Icon(
              isExpanded ? Icons.folder_open : Icons.folder,
              size: 16,
              color: const Color(0xFFDCB67A),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: const TextStyle(color: IdeColors.text, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileItem(String name, int depth) {
    final isSelected = _selectedFile == name;
    final icon = _getFileIcon(name);
    final iconColor = _getFileIconColor(name);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFile = name;
        });
      },
      child: Container(
        height: 22,
        padding: EdgeInsets.only(left: depth * 16.0 + 24),
        decoration: BoxDecoration(
          color: isSelected ? IdeColors.selection : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : IdeColors.text,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String name) {
    if (name.endsWith('.dart')) return Icons.code;
    if (name.endsWith('.yaml') || name.endsWith('.yml')) return Icons.settings;
    if (name.endsWith('.md')) return Icons.description;
    if (name.startsWith('.')) return Icons.settings;
    return Icons.insert_drive_file;
  }

  Color _getFileIconColor(String name) {
    if (name.endsWith('.dart')) return IdeColors.type;
    if (name.endsWith('.yaml') || name.endsWith('.yml')) {
      return IdeColors.keyword;
    }
    if (name.endsWith('.md')) return IdeColors.function;
    return IdeColors.textMuted;
  }

  Widget _buildCenterPanel() {
    // Fleet style: editor with rounded corners
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: IdeColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: IdeColors.panelBorder, width: 1),
        ),
        child: Column(
          children: [
            // Editor tabs
            _buildEditorTabs(),
            // Code editor (no breadcrumb - Fleet is minimal)
            Expanded(child: _buildCodeEditor()),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorTabs() {
    final tabs = ['main.dart', 'pane_theme.dart'];

    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: IdeColors.panel,
        border: Border(
          bottom: BorderSide(color: IdeColors.panelBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++) _editorTab(tabs[i], i),
          const Spacer(),
          // Maximize editor button
          Tooltip(
            message: _isEditorMaximized ? 'Restore' : 'Maximize',
            child: InkWell(
              onTap: () {
                _ideController.rootController.toggleMaximize(
                  IdePane.centerContainer.id,
                );
                _ideController.centerController.toggleMaximize(
                  IdePane.center.id,
                );
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  _isEditorMaximized ? Icons.fullscreen_exit : Icons.fullscreen,
                  size: 16,
                  color: IdeColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _editorTab(String name, int index) {
    final isActive = _activeEditorTab == index;

    return GestureDetector(
      onTap: () => setState(() => _activeEditorTab = index),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        margin: const EdgeInsets.only(top: 4, left: 4),
        decoration: BoxDecoration(
          color: isActive ? IdeColors.surface : Colors.transparent,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.code, size: 14, color: const Color(0xFF2AACB8)),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                color: isActive ? IdeColors.text : IdeColors.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            if (isActive)
              InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(4),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: IdeColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeEditor() {
    final lines = _getCodeForFile(_selectedFile);

    return Container(
      color: IdeColors.background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line numbers + Code content (scrolls together)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line numbers
                  SizedBox(
                    width: 50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(
                        lines.length,
                        (i) => Container(
                          height: 20,
                          padding: const EdgeInsets.only(right: 12),
                          color: i == 4 ? IdeColors.lineHighlight : null,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: i == 4
                                  ? IdeColors.text
                                  : IdeColors.lineNumber,
                              fontSize: 13,
                              fontFamily: 'JetBrains Mono',
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Code content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < lines.length; i++)
                          Container(
                            height: 20,
                            padding: const EdgeInsets.only(left: 4),
                            color: i == 4 ? IdeColors.lineHighlight : null,
                            child: lines[i],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Minimap
          Container(
            width: 80,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: IdeColors.sidebar.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Column(
              children: [
                Container(
                  height: 20,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: IdeColors.selection.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _getCodeForFile(String filename) {
    if (filename == 'main.dart' || filename.endsWith('.dart')) {
      return [
        _codeLine([
          _keyword('import'),
          _plain(' '),
          _string("'package:flutter/material.dart'"),
          _plain(';'),
        ]),
        _codeLine([
          _keyword('import'),
          _plain(' '),
          _string("'package:panes/panes.dart'"),
          _plain(';'),
        ]),
        _codeLine([]),
        _codeLine([
          _keyword('void'),
          _plain(' '),
          _function('main'),
          _plain('() {'),
        ]),
        _codeLine([
          _plain('  '),
          _function('runApp'),
          _plain('('),
          _keyword('const'),
          _plain(' '),
          _type('MyApp'),
          _plain('());'),
        ]),
        _codeLine([_plain('}')]),
        _codeLine([]),
        _codeLine([
          _keyword('class'),
          _plain(' '),
          _type('MyApp'),
          _plain(' '),
          _keyword('extends'),
          _plain(' '),
          _type('StatelessWidget'),
          _plain(' {'),
        ]),
        _codeLine([
          _plain('  '),
          _keyword('const'),
          _plain(' '),
          _type('MyApp'),
          _plain('({'),
          _keyword('super'),
          _plain('.key});'),
        ]),
        _codeLine([]),
        _codeLine([_plain('  '), _keyword('@override')]),
        _codeLine([
          _plain('  '),
          _type('Widget'),
          _plain(' '),
          _function('build'),
          _plain('('),
          _type('BuildContext'),
          _plain(' context) {'),
        ]),
        _codeLine([
          _plain('    '),
          _keyword('return'),
          _plain(' '),
          _type('MaterialApp'),
          _plain('('),
        ]),
        _codeLine([
          _plain('      title: '),
          _string("'Panes Example'"),
          _plain(','),
        ]),
        _codeLine([
          _plain('      home: '),
          _keyword('const'),
          _plain(' '),
          _type('IdeExample'),
          _plain('(),'),
        ]),
        _codeLine([_plain('    );')]),
        _codeLine([_plain('  }')]),
        _codeLine([_plain('}')]),
        _codeLine([]),
        _codeLine([_comment('// Enhanced IDE layout demonstration')]),
      ];
    } else if (filename == 'pubspec.yaml') {
      return [
        _codeLine([_variable('name'), _plain(': '), _string('panes_example')]),
        _codeLine([
          _variable('description'),
          _plain(': '),
          _string('A demo of the panes package'),
        ]),
        _codeLine([_variable('version'), _plain(': '), _string('1.0.0')]),
        _codeLine([]),
        _codeLine([_variable('environment'), _plain(':')]),
        _codeLine([
          _plain('  '),
          _variable('sdk'),
          _plain(': '),
          _string("'>=3.0.0 <4.0.0'"),
        ]),
      ];
    }
    return [
      _codeLine([_comment('// Select a file to view')]),
    ];
  }

  Widget _codeLine(List<Widget> spans) {
    return Row(children: spans.isEmpty ? [const SizedBox(height: 20)] : spans);
  }

  Widget _keyword(String text) => Text(
        text,
        style: const TextStyle(
          color: IdeColors.keyword,
          fontSize: 13,
          fontFamily: 'JetBrains Mono',
          height: 1.5,
        ),
      );
  Widget _string(String text) => Text(
        text,
        style: const TextStyle(
          color: IdeColors.string,
          fontSize: 13,
          fontFamily: 'JetBrains Mono',
          height: 1.5,
        ),
      );
  Widget _comment(String text) => Text(
        text,
        style: const TextStyle(
          color: IdeColors.comment,
          fontSize: 13,
          fontFamily: 'JetBrains Mono',
          height: 1.5,
        ),
      );
  Widget _function(String text) => Text(
        text,
        style: const TextStyle(
          color: IdeColors.function,
          fontSize: 13,
          fontFamily: 'JetBrains Mono',
          height: 1.5,
        ),
      );
  Widget _type(String text) => Text(
        text,
        style: const TextStyle(
          color: IdeColors.type,
          fontSize: 13,
          fontFamily: 'JetBrains Mono',
          height: 1.5,
        ),
      );
  Widget _variable(String text) => Text(
        text,
        style: const TextStyle(
          color: IdeColors.variable,
          fontSize: 13,
          fontFamily: 'JetBrains Mono',
          height: 1.5,
        ),
      );
  Widget _plain(String text) => Text(
        text,
        style: const TextStyle(
          color: IdeColors.text,
          fontSize: 13,
          fontFamily: 'JetBrains Mono',
          height: 1.5,
        ),
      );

  Widget _buildRightPanel() {
    // Fleet style: outline panel with rounded corners
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: IdeColors.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: IdeColors.panelBorder, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Text(
                    'Structure',
                    style: TextStyle(
                      color: IdeColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  _panelAction(Icons.filter_list, 'Filter'),
                  // Demonstrate maximize for right panel
                  Tooltip(
                    message: _ideController.rootController.isMaximized
                        ? 'Restore'
                        : 'Maximize',
                    child: InkWell(
                      onTap: () => _ideController.rootController.toggleMaximize(
                        IdePane.right.id,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          _ideController.rootController.isMaximized
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          size: 16,
                          color: IdeColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  // Demonstrate hide API
                  Tooltip(
                    message: 'Close Panel',
                    child: InkWell(
                      onTap: () => _ideController.toggleRight(),
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: IdeColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _outlineItem('MyApp', Icons.class_, 0),
                  _outlineItem('build()', Icons.functions, 1),
                  _outlineItem('IdeExample', Icons.class_, 0),
                  _outlineItem('_IdeExampleState', Icons.class_, 1),
                  _outlineItem('build()', Icons.functions, 2),
                  _outlineItem('_buildFileTree()', Icons.functions, 2),
                  _outlineItem('_buildCodeEditor()', Icons.functions, 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outlineItem(String name, IconData icon, int depth) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 12.0, top: 4, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: IdeColors.accent),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(color: IdeColors.text, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    // Fleet style: wrap TabbedPane in rounded container
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: IdeColors.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: IdeColors.panelBorder, width: 1),
        ),
        child: TabbedPane(
          selectedIndex: _bottomTabIndex,
          onTabSelected: (index) => setState(() => _bottomTabIndex = index),
          labels: const ['Terminal', 'Problems', 'Output', 'Debug'],
          icons: const [
            Icons.terminal,
            Icons.error_outline,
            Icons.text_snippet,
            Icons.bug_report,
          ],
          actions: [
            _panelAction(Icons.add, 'New Terminal'),
            _panelAction(Icons.splitscreen, 'Split'),
            const SizedBox(width: 4),
            // Demonstrate maximize/restore for bottom panel (full maximize)
            Tooltip(
              message: _isTerminalMaximized ? 'Restore' : 'Maximize',
              child: InkWell(
                onTap: () {
                  // Maximize both controllers for true full-screen terminal
                  _ideController.rootController.toggleMaximize(
                    IdePane.centerContainer.id,
                  );
                  _ideController.centerController.toggleMaximize(
                    IdePane.bottom.id,
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _isTerminalMaximized
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen,
                    size: 16,
                    color: IdeColors.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => _ideController.toggleBottom(),
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: IdeColors.textMuted),
              ),
            ),
            const SizedBox(width: 8),
          ],
          tabBuilder: (context, index) {
            if (index == 0) return _buildTerminalContent();
            return _buildPlaceholderContent(index);
          },
        ),
      ),
    );
  }

  Widget _buildTerminalContent() {
    return Container(
      color: IdeColors.surface,
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _terminalLine(
              'simon@macbook',
              'panes %',
              'flutter run -d macos',
              isPrompt: true,
            ),
            const SizedBox(height: 4),
            _terminalOutput(
              'Launching lib/main.dart on macOS in debug mode...',
              IdeColors.text,
            ),
            _terminalOutput('Building macOS application...', IdeColors.text),
            const SizedBox(height: 4),
            _terminalOutput(
              '✓ Built build/macos/Build/Products/Debug/example.app',
              IdeColors.string,
            ),
            const SizedBox(height: 8),
            _terminalOutput('Syncing files to device macOS...', IdeColors.text),
            _terminalOutput('  4,521ms (!) ', IdeColors.keyword),
            const SizedBox(height: 8),
            _terminalOutput('Flutter run key commands.', IdeColors.textMuted),
            _terminalOutput('r  Hot reload. 🔥🔥🔥', IdeColors.textMuted),
            _terminalOutput('R  Hot restart.', IdeColors.textMuted),
            _terminalOutput('q  Quit.', IdeColors.textMuted),
            const SizedBox(height: 16),
            _terminalLine('simon@macbook', 'panes %', '', isPrompt: true),
          ],
        ),
      ),
    );
  }

  Widget _terminalLine(
    String user,
    String path,
    String command, {
    bool isPrompt = false,
  }) {
    return Row(
      children: [
        Text(
          user,
          style: const TextStyle(
            color: IdeColors.string,
            fontSize: 12,
            fontFamily: 'JetBrains Mono',
          ),
        ),
        const Text(' ', style: TextStyle(fontSize: 12)),
        Text(
          path,
          style: const TextStyle(
            color: IdeColors.function,
            fontSize: 12,
            fontFamily: 'JetBrains Mono',
          ),
        ),
        const Text(' ', style: TextStyle(fontSize: 12)),
        Text(
          command,
          style: const TextStyle(
            color: IdeColors.text,
            fontSize: 12,
            fontFamily: 'JetBrains Mono',
          ),
        ),
        if (isPrompt && command.isEmpty)
          Container(width: 8, height: 14, color: IdeColors.accent),
      ],
    );
  }

  Widget _terminalOutput(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 0),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontFamily: 'JetBrains Mono',
        ),
      ),
    );
  }

  Widget _buildPlaceholderContent(int index) {
    String text;
    switch (index) {
      case 1:
        text = 'No problems have been detected in the workspace.';
        break;
      case 2:
        text = 'Output currently empty.';
        break;
      case 3:
        text = 'Debug console ready.';
        break;
      default:
        text = 'Empty';
    }

    return Container(
      color: IdeColors.background,
      padding: const EdgeInsets.all(12),
      alignment: Alignment.topLeft,
      child: Text(
        text,
        style: const TextStyle(color: IdeColors.textMuted, fontSize: 13),
      ),
    );
  }
}
