import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:zecure/services/crime_heatmap_service.dart';

/// A proper GIS-style thermal heatmap layer for crime data
/// Uses radial gradients to create smooth heat distribution
class CrimeHeatmapLayer extends StatelessWidget {
  final List<HeatmapPoint> points;
  final HeatmapConfig config;
  final double currentZoom;

  const CrimeHeatmapLayer({
    Key? key,
    required this.points,
    required this.config,
    required this.currentZoom,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    return MarkerLayer(
      markers: points.map((point) {
        return Marker(
          point: point.location,
          width: config.radius * 2,
          height: config.radius * 2,
          child: _HeatmapGradientCircle(
            radius: config.radius,
            blur: config.blur,
            intensity: point.weight,
            maxOpacity: config.maxOpacity,
            minOpacity: config.minOpacity,
          ),
        );
      }).toList(),
    );
  }
}

/// Individual heat gradient circle
/// Creates a radial gradient from hot (center) to cool (edges)
class _HeatmapGradientCircle extends StatelessWidget {
  final double radius;
  final double blur;
  final double intensity; // 0.0 to 1.0
  final double maxOpacity;
  final double minOpacity;

  const _HeatmapGradientCircle({
    required this.radius,
    required this.blur,
    required this.intensity,
    required this.maxOpacity,
    required this.minOpacity,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(radius * 2, radius * 2),
      painter: _HeatmapCirclePainter(
        radius: radius,
        blur: blur,
        intensity: intensity,
        maxOpacity: maxOpacity,
        minOpacity: minOpacity,
      ),
    );
  }
}

/// Custom painter for thermal gradient circles
/// Implements the thermal color scheme: blue → green → yellow → orange → red
class _HeatmapCirclePainter extends CustomPainter {
  final double radius;
  final double blur;
  final double intensity;
  final double maxOpacity;
  final double minOpacity;

  _HeatmapCirclePainter({
    required this.radius,
    required this.blur,
    required this.intensity,
    required this.maxOpacity,
    required this.minOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(radius, radius);

    // Create radial gradient with thermal color scheme
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: _getThermalColors(intensity),
      stops: _getThermalStops(),
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

    canvas.drawCircle(center, radius, paint);
  }

  /// Returns thermal gradient colors based on intensity
  /// Higher intensity = hotter colors (yellow, orange, red)
  /// Lower intensity = cooler colors (blue, green)
  List<Color> _getThermalColors(double intensity) {
    // Base thermal gradient: blue → green → yellow → orange → red
    final baseColors = [
      const Color(0x00000000), // Transparent edge
      _getColorForIntensity(intensity, 0.2),
      _getColorForIntensity(intensity, 0.5),
      _getColorForIntensity(intensity, 0.8),
      _getColorForIntensity(intensity, 1.0),
    ];

    return baseColors;
  }

  /// Gets the thermal color for a given intensity and position in gradient
  Color _getColorForIntensity(double intensity, double position) {
    // Calculate effective heat value
    final heat = intensity * position;

    Color baseColor;
    double alpha;

    if (heat < 0.2) {
      // Cool - blue
      baseColor = const Color(0xFF0000FF);
      alpha = minOpacity + (heat / 0.2) * (maxOpacity - minOpacity) * 0.3;
    } else if (heat < 0.4) {
      // Cool-medium - blue to cyan
      final t = (heat - 0.2) / 0.2;
      baseColor = Color.lerp(
        const Color(0xFF0000FF), // Blue
        const Color(0xFF00FFFF), // Cyan
        t,
      )!;
      alpha = minOpacity + (maxOpacity - minOpacity) * 0.4;
    } else if (heat < 0.6) {
      // Medium - cyan to green to yellow
      final t = (heat - 0.4) / 0.2;
      baseColor = Color.lerp(
        const Color(0xFF00FFFF), // Cyan
        const Color(0xFFFFFF00), // Yellow
        t,
      )!;
      alpha = minOpacity + (maxOpacity - minOpacity) * 0.6;
    } else if (heat < 0.8) {
      // Hot - yellow to orange
      final t = (heat - 0.6) / 0.2;
      baseColor = Color.lerp(
        const Color(0xFFFFFF00), // Yellow
        const Color(0xFFFF8000), // Orange
        t,
      )!;
      alpha = minOpacity + (maxOpacity - minOpacity) * 0.8;
    } else {
      // Very hot - orange to red
      final t = (heat - 0.8) / 0.2;
      baseColor = Color.lerp(
        const Color(0xFFFF8000), // Orange
        const Color(0xFFFF0000), // Red
        t,
      )!;
      alpha = maxOpacity;
    }

    return baseColor.withOpacity(alpha);
  }

  /// Returns gradient stops for smooth distribution
  List<double> _getThermalStops() {
    return [0.0, 0.3, 0.5, 0.7, 1.0];
  }

  @override
  bool shouldRepaint(_HeatmapCirclePainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.blur != blur ||
        oldDelegate.intensity != intensity ||
        oldDelegate.maxOpacity != maxOpacity ||
        oldDelegate.minOpacity != minOpacity;
  }
}

/// Heatmap legend widget to show color scale
class HeatmapLegend extends StatelessWidget {
  final bool isVisible;

  const HeatmapLegend({Key? key, required this.isVisible}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Crime Density',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLegendItem('Low', const Color(0xFF0000FF)),
              const SizedBox(width: 4),
              _buildLegendItem('', const Color(0xFF00FFFF)),
              const SizedBox(width: 4),
              _buildLegendItem('Medium', const Color(0xFFFFFF00)),
              const SizedBox(width: 4),
              _buildLegendItem('', const Color(0xFFFF8000)),
              const SizedBox(width: 4),
              _buildLegendItem('High', const Color(0xFFFF0000)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color.withOpacity(0.7),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 9)),
        ],
      ],
    );
  }
}
