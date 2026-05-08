import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:light/light.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'photo_detail_upload_screen.dart';

class CaptureScreen extends StatefulWidget {
  final String? preselectedAlbum;
  const CaptureScreen({super.key, this.preselectedAlbum});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with SingleTickerProviderStateMixin {
  // ─── Camera ───────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady = false;
  bool _isCapturing = false;
  bool _flashOn = false;
  int _currentCameraIndex = 0;

  // ─── Sensors ──────────────────────────────────────────────────────────────
  StreamSubscription? _lightSub;
  StreamSubscription? _accelSub;
  StreamSubscription? _magSub;
  final Light _light = Light();

  double _lux = 0;
  double _tilt = 0;
  double _direction = 0;
  bool _luxAvailable = true;

  // ─── Location ─────────────────────────────────────────────────────────────
  double? _latitude;
  double? _longitude;
  String _placeName = '';
  bool _locationLoading = true;

  // ─── Shutter animation ───────────────────────────────────────────────────
  late final AnimationController _shutterCtrl;
  late final Animation<double> _shutterAnim;

  @override
  void initState() {
    super.initState();

    _shutterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _shutterAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _shutterCtrl, curve: Curves.easeIn),
    );

    _requestPermissionsAndInit();
  }

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> _requestPermissionsAndInit() async {
    final statuses = await [
      Permission.camera,
      Permission.location,
      Permission.sensors,
    ].request();

    if (statuses[Permission.camera]!.isGranted) {
      await _initCamera();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required to capture photos.'),
          ),
        );
      }
    }

    if (statuses[Permission.location]!.isGranted) {
      _fetchLocation();
    } else {
      setState(() => _locationLoading = false);
    }

    _startSensors();
  }

  Future<void> _initCamera({int index = 0}) async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      final prev = _cameraController;
      _cameraController = null;
      if (mounted) setState(() => _isCameraReady = false);

      await prev?.dispose();

      final cam = _cameras[index % _cameras.length];
      final controller = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      _cameraController = controller;
      _currentCameraIndex = index % _cameras.length;

      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    await _initCamera(index: _currentCameraIndex + 1);
  }

  Future<void> _fetchLocation() async {
    setState(() => _locationLoading = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _placeName =
              '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
          _locationLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  void _startSensors() {
    // Light sensor
    try {
      _lightSub = _light.lightSensorStream.listen(
        (v) {
          if (mounted) setState(() => _lux = v.toDouble());
        },
        onError: (_) {
          _luxAvailable = false;
        },
      );
    } catch (_) {
      _luxAvailable = false;
    }

    // Accelerometer → tilt
    _accelSub = accelerometerEventStream().listen((e) {
      if (mounted) {
        setState(() => _tilt = math.atan2(e.y, e.z) * 180 / math.pi);
      }
    });

    // Magnetometer → compass direction
    _magSub = magnetometerEventStream().listen((e) {
      double h = math.atan2(e.y, e.x) * 180 / math.pi;
      if (mounted) setState(() => _direction = h < 0 ? h + 360 : h);
    });
  }

  // ─── Sensor classification ────────────────────────────────────────────────

  String get _luxLabel {
    if (_lux < 100) return 'Dim';
    if (_lux < 1000) return 'Indoor';
    return 'Bright';
  }

  String get _luxSemantic {
    if (_lux < 100) return 'Dim light';
    if (_lux < 300) return 'Soft light';
    if (_lux < 1000) return 'Balanced light';
    if (_lux < 10000) return 'Open light';
    return 'Intense light';
  }

  String get _directionLabel {
    if (_direction >= 337.5 || _direction < 22.5) return 'N';
    if (_direction < 67.5) return 'NE';
    if (_direction < 112.5) return 'E';
    if (_direction < 157.5) return 'SE';
    if (_direction < 202.5) return 'S';
    if (_direction < 247.5) return 'SW';
    if (_direction < 292.5) return 'W';
    return 'NW';
  }

  String get _directionFullLabel {
    if (_direction >= 337.5 || _direction < 22.5) return 'North';
    if (_direction < 67.5) return 'N-East';
    if (_direction < 112.5) return 'East';
    if (_direction < 157.5) return 'S-East';
    if (_direction < 202.5) return 'South';
    if (_direction < 247.5) return 'S-West';
    if (_direction < 292.5) return 'West';
    return 'N-West';
  }

  String get _directionSemantic {
    if (_direction >= 337.5 || _direction < 22.5) return 'Facing north';
    if (_direction < 67.5) return 'Facing north-east';
    if (_direction < 112.5) return 'Facing east';
    if (_direction < 157.5) return 'Facing south-east';
    if (_direction < 202.5) return 'Facing south';
    if (_direction < 247.5) return 'Facing south-west';
    if (_direction < 292.5) return 'Facing west';
    return 'Facing north-west';
  }

  String get _tiltLabel {
    final t = _tilt.abs();
    if (t < 15) return 'Level';
    if (t < 45) return 'Angled';
    return 'Steep';
  }

  String get _tiltSemantic {
    final t = _tilt.abs();
    if (t < 15) return 'Level perspective';
    if (t < 45) return 'Angled perspective';
    return 'Steep perspective';
  }

  String get _spatialMood =>
      '$_luxSemantic · $_directionSemantic · $_tiltSemantic';

  // ─── Capture ──────────────────────────────────────────────────────────────

  Future<void> _capture() async {
    if (_isCapturing || !_isCameraReady || _cameraController == null) return;
    setState(() => _isCapturing = true);

    // Flash the shutter overlay
    _shutterCtrl.forward().then((_) => _shutterCtrl.reverse());

    try {
      final file = await _cameraController!.takePicture();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoDetailUploadScreen(
            imageFile: File(file.path),
            preselectedAlbum: widget.preselectedAlbum,
            lux: _luxAvailable ? _lux : null,
            luxLabel: _luxAvailable ? _luxLabel : null,
            luxSemantic: _luxAvailable ? _luxSemantic : null,
            direction: _direction,
            directionLabel: _directionFullLabel,
            directionSemantic: _directionSemantic,
            tilt: _tilt,
            tiltLabel: _tiltLabel,
            tiltSemantic: _tiltSemantic,
            spatialMood: _spatialMood,
            latitude: _latitude,
            longitude: _longitude,
            placeName: _placeName,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _toggleFlash() {
    setState(() => _flashOn = !_flashOn);
    _cameraController?.setFlashMode(
      _flashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  // ─── Dispose ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _shutterCtrl.dispose();
    _lightSub?.cancel();
    _accelSub?.cancel();
    _magSub?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Full-screen camera preview ──────────────────────────────────
          if (_isCameraReady && _cameraController != null)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            )
          else
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Starting camera…',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),

          // ── Shutter flash overlay ───────────────────────────────────────
          AnimatedBuilder(
            animation: _shutterAnim,
            builder: (_, _) => Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color:
                      Colors.white.withValues(alpha: 1 - _shutterAnim.value),
                ),
              ),
            ),
          ),

          // ── Top controls bar ────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _iconBtn(
                    icon: Icons.close,
                    onTap: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      if (_cameras.length > 1) ...[
                        _iconBtn(
                          icon: Icons.flip_camera_ios_outlined,
                          onTap: _switchCamera,
                        ),
                        const SizedBox(width: 12),
                      ],
                      _iconBtn(
                        icon: _flashOn
                            ? Icons.flash_on
                            : Icons.flash_off,
                        onTap: _toggleFlash,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Sensor HUD strip ────────────────────────────────────────────
          Positioned(
            top: 90,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.50),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_luxAvailable)
                      _hudChip(Icons.wb_sunny_outlined, _luxLabel),
                    if (_luxAvailable) _hudDivider(),
                    _hudChip(Icons.explore_outlined, _directionLabel),
                    _hudDivider(),
                    _hudChip(Icons.screen_rotation_outlined, _tiltLabel),
                    _hudDivider(),
                    _locationLoading
                        ? _hudChip(Icons.location_searching,
                            'GPS…', subtle: true)
                        : _latitude != null
                            ? _hudChip(Icons.location_on_outlined, 'GPS')
                            : _hudChip(Icons.location_off_outlined,
                                'No GPS', subtle: true),
                  ],
                ),
              ),
            ),
          ),

          // ── Grid / rule of thirds overlay (faint) ───────────────────────
          if (_isCameraReady)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _GridOverlayPainter()),
              ),
            ),

          // ── Bottom controls: shutter + info ─────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 36),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Spatial mood preview text
                    if (_luxAvailable)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Text(
                          _spatialMood,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),

                    // Shutter button row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _isCapturing ? null : _capture,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: 78,
                            height: 78,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isCapturing
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : Colors.white,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: _isCapturing
                                ? const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.black38,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Text(
                      'Tap to capture',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helper widgets ───────────────────────────────────────────────────────

  Widget _iconBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _hudChip(IconData icon, String label, {bool subtle = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: subtle ? Colors.white38 : Colors.white70,
          size: 13,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: subtle ? Colors.white38 : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _hudDivider() {
    return Container(
      width: 1,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white24,
    );
  }
}

// ── Rule-of-thirds grid overlay ─────────────────────────────────────────────

class _GridOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 0.7;

    // Vertical lines
    canvas.drawLine(
        Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0),
        Offset(size.width * 2 / 3, size.height), paint);

    // Horizontal lines
    canvas.drawLine(
        Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3),
        Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
