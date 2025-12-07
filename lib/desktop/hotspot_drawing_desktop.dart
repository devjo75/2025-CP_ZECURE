import 'package:flutter/material.dart';

// ============================================
// DESKTOP HOTSPOT CREATION DIALOG
// ============================================

/// Desktop-optimized dialog for choosing hotspot creation mode
class HotspotCreationModeDialogDesktop extends StatelessWidget {
  final Function(String mode) onModeSelected;

  const HotspotCreationModeDialogDesktop({
    super.key,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.add_location_alt,
                        color: Colors.red.shade600,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Crime Hotspot',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Choose how to define the hotspot area',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Mode options in vertical layout
                _DesktopModeCard(
                  icon: Icons.circle_outlined,
                  iconColor: Colors.blue,
                  title: 'Circular Zone',
                  description:
                      'Quick and simple. Define a danger area using a center point and radius.',
                  features: const [
                    'Fast setup',
                    'Radius-based',
                    'Ideal for incidents',
                  ],
                  onTap: () {
                    Navigator.pop(context);
                    onModeSelected('circular');
                  },
                ),

                const SizedBox(height: 12),

                _DesktopModeCard(
                  icon: Icons.pentagon_outlined,
                  iconColor: Colors.purple,
                  title: 'Custom Polygon',
                  description:
                      'Draw precise boundaries by tapping 3 or more points on the map.',
                  features: const [
                    'Precise boundaries',
                    'Flexible shapes',
                    'Complex areas',
                  ],
                  recommended: true,
                  onTap: () {
                    Navigator.pop(context);
                    onModeSelected('polygon');
                  },
                ),

                const SizedBox(height: 20),

                // Info banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Hotspot zones help users avoid dangerous areas when planning routes',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopModeCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final List<String> features;
  final bool recommended;
  final VoidCallback? onTap;

  const _DesktopModeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.features,
    this.recommended = false,
    this.onTap,
  });

  @override
  State<_DesktopModeCard> createState() => _DesktopModeCardState();
}

class _DesktopModeCardState extends State<_DesktopModeCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onTap == null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDisabled
                ? Colors.grey.shade100
                : _isHovered
                ? widget.iconColor.withOpacity(0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDisabled
                  ? Colors.grey.shade300
                  : _isHovered
                  ? widget.iconColor
                  : Colors.grey.shade300,
              width: _isHovered && !isDisabled ? 2 : 1,
            ),
            boxShadow: _isHovered && !isDisabled
                ? [
                    BoxShadow(
                      color: widget.iconColor.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDisabled
                      ? Colors.grey.shade300
                      : widget.iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.icon,
                  color: isDisabled ? Colors.grey.shade500 : widget.iconColor,
                  size: 28,
                ),
              ),

              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and badge
                    Row(
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDisabled ? Colors.grey : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (widget.recommended)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Recommended',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Description
                    Text(
                      widget.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDisabled ? Colors.grey : Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Features
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: widget.features.map((feature) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: isDisabled
                                  ? Colors.grey.shade400
                                  : widget.iconColor.withOpacity(0.7),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              feature,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDisabled
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // Arrow icon
              if (!isDisabled) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: _isHovered ? widget.iconColor : Colors.grey.shade400,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// DESKTOP DRAWING CONTROLS
// ============================================

class HotspotDrawingControlsDesktop extends StatelessWidget {
  final int vertexCount;
  final VoidCallback onUndo;
  final VoidCallback onCancel;
  final VoidCallback onComplete;
  final bool canComplete;

  const HotspotDrawingControlsDesktop({
    super.key,
    required this.vertexCount,
    required this.onUndo,
    required this.onCancel,
    required this.onComplete,
    required this.canComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.edit_location_alt,
                          color: Colors.red.shade600,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Drawing Hotspot Zone',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$vertexCount point${vertexCount != 1 ? 's' : ''} added (min. 3 required)',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Click on the map to add boundary points',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      // Undo button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: vertexCount > 0 ? onUndo : null,
                          icon: const Icon(Icons.undo, size: 20),
                          label: const Text('Undo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade600,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Cancel button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onCancel,
                          icon: const Icon(Icons.close, size: 20),
                          label: const Text('Cancel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Complete button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: canComplete ? onComplete : null,
                          icon: const Icon(Icons.check_circle, size: 20),
                          label: const Text('Complete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
