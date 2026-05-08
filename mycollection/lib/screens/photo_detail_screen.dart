import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/photo_service.dart';

class PhotoDetailScreen extends StatefulWidget {
  final String photoId;
  final bool isEditable;

  const PhotoDetailScreen({
    super.key,
    required this.photoId,
    required this.isEditable,
  });

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  final PhotoService _photoService = PhotoService();

  bool _isLoading = true;
  bool _isSaving = false;

  Map<String, dynamic>? _photoData;

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _tagsController;

  bool _isPublic = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _tagsController = TextEditingController();
    _loadPhoto();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadPhoto() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('photos')
          .doc(widget.photoId)
          .get();

      if (!doc.exists) throw Exception('Photo not found');

      final data = doc.data()!;
      _photoData = data;

      _titleController.text = data['title'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      _isPublic = data['isPublic'] ?? false;

      final tags = List<String>.from(data['tags'] ?? []);
      _tagsController.text = tags.join(', ');
    } catch (e) {
      debugPrint('Photo detail load error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePhoto() async {
    try {
      setState(() => _isSaving = true);

      final tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await _photoService.updatePhoto(
        photoId: widget.photoId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        tags: tags,
        isPublic: _isPublic,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo updated successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Save photo error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Sensor field helpers ─────────────────────────────────────────────────
  // Old captures only stored luxLabel/directionLabel/tiltLabel.
  // New captures also store luxSemantic/directionSemantic/tiltSemantic.
  // We show semantic if available, else fall back to label, else show nothing.

  String _str(dynamic v) => (v ?? '').toString().trim();

  /// Returns the best display string for a sensor value.
  /// [semantic] is the richer description (e.g. "Dim light").
  /// [label]    is the short classification (e.g. "Dim").
  /// Returns empty string if both are absent — caller hides the row.
  String _sensorText(dynamic semantic, dynamic label) {
    final s = _str(semantic);
    final l = _str(label);
    if (s.isNotEmpty) return s;
    if (l.isNotEmpty) return l;
    return '';
  }

  /// Builds a display string like "618 lux · Indoor · Dim light"
  /// Skips any segment that is empty.
  String _buildSensorDetail({
    required dynamic rawValue,
    required String unit,
    required dynamic label,
    required dynamic semantic,
    int fractionDigits = 0,
  }) {
    final parts = <String>[];

    if (rawValue is num) {
      parts.add('${rawValue.toStringAsFixed(fractionDigits)} $unit');
    }

    final l = _str(label);
    if (l.isNotEmpty) parts.add(l);

    final s = _str(semantic);
    // Avoid duplicating if semantic == label
    if (s.isNotEmpty && s != l) parts.add(s);

    return parts.join(' · ');
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final imageUrl = _str(_photoData?['imageUrl']);
    final placeName = _str(_photoData?['placeName']);
    final latitude = _photoData?['latitude'];
    final longitude = _photoData?['longitude'];

    // Light
    final lux = _photoData?['lux'];
    final luxLabel = _photoData?['luxLabel'];
    final luxSemantic = _photoData?['luxSemantic'];

    // Direction
    final directionDegrees =
        _photoData?['directionDegrees'] ?? _photoData?['direction'];
    final directionLabel = _photoData?['directionLabel'];
    final directionSemantic = _photoData?['directionSemantic'];

    // Tilt
    final tiltDegrees =
        _photoData?['tiltDegrees'] ?? _photoData?['tilt'];
    final tiltLabel = _photoData?['tiltLabel'];
    final tiltSemantic = _photoData?['tiltSemantic'];

    final spatialMood = _str(_photoData?['spatialMood']);
    final spatialTags =
        List<String>.from(_photoData?['spatialTags'] ?? []);

    // Only show sensor section if at least one value exists
    final hasLux = lux != null;
    final hasDirection = directionDegrees != null;
    final hasTilt = tiltDegrees != null;
    final hasSensorData = hasLux || hasDirection || hasTilt;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        title: Text(
          widget.isEditable ? 'Edit Photo' : 'Photo Detail',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        backgroundColor: const Color(0xFFFDFCFB),
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (widget.isEditable)
            TextButton(
              onPressed: _isSaving ? null : _savePhoto,
              child: Text(_isSaving ? 'Saving…' : 'Save'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photoData == null
              ? const Center(child: Text('Photo not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Photo ────────────────────────────────────────
                      Container(
                        height: 320,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: Colors.grey[200],
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          image: imageUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(imageUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: imageUrl.isEmpty
                            ? const Center(
                                child: Icon(Icons.image_outlined, size: 40))
                            : null,
                      ),
                      const SizedBox(height: 24),

                      // ── Title ────────────────────────────────────────
                      TextField(
                        controller: _titleController,
                        enabled: widget.isEditable,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Description ──────────────────────────────────
                      TextField(
                        controller: _descriptionController,
                        enabled: widget.isEditable,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Tags ─────────────────────────────────────────
                      TextField(
                        controller: _tagsController,
                        enabled: widget.isEditable,
                        decoration: const InputDecoration(
                          labelText: 'Tags (comma separated)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Visibility ───────────────────────────────────
                      if (widget.isEditable)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Make Public'),
                          value: _isPublic,
                          onChanged: (v) => setState(() => _isPublic = v),
                        )
                      else
                        Row(
                          children: [
                            const Text(
                              'Visibility: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              _isPublic ? 'Public' : 'Private',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),

                      // ── Place ────────────────────────────────────────
                      const SizedBox(height: 24),
                      _buildSectionTitle('Place'),
                      const SizedBox(height: 8),
                      if (placeName.isNotEmpty)
                        Text(
                          placeName,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      if (latitude != null && longitude != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Lat: $latitude, Lng: $longitude',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black45,
                          ),
                        ),
                      ],

                      // ── Sensor Snapshot ──────────────────────────────
                      if (hasSensorData) ...[
                        const SizedBox(height: 24),
                        _buildSectionTitle('Sensor Snapshot'),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: Colors.black.withValues(alpha: 0.07)),
                          ),
                          child: Column(
                            children: [
                              if (hasLux)
                                _buildSensorRow(
                                  icon: Icons.wb_sunny_outlined,
                                  label: 'Light',
                                  primaryText: _sensorText(luxSemantic, luxLabel),
                                  detail: _buildSensorDetail(
                                    rawValue: lux,
                                    unit: 'lux',
                                    label: luxLabel,
                                    semantic: luxSemantic,
                                  ),
                                  isFirst: true,
                                  isLast: !hasDirection && !hasTilt,
                                ),
                              if (hasDirection)
                                _buildSensorRow(
                                  icon: Icons.explore_outlined,
                                  label: 'Direction',
                                  primaryText: _sensorText(
                                      directionSemantic, directionLabel),
                                  detail: _buildSensorDetail(
                                    rawValue: directionDegrees,
                                    unit: '°',
                                    label: directionLabel,
                                    semantic: directionSemantic,
                                    fractionDigits: 1,
                                  ),
                                  isFirst: !hasLux,
                                  isLast: !hasTilt,
                                ),
                              if (hasTilt)
                                _buildSensorRow(
                                  icon: Icons.screen_rotation_outlined,
                                  label: 'Tilt',
                                  primaryText:
                                      _sensorText(tiltSemantic, tiltLabel),
                                  detail: _buildSensorDetail(
                                    rawValue: tiltDegrees,
                                    unit: '°',
                                    label: tiltLabel,
                                    semantic: tiltSemantic,
                                    fractionDigits: 1,
                                  ),
                                  isFirst: !hasLux && !hasDirection,
                                  isLast: true,
                                ),
                            ],
                          ),
                        ),
                      ],

                      // ── Spatial Mood ─────────────────────────────────
                      if (spatialMood.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F2EE),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Spatial Mood',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black45,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                spatialMood,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ── Spatial Tags ─────────────────────────────────
                      if (spatialTags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildSectionTitle('Spatial Tags'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: spatialTags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFE7D8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  // ─── Sub-widgets ─────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildSensorRow({
    required IconData icon,
    required String label,
    required String primaryText,
    required String detail,
    required bool isFirst,
    required bool isLast,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: Colors.black38),
              const SizedBox(width: 10),
              SizedBox(
                width: 72,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (primaryText.isNotEmpty)
                      Text(
                        primaryText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    if (detail.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                            top: primaryText.isNotEmpty ? 2 : 0),
                        child: Text(
                          detail,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black38,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Colors.black.withValues(alpha: 0.05),
          ),
      ],
    );
  }
}
