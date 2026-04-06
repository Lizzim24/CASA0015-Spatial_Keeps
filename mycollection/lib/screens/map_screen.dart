import 'package:flutter/material.dart';

class SpatialPoint {
  final Offset position; // Normalized 0.0 to 1.0
  final String title;
  final double lux;

  SpatialPoint({required this.position, required this.title, required this.lux});
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isPublic = false;

  // Mock data for our spatial points
  final List<SpatialPoint> _points = [
    SpatialPoint(position: const Offset(0.3, 0.4), title: "Morning Light", lux: 450),
    SpatialPoint(position: const Offset(0.7, 0.2), title: "Office Glow", lux: 300),
    SpatialPoint(position: const Offset(0.5, 0.8), title: "Sunset Balcony", lux: 120),
    SpatialPoint(position: const Offset(0.2, 0.7), title: "Reading Nook", lux: 80),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      body: Stack(
        children: [
          // 1. The Abstract Grid & Points
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return CustomPaint(
                painter: SpatialMapPainter(
                  points: _points,
                  pulseValue: _pulseController.value,
                ),
                child: Container(),
              );
            },
          ),

          // 2. Header & Toggle
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Spatial Map",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.0),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildToggleButton("Personal", !_isPublic),
                      const SizedBox(width: 12),
                      _buildToggleButton("Public", _isPublic),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. Floating Legend
          Positioned(
            bottom: 120,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 255, 255, 0.8),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendItem("High Lux", const Color(0xFFE6D5B8)),
                  const SizedBox(height: 8),
                  _buildLegendItem("Low Lux", Colors.grey[300]!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool active) {
    return GestureDetector(
      onTap: () => setState(() => _isPublic = label == "Public"),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: active ? Colors.black : Colors.black12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ],
    );
  }
}

// --- The Magic: Custom Painter for the Abstract Map ---

class SpatialMapPainter extends CustomPainter {
  final List<SpatialPoint> points;
  final double pulseValue;

  SpatialMapPainter({required this.points, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = const Color.fromRGBO(0, 0, 0, 0.03)
      ..strokeWidth = 1.0;

    // 1. Draw Grid Lines
    double spacing = 50.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // 2. Draw Spatial Points
    for (var point in points) {
      final Offset pos = Offset(point.position.dx * size.width, point.position.dy * size.height);
      
      // Calculate color based on Lux (Higher Lux = Warmer/Brighter)
      final Color pointColor = Color.lerp(
        const Color(0xFFE6D5B8), 
        Colors.grey[300]!, 
        (500 - point.lux) / 500
      )!;

      // Draw Pulse Effect
      final Paint pulsePaint = Paint()
        ..color = pointColor.withValues(alpha: (0.2 * (1 - pulseValue)))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 10 + (20 * pulseValue), pulsePaint);

      // Draw Main Node
      final Paint nodePaint = Paint()
        ..color = pointColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 6, nodePaint);

      // Draw Label
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: point.title,
          style: const TextStyle(color: Colors.black38, fontSize: 8, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(pos.dx + 10, pos.dy - 4));
    }
  }

  @override
  bool shouldRepaint(covariant SpatialMapPainter oldDelegate) => true;
}