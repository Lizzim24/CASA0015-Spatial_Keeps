import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/grouped_location.dart';
import '../services/photo_service.dart';
import 'location_photos_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final PhotoService _photoService = PhotoService();

  // Non-const: LatLng constructor is not const
  static final CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(51.5074, -0.1278),
    zoom: 13,
  );

  bool _isLoading = true;
  bool _isPublic = false;
  String _searchTag = '';
  final TextEditingController _tagController = TextEditingController();

  List<GroupedLocation> _locations = [];
  Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _initLocationAndLoad();
  }

  @override
  void dispose() {
    _tagController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> _initLocationAndLoad() async {
    await _fetchCurrentLocation();
    await _loadLocations();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (_currentPosition != null && _mapController != null && mounted) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              zoom: 14,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  // ─── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadLocations() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final tag = _searchTag.trim().isEmpty ? null : _searchTag.trim();

      final List<GroupedLocation> locations;

      if (_isPublic) {
        // Public mode: public photos, optionally filtered by tag
        locations = await _photoService.getPublicGroupedLocations(tag: tag);
      } else {
        // Personal mode: my photos only, optionally filtered by tag
        locations = await _photoService.getMyGroupedLocations(tag: tag);
      }

      final markers = await _buildPhotoMarkers(locations, isPublic: _isPublic);

      if (!mounted) return;
      setState(() {
        _locations = locations;
        _markers = markers;
      });

      if (locations.isNotEmpty && tag != null && _mapController != null) {
        await _moveCameraToFitLocations(locations);
      } else if (_currentPosition != null && _mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              zoom: 14,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('MapScreen load error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load map data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleMode(bool makePublic) {
    setState(() {
      _isPublic = makePublic;
      _searchTag = '';
      _tagController.clear();
    });
    _loadLocations();
  }

  // ─── Markers ──────────────────────────────────────────────────────────────

  Future<Set<Marker>> _buildPhotoMarkers(
    List<GroupedLocation> locations, {
    required bool isPublic,
  }) async {
    final Set<Marker> markers = {};

    for (final location in locations) {
      BitmapDescriptor icon;
      try {
        icon = await _buildThumbnailMarker(location.coverImageUrl);
      } catch (_) {
        icon = BitmapDescriptor.defaultMarkerWithHue(
          isPublic ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueOrange,
        );
      }

      markers.add(
        Marker(
          markerId: MarkerId(location.locationKey),
          position: LatLng(location.latitude, location.longitude),
          icon: icon,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LocationPhotosScreen(
                  locationKey: location.locationKey,
                  placeName: location.placeName,
                  isPublic: isPublic,
                ),
              ),
            );
          },
          infoWindow: InfoWindow(
            title: location.placeName,
            snippet:
                '${location.photoCount} photo${location.photoCount > 1 ? 's' : ''}',
          ),
        ),
      );
    }

    return markers;
  }

  /// Renders a circular photo thumbnail as a [BitmapDescriptor] for map markers.
  Future<BitmapDescriptor> _buildThumbnailMarker(String imageUrl) async {
    const int thumbSize = 120;
    const double border = 4.0;
    const double total = thumbSize + border * 2;

    final response = await http.get(Uri.parse(imageUrl));
    final codec = await ui.instantiateImageCodec(
      response.bodyBytes,
      targetWidth: thumbSize,
    );
    final frame = await codec.getNextFrame();
    final photo = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(total / 2, total / 2);
    const radius = thumbSize / 2.0;

    // White border
    canvas.drawCircle(
      center,
      radius + border,
      Paint()..color = Colors.white,
    );

    // Clip to circle and draw photo
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawImageRect(
      photo,
      Rect.fromLTWH(0, 0, photo.width.toDouble(), photo.height.toDouble()),
      Rect.fromCircle(center: center, radius: radius),
      Paint(),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(total.toInt(), total.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
      width: total,
      height: total,
    );
  }

  Future<void> _moveCameraToFitLocations(
    List<GroupedLocation> locations,
  ) async {
    if (_mapController == null || locations.isEmpty) return;

    if (locations.length == 1) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target:
                LatLng(locations.first.latitude, locations.first.longitude),
            zoom: 15,
          ),
        ),
      );
      return;
    }

    double minLat = locations.first.latitude;
    double maxLat = locations.first.latitude;
    double minLng = locations.first.longitude;
    double maxLng = locations.first.longitude;

    for (final l in locations) {
      if (l.latitude < minLat) minLat = l.latitude;
      if (l.latitude > maxLat) maxLat = l.latitude;
      if (l.longitude < minLng) minLng = l.longitude;
      if (l.longitude > maxLng) maxLng = l.longitude;
    }

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final initialPosition = _currentPosition != null
        ? CameraPosition(
            target: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            zoom: 14,
          )
        : _defaultPosition;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      body: Stack(
        children: [
          // ── Google Map ────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: initialPosition,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            onMapCreated: (controller) async {
              _mapController = controller;
              if (_currentPosition != null) {
                await controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      zoom: 14,
                    ),
                  ),
                );
              }
            },
          ),

          // ── Overlay header ────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  const Text(
                    'Spatial Map',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Personal / Public toggle
                  Row(
                    children: [
                      _buildToggleButton(
                        label: 'Personal',
                        active: !_isPublic,
                        onTap: () => _toggleMode(false),
                      ),
                      const SizedBox(width: 12),
                      _buildToggleButton(
                        label: 'Public',
                        active: _isPublic,
                        onTap: () => _toggleMode(true),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Tag search bar — always visible in both modes
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.97),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _tagController,
                      decoration: InputDecoration(
                        hintText: _isPublic
                            ? 'Search public photos by tag…'
                            : 'Filter my photos by tag…',
                        hintStyle: const TextStyle(
                          color: Colors.black38,
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.black45,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        suffixIcon: _searchTag.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.black45,
                                ),
                                onPressed: () {
                                  _tagController.clear();
                                  setState(() => _searchTag = '');
                                  _loadLocations();
                                },
                              )
                            : IconButton(
                                icon: const Icon(
                                  Icons.arrow_forward,
                                  size: 18,
                                  color: Colors.black54,
                                ),
                                onPressed: () {
                                  setState(() =>
                                      _searchTag = _tagController.text.trim());
                                  _loadLocations();
                                },
                              ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onSubmitted: (value) {
                        setState(() => _searchTag = value.trim());
                        _loadLocations();
                      },
                    ),
                  ),

                  // Active tag badge
                  if (_searchTag.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_locations.length} result${_locations.length == 1 ? '' : 's'} for "$_searchTag"',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Bottom-right controls ─────────────────────────────────────
          Positioned(
            bottom: 130,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // My location FAB
                FloatingActionButton.small(
                  heroTag: 'myLocation',
                  backgroundColor: Colors.white,
                  elevation: 3,
                  onPressed: () async {
                    if (_currentPosition != null && _mapController != null) {
                      await _mapController!.animateCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(
                            target: LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                            zoom: 15,
                          ),
                        ),
                      );
                    } else {
                      await _fetchCurrentLocation();
                    }
                  },
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.black87,
                    size: 20,
                  ),
                ),

                const SizedBox(height: 10),

                // Location count chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isPublic
                              ? const Color(0xFF4A90D9)
                              : const Color(0xFFE6D5B8),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_locations.length} place${_locations.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Loading overlay ───────────────────────────────────────────
          if (_isLoading)
            Container(
              color: Colors.white.withValues(alpha: 0.2),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // ─── Helper widgets ───────────────────────────────────────────────────────

  Widget _buildToggleButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? Colors.black87
              : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: active ? Colors.black87 : Colors.black12,
          ),
          boxShadow: active
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.black54,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
