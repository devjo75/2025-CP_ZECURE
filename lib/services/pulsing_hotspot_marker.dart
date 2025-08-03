import 'package:flutter/material.dart';

class PulsingHotspotMarker extends StatefulWidget {
  final Color markerColor;
  final IconData markerIcon;
  final bool isActive;
  final VoidCallback onTap;

  const PulsingHotspotMarker({
    super.key,
    required this.markerColor,
    required this.markerIcon,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<PulsingHotspotMarker> createState() => _PulsingHotspotMarkerState();
}

class _PulsingHotspotMarkerState extends State<PulsingHotspotMarker>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOut,
    ));

    // Start pulsing only for active hotspots
    if (widget.isActive) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(PulsingHotspotMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update animation based on active status
    if (widget.isActive && !oldWidget.isActive) {
      _pulseController.repeat();
    } else if (!widget.isActive && oldWidget.isActive) {
      _pulseController.stop();
      _pulseController.reset();
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
      child: widget.isActive
          ? AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulse ring
                    Container(
                      width: 40 + (_pulseAnimation.value * 20),
                      height: 40 + (_pulseAnimation.value * 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.markerColor.withOpacity(
                          0.3 * (1 - _pulseAnimation.value),
                        ),
                        border: Border.all(
                          color: widget.markerColor.withOpacity(
                            0.6 * (1 - _pulseAnimation.value),
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                    // Main marker
                    Container(
                      width: 40,
                      height: 40,
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
                );
              },
            )
          : Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.markerColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: Icon(
                widget.markerIcon,
                color: Colors.white,
                size: 20,
              ),
            ),
    );
  }
}