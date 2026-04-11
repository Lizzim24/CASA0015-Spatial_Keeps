import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/grouped_location.dart';
import '../services/photo_service.dart';
import 'album_details_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final PhotoService _photoService = PhotoService();

  bool _isPublic = false;
  bool _isLoading = true;
  String _searchTag = '';
  final TextEditingController _tagController = TextEditingController();

  List<GroupedLocation> _locations = [];
  GoogleMapController? _mapController;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(51.5246, -0.1340),
    zoom: 13,
  );

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _tagController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final locations = _isPublic
          ? await _photoService.getPublicGroupedLocations(
              tag: _searchTag.trim().isEmpty ? null : _searchTag.trim(),
            )
          : await _photoService.getMyGroupedLocations();

      if (!mounted) return;
      setState(() {
        _locations = locations;
      });

      if (_locations.isNotEmpty && _mapController != null) {
        await _moveCameraToFitLocations(_locations);
      }
    } catch (e) {
      debugPrint('MapScreen load error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load map data: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _moveCameraToFitLocations(
    List<GroupedLocation> locations,
  ) async {
    if (_mapController == null || locations.isEmpty) return;

    if (locations.length == 1) {
      final location = locations.first;
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(location.latitude, location.longitude),
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

    for (final location in locations) {
      if (location.latitude < minLat) minLat = location.latitude;
      if (location.latitude > maxLat) maxLat = location.latitude;
      if (location.longitude < minLng) minLng = location.longitude;
      if (location.longitude > maxLng) maxLng = location.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  Set<Marker> _buildMarkers() {
    return _locations.map((location) {
      return Marker(
        markerId: MarkerId(location.locationKey),
        position: LatLng(location.latitude, location.longitude),
        infoWindow: InfoWindow(
          title: location.placeName,
          snippet:
              '${location.photoCount} photo${location.photoCount > 1 ? 's' : ''}',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AlbumDetailsScreen(
                  albumName: location.placeName,
                  isPublic: false,
                ),
              ),
            );
          },
        ),
      );
    }).toSet();
  }

  void _toggleMode(bool makePublic) {
    setState(() {
      _isPublic = makePublic;
      if (!_isPublic) {
        _searchTag = '';
        _tagController.clear();
      }
    });
    _loadLocations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: _buildMarkers(),
            myLocationButtonEnabled: false,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            onMapCreated: (controller) async {
              _mapController = controller;
              if (_locations.isNotEmpty) {
                await _moveCameraToFitLocations(_locations);
              }
            },
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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

                  if (_isPublic) ...[
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _tagController,
                        decoration: InputDecoration(
                          hintText: 'Search by tag...',
                          prefixIcon: const Icon(Icons.search),
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: () {
                              setState(() {
                                _searchTag = _tagController.text.trim();
                              });
                              _loadLocations();
                            },
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onSubmitted: (value) {
                          setState(() {
                            _searchTag = value.trim();
                          });
                          _loadLocations();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 120,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendItem('Locations', const Color(0xFFE6D5B8)),
                  const SizedBox(height: 8),
                  Text(
                    '${_locations.length} place${_locations.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.white.withValues(alpha: 0.25),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.black : Colors.white.withValues(alpha: 0.92),
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
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.black54),
        ),
      ],
    );
  }
}
