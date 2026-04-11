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

      if (!doc.exists) {
        throw Exception('Photo not found');
      }

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
        SnackBar(content: Text('Failed to load photo detail: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePhoto() async {
    try {
      setState(() {
        _isSaving = true;
      });

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
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatNumber(dynamic value, {int fractionDigits = 0}) {
    if (value == null) return '--';
    if (value is num) return value.toStringAsFixed(fractionDigits);
    return value.toString();
  }

  Widget _buildSensorInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final imageUrl = _photoData?['imageUrl'] ?? '';
    final placeName = _photoData?['placeName'] ?? '';
    final latitude = _photoData?['latitude'];
    final longitude = _photoData?['longitude'];

    final lux = _photoData?['lux'];
    final luxLabel = _photoData?['luxLabel'] ?? 'Unknown';
    final luxSemantic = _photoData?['luxSemantic'] ?? 'Unknown';

    final directionDegrees =
        _photoData?['directionDegrees'] ?? _photoData?['direction'];
    final directionLabel = _photoData?['directionLabel'] ?? 'Unknown';
    final directionSemantic = _photoData?['directionSemantic'] ?? 'Unknown';

    final tiltDegrees = _photoData?['tiltDegrees'] ?? _photoData?['tilt'];
    final tiltLabel = _photoData?['tiltLabel'] ?? 'Unknown';
    final tiltSemantic = _photoData?['tiltSemantic'] ?? 'Unknown';

    final spatialMood = _photoData?['spatialMood'] ?? '';
    final spatialTags = List<String>.from(_photoData?['spatialTags'] ?? []);

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
              child: Text(_isSaving ? 'Saving...' : 'Save'),
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
                          image: imageUrl.toString().isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(imageUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: imageUrl.toString().isEmpty
                            ? const Center(child: Icon(Icons.image_outlined, size: 40))
                            : null,
                      ),
                      const SizedBox(height: 24),

                      TextField(
                        controller: _titleController,
                        enabled: widget.isEditable,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

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

                      TextField(
                        controller: _tagsController,
                        enabled: widget.isEditable,
                        decoration: const InputDecoration(
                          labelText: 'Tags (comma separated)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (widget.isEditable)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Make Public'),
                          value: _isPublic,
                          onChanged: (value) {
                            setState(() {
                              _isPublic = value;
                            });
                          },
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

                      const SizedBox(height: 24),
                      _buildSectionTitle('Place'),
                      const SizedBox(height: 8),
                      Text(
                        placeName.toString().isEmpty
                            ? 'Unknown place'
                            : placeName,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (latitude != null && longitude != null)
                        Text(
                          'Lat: $latitude, Lng: $longitude',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),

                      const SizedBox(height: 24),
                      _buildSectionTitle('Sensor Snapshot'),
                      const SizedBox(height: 12),

                      _buildSensorInfoRow(
                        'Light',
                        '${_formatNumber(lux)} lux · $luxLabel · $luxSemantic',
                      ),
                      _buildSensorInfoRow(
                        'Direction',
                        '${_formatNumber(directionDegrees)}° · $directionLabel · $directionSemantic',
                      ),
                      _buildSensorInfoRow(
                        'Tilt',
                        '${_formatNumber(tiltDegrees)}° · $tiltLabel · $tiltSemantic',
                      ),

                      if (spatialMood.toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildSectionTitle('Spatial Mood'),
                        const SizedBox(height: 8),
                        Text(
                          spatialMood,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ],

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
}