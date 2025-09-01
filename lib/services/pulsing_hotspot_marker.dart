import 'package:flutter/material.dart';

class PulsingHotspotMarker extends StatefulWidget {
  final Color markerColor;
  final IconData markerIcon;
  final bool isActive;
  final VoidCallback onTap;
  final double pulseScale;

  const PulsingHotspotMarker({
    super.key,
    required this.markerColor,
    required this.markerIcon,
    required this.isActive,
    required this.onTap,
    required this.pulseScale,
  });

  // CRITICAL: Add equality operators to prevent unnecessary rebuilds
  @override
  // ignore: invalid_override_of_non_virtual_member
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is PulsingHotspotMarker &&
    runtimeType == other.runtimeType &&
    markerColor == other.markerColor &&
    markerIcon == other.markerIcon &&
    isActive == other.isActive &&
    pulseScale == other.pulseScale;

  @override
  // ignore: invalid_override_of_non_virtual_member
  int get hashCode => Object.hash(markerColor, markerIcon, isActive, pulseScale);

  @override
  State<PulsingHotspotMarker> createState() => _PulsingHotspotMarkerState();
}

class _PulsingHotspotMarkerState extends State<PulsingHotspotMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000), // Slower, smoother pulse
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut, // Smoother curve
    ));

    // Start pulsing only for active hotspots
    if (widget.isActive) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(PulsingHotspotMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Only update animation if active status actually changed
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _pulseController.repeat();
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        // CRITICAL: Fixed container size prevents position shifting
        width: 80, // Fixed width that accommodates largest pulse
        height: 80, // Fixed height that accommodates largest pulse
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulse animation only for active markers
            if (widget.isActive)
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    // FIXED: Use fixed base size + animation offset
                    width: 40 + (_pulseAnimation.value * 15), // Reduced pulse range
                    height: 40 + (_pulseAnimation.value * 15), // Reduced pulse range
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.markerColor.withOpacity(
                        0.2 * (1 - _pulseAnimation.value), // Gentler opacity change
                      ),
                      border: Border.all(
                        color: widget.markerColor.withOpacity(
                          0.4 * (1 - _pulseAnimation.value), // Gentler border opacity
                        ),
                        width: 1,
                      ),
                    ),
                  );
                },
              ),
            
            // MAIN MARKER - Always same size and position
            Container(
              width: 40, // Fixed size
              height: 40, // Fixed size
              decoration: BoxDecoration(
                color: widget.markerColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                widget.markerIcon,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}