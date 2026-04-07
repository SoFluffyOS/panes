library;

import 'package:flutter/material.dart';
import 'package:panes/panes.dart';

/// Flat "No-Islands" Dashboard Demo
///
/// Showcases a true pixel-perfect flat layout where panels have absolutely
/// zero spacing or margins.
class ZeroSpaceResizerDemo extends StatefulWidget {
  const ZeroSpaceResizerDemo({super.key});

  @override
  State<ZeroSpaceResizerDemo> createState() => _ZeroSpaceResizerDemoState();
}

class _ZeroSpaceResizerDemoState extends State<ZeroSpaceResizerDemo> {
  late PaneController _horizontalController;
  late PaneController _verticalController;

  @override
  void initState() {
    super.initState();
    _horizontalController = PaneController(
      entries: [
        PaneEntry(
          id: 'sidebar',
          initialSize: PaneSize.pixel(220),
          minSize: PaneSize.pixel(150),
          maxSize: PaneSize.pixel(300),
        ),
        PaneEntry(
          id: 'main',
          initialSize: PaneSize.fraction(1.0),
          minSize: PaneSize.pixel(300),
        ),
        PaneEntry(
          id: 'details',
          initialSize: PaneSize.pixel(280),
          minSize: PaneSize.pixel(200),
          maxSize: PaneSize.pixel(500),
        ),
      ],
    );

    _verticalController = PaneController(
      entries: [
        PaneEntry(
          id: 'chart',
          initialSize: PaneSize.fraction(0.55),
          minSize: PaneSize.pixel(200),
        ),
        PaneEntry(
          id: 'data',
          initialSize: PaneSize.fraction(0.45),
          minSize: PaneSize.pixel(150),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PaneTheme(
      data: const PaneThemeData(
        resizerThickness: 0.0,
        resizerHitTestThickness: 16.0,
        resizerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF141414),
        appBar: AppBar(
          title: const Text('Flat Dashboard', style: TextStyle(fontSize: 14)),
          backgroundColor: const Color(0xFF1E1E1E),
          elevation: 0,
        ),
        body: MultiPane(
          controller: _horizontalController,
          direction: Axis.horizontal,
          paneBuilder: (context, id, _) {
            switch (id) {
              case 'sidebar':
                return _buildSidebar();
              case 'main':
                return MultiPane(
                  controller: _verticalController,
                  direction: Axis.vertical,
                  paneBuilder: (context, vId, _) {
                    return vId == 'chart'
                        ? _buildChartPanel()
                        : _buildDataPanel();
                  },
                );
              case 'details':
                return _buildDetailsPanel();
              default:
                return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: const Color(0xFF161616),
      child: const Column(
        children: [
          _PanelHeader(title: 'NAVIGATION'),
          _SidebarItem(
            icon: Icons.analytics,
            label: 'Analytics',
            isActive: true,
          ),
          _SidebarItem(icon: Icons.inventory_2_outlined, label: 'Resources'),
          _SidebarItem(icon: Icons.people_outline, label: 'Audience'),
          _SidebarItem(icon: Icons.campaign_outlined, label: 'Campaigns'),
        ],
      ),
    );
  }

  Widget _buildChartPanel() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(title: 'PERFORMANCE VELOCITY'),
          Expanded(
            child: Center(
              child: Text(
                "[ Main Chart Visualization ]",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white30, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataPanel() {
    return Container(
      color: const Color(0xFF181818),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(title: 'TRANSACTION FEED'),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: 20,
              itemBuilder: (context, index) {
                return Container(
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1C1C1C),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF2A2A2A)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Text(
                        'TXN-${9400 + index}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '\$${(120.5 + index * 10).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel() {
    return Container(
      color: const Color(0xFF161616),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(title: 'PROPERTIES OVERVIEW'),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STATUS',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Active Deployment',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Text(
                  'LAST DEPLOY',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Today, 14:22 PT',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final String title;

  const _PanelHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      color: const Color(0xFF202020),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 10,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _SidebarItem({
    required this.icon,
    required this.label,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.white : Colors.white54;
    return Container(
      height: 40,
      color: isActive ? const Color(0xFF2A2A2A) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
