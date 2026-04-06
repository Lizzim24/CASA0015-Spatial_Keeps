import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
// Fallback Light sensor implementation when 'package:light' is not available.
import 'dart:math' as math;

/// Simple local Light fallback that emits faux lux values so the app compiles
/// and can run on platforms where the 'light' package is not available.
class Light {
  final Stream<int> lightSensorStream = Stream.periodic(
    const Duration(milliseconds: 500),
    (i) => 100 + (i % 900), // varying lux values for a basic preview
  );
}

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  // Sensor Data
  double _luxValue = 0.0;
  double _direction = 0.0; // Heading in degrees
  double _tilt = 0.0;      // Inclination in degrees
  
  // Streams
  StreamSubscription<int>? _lightSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<MagnetometerEvent>? _magSubscription;

  @override
  void initState() {
    super.initState();
    _startSensorStreams();
  }

  void _startSensorStreams() {
    // 1. Light Sensor (Lux)
    try {
      _lightSubscription = Light().lightSensorStream.listen((lux) {
        setState(() => _luxValue = lux.toDouble());
      });
    } catch (e) {
      debugPrint("Light sensor not available");
    }

    // 2. Accelerometer (Tilt/Inclination)
    _accelSubscription = accelerometerEventStream().listen((event) {
      // Calculate tilt from Z-axis
      double tilt = math.atan2(event.y, event.z) * 180 / math.pi;
      setState(() => _tilt = tilt);
    });

    // 3. Magnetometer (Direction/Compass)
    _magSubscription = magnetometerEventStream().listen((event) {
      // Simple heading calculation
      double heading = math.atan2(event.y, event.x) * 180 / math.pi;
      setState(() => _direction = heading < 0 ? heading + 360 : heading);
    });
  }

  @override
  void dispose() {
    _lightSubscription?.cancel();
    _accelSubscription?.cancel();
    _magSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Preview Placeholder
          // In a real app, you'd use CameraPreview(controller)
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.grey[900],
            child: const Center(
              child: Icon(Icons.camera_alt, color: Colors.white24, size: 64),
            ),
          ),

          // 2. Sensor Overlay (The "Ethereal" HUD)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSensorReadout("LUX", _luxValue.toStringAsFixed(0), Icons.wb_sunny_outlined),
                  const SizedBox(height: 16),
                  _buildSensorReadout("DIR", "${_direction.toStringAsFixed(0)}°", Icons.explore_outlined),
                  const SizedBox(height: 16),
                  _buildSensorReadout("TILT", "${_tilt.toStringAsFixed(0)}°", Icons.screen_rotation),
                ],
              ),
            ),
          ),

          // 3. Bottom Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  "CURATING SPATIAL LIGHT",
                  style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 2),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery Shortcut
                    IconButton(
                      icon: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 28),
                      onPressed: () {},
                    ),
                    // Shutter Button
                    GestureDetector(
                      onTap: () => _capturePhoto(),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Flash Toggle
                    IconButton(
                      icon: const Icon(Icons.flash_on_outlined, color: Colors.white, size: 28),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorReadout(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(0, 0, 0, 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFE6D5B8), size: 18),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
            ],
          ),
        ],
      ),
    );
  }

  void _capturePhoto() {
    // Logic to save photo + sensor data to Firestore
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Capture saved to 'Golden Hour'")),
    );
  }
}