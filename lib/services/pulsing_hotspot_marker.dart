import 'package:flutter/material.dart';

class PulsingHotspotMarker extends StatefulWidget {
  final Color markerColor;
  final IconData markerIcon;
  final bool isActive;
  final VoidCallback onTap;
  final double pulseScale;
  final String crimeLevel;

  const PulsingHotspotMarker({
    super.key,
    required this.markerColor,
    required this.markerIcon,
    required this.isActive,
    required this.onTap,
    required this.pulseScale,
    this.crimeLevel = 'low',
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
    pulseScale == other.pulseScale &&
    crimeLevel == other.crimeLevel;

  @override
  // ignore: invalid_override_of_non_virtual_member
  int get hashCode => Object.hash(markerColor, markerIcon, isActive, pulseScale, crimeLevel);

  @override
  State<PulsingHotspotMarker> createState() => _PulsingHotspotMarkerState();
}

class _PulsingHotspotMarkerState extends State<PulsingHotspotMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Get pulse configuration based on crime level
  _PulseConfig _getPulseConfig() {
    switch (widget.crimeLevel.toLowerCase()) {
      case 'critical':
        return _PulseConfig(
          duration: 800,  // Fastest
          pulseSize: 50.0, // Dramatically larger pulse
          opacity: 0.38,   // More visible
          pulseCount: 3,   // Multiple rings
        );
      case 'high':
        return _PulseConfig(
          duration: 1200,
          pulseSize: 32.0, // Significantly larger
          opacity: 0.30,
          pulseCount: 2,
        );
      case 'medium':
        return _PulseConfig(
          duration: 1800,
          pulseSize: 20.0, // Moderately larger
          opacity: 0.24,
          pulseCount: 2,
        );
      case 'low':
      default:
        return _PulseConfig(
          duration: 2400,  // Slowest
          pulseSize: 14.0, // Slightly larger
          opacity: 0.20,   // Slightly more visible
          pulseCount: 1,   // Single ring
        );
    }
  }

  @override
  void initState() {
    super.initState();
    _initializePulse();
  }

  void _initializePulse() {
    final config = _getPulseConfig();
    
    // Initialize pulse animation with dynamic duration
    _pulseController = AnimationController(
      duration: Duration(milliseconds: config.duration),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Start pulsing only for active hotspots
    if (widget.isActive) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(PulsingHotspotMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Reinitialize if crime level changed
    if (widget.crimeLevel != oldWidget.crimeLevel) {
      _pulseController.dispose();
      _initializePulse();
    }
    
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
    final config = _getPulseConfig();
    
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        // CRITICAL: Larger fixed container to accommodate bigger pulses
        width: 100,
        height: 100,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Multiple pulse rings for higher severity crimes
            if (widget.isActive)
              ...List.generate(config.pulseCount, (index) {
                // Stagger the pulses for dramatic effect
                final delay = index * (1.0 / config.pulseCount);
                
                return AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    // Calculate staggered animation value
                    final staggeredValue = (_pulseAnimation.value + delay) % 1.0;
                    
                    // Use easeOut curve for more dramatic expansion
                    final easedValue = Curves.easeOut.transform(staggeredValue);
                    
                    return Container(
                      width: 40 + (easedValue * config.pulseSize),
                      height: 40 + (easedValue * config.pulseSize),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.markerColor.withOpacity(
                          config.opacity * (1 - easedValue),
                        ),
                        border: Border.all(
                          color: widget.markerColor.withOpacity(
                            (config.opacity * 1.5) * (1 - easedValue),
                          ),
                          width: widget.crimeLevel == 'critical' ? 2.0 : 1.0,
                        ),
                      ),
                    );
                  },
                );
              }),
            
            // MAIN MARKER - Always same size and position
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
                  // Add glow for critical crimes
                  if (widget.crimeLevel == 'critical')
                    BoxShadow(
                      color: widget.markerColor.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
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

// Configuration class for pulse parameters
class _PulseConfig {
  final int duration;      // Animation duration in ms
  final double pulseSize;  // Maximum pulse expansion
  final double opacity;    // Base opacity for pulses
  final int pulseCount;    // Number of pulse rings

  _PulseConfig({
    required this.duration,
    required this.pulseSize,
    required this.opacity,
    required this.pulseCount,
  });
}