import 'dart:io';

import 'package:flutter/material.dart';

import '../services/photo_service.dart';

/// Shown immediately after a photo is captured.
/// Displays the image preview alongside editable metadata fields,
/// then uploads to Firestore + Storage on save.
class PhotoDetailUploadScreen extends StatefulWidget {
  final File imageFile;
  final String? preselectedAlbum;

  // Sensor data passed from CaptureScreen
  final double? lux;
  final String? luxLabel;
  final String? luxSemantic;
  final double direction;
  final String directionLabel;
  final String directionSemantic;
  final double tilt;
  final String tiltLabel;
  final String tiltSemantic;
  final String spatialMood;
  final double? latitude;
  final double? longitude;
  final String placeName;

  const PhotoDetailUploadScreen({
    super.key,
    required this.imageFile,
    this.preselectedAlbum,
    this.lux,
    this.luxLabel,
    this.luxSemantic,
    required this.direction,
    required this.directionLabel,
    required this.directionSemantic,
    required this.tilt,
    required this.tiltLabel,
    required this.tiltSemantic,
    required this.spatialMood,
    this.latitude,
    this.longitude,
    required this.placeName,
  });

  @override
  State<PhotoDetailUploadScreen> createState() =>
      _PhotoDetailUploadScreenState();
}

class _PhotoDetailUploadScreenState extends State<PhotoDetailUploadScreen> {
  final PhotoService _photoService = PhotoService();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final _albumController = TextEditingController();
  final _placeController = TextEditingController();

  bool _isPublic = false;
  bool _isUploading = false;

  // Album picker
  List<String> _existingAlbums = [];
  String? _selectedAlbumFromList;
  bool _showNewAlbumField = false;

  @override
  void initState() {
    super.initState();
    _placeController.text = widget.placeName;

    if (widget.preselectedAlbum != null) {
      _albumController.text = widget.preselectedAlbum!;
      _selectedAlbumFromList = widget.preselectedAlbum;
    }

    _loadExistingAlbums();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _albumController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingAlbums() async {
    try {
      final albums = await _photoService.getMyGroupedAlbums();
      if (mounted) {
        setState(() {
          _existingAlbums = albums.map((a) => a.placeName).toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to load albums: $e');
    }
  }

  // ─── Validation ───────────────────────────────────────────────────────────

  String? _validate() {
    final albumName = _resolvedAlbumName;
    if (_titleController.text.trim().isEmpty) {
      return 'Please add a title for this capture.';
    }
    if (albumName.trim().isEmpty) {
      return 'Please choose or create an album.';
    }
    if (widget.latitude == null || widget.longitude == null) {
      return 'Location data is missing. Please try again.';
    }
    return null;
  }

  String get _resolvedAlbumName {
    if (_showNewAlbumField) {
      return _albumController.text.trim();
    }
    return _selectedAlbumFromList ?? _albumController.text.trim();
  }

  // ─── Upload ───────────────────────────────────────────────────────────────

  Future<void> _upload() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      await _photoService.createPhoto(
        imageFile: widget.imageFile,
        albumName: _resolvedAlbumName,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        latitude: widget.latitude!,
        longitude: widget.longitude!,
        placeName: _placeController.text.trim(),
        tags: tags,
        isPublic: _isPublic,
        lux: widget.lux,
        luxLabel: widget.luxLabel,
        luxSemantic: widget.luxSemantic,
        direction: widget.direction,
        directionLabel: widget.directionLabel,
        directionSemantic: widget.directionSemantic,
        tilt: widget.tilt,
        tiltLabel: widget.tiltLabel,
        tiltSemantic: widget.tiltSemantic,
        spatialMood: widget.spatialMood,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Captured and saved.'),
          backgroundColor: Colors.black87,
        ),
      );

      // Pop both this screen and the CaptureScreen
      Navigator.of(context).popUntil((route) {
        return route.settings.name != null || route.isFirst;
      });
      // Simpler: pop twice
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        title: const Text(
          'Save Capture',
          style: TextStyle(
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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isUploading ? null : _upload,
              style: TextButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo preview ───────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.file(
                  widget.imageFile,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Spatial mood badge ──────────────────────────────────────
            _buildSpatialMoodCard(),

            const SizedBox(height: 24),

            // ── Title ───────────────────────────────────────────────────
            _buildSectionLabel('Title'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _titleController,
              hint: 'e.g. Golden light on brick wall',
              icon: Icons.title,
            ),

            const SizedBox(height: 20),

            // ── Album ───────────────────────────────────────────────────
            _buildSectionLabel('Album'),
            const SizedBox(height: 8),
            _buildAlbumPicker(),

            const SizedBox(height: 20),

            // ── Description ─────────────────────────────────────────────
            _buildSectionLabel('Description'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _descriptionController,
              hint: 'What do you notice about this space?',
              icon: Icons.notes,
              maxLines: 3,
            ),

            const SizedBox(height: 20),

            // ── Tags ─────────────────────────────────────────────────────
            _buildSectionLabel('Tags'),
            const SizedBox(height: 4),
            const Text(
              'Separate with commas — e.g. urban, afternoon, cafe',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _tagsController,
              hint: 'urban, afternoon, cafe',
              icon: Icons.tag,
            ),

            const SizedBox(height: 20),

            // ── Location ─────────────────────────────────────────────────
            _buildSectionLabel('Location'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _placeController,
              hint: 'Location name',
              icon: Icons.location_on_outlined,
            ),
            if (widget.latitude != null && widget.longitude != null) ...[
              const SizedBox(height: 6),
              Text(
                '${widget.latitude!.toStringAsFixed(5)}, ${widget.longitude!.toStringAsFixed(5)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black38,
                  fontFamily: 'monospace',
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Visibility ───────────────────────────────────────────────
            _buildVisibilityToggle(),

            const SizedBox(height: 32),

            // ── Sensor snapshot (read-only, collapsible) ─────────────────
            _buildSensorSnapshot(),
          ],
        ),
      ),
    );
  }

  // ─── Sub-widgets ─────────────────────────────────────────────────────────

  Widget _buildSpatialMoodCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F2EE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE6D5B8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 18,
              color: Color(0xFF2D2D2D),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Spatial mood',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black45,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.spatialMood,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(color: Colors.black38, fontSize: 14),
          prefixIcon: Icon(icon, size: 18, color: Colors.black38),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildAlbumPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle: existing vs new
        Row(
          children: [
            _albumToggleChip(
              label: 'Choose existing',
              selected: !_showNewAlbumField,
              onTap: () => setState(() => _showNewAlbumField = false),
            ),
            const SizedBox(width: 10),
            _albumToggleChip(
              label: 'Create new',
              selected: _showNewAlbumField,
              onTap: () => setState(() {
                _showNewAlbumField = true;
                _selectedAlbumFromList = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_showNewAlbumField)
          _buildTextField(
            controller: _albumController,
            hint: 'New album name',
            icon: Icons.add_box_outlined,
          )
        else if (_existingAlbums.isEmpty)
          GestureDetector(
            onTap: () => setState(() => _showNewAlbumField = true),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 18, color: Colors.black45),
                  SizedBox(width: 8),
                  Text(
                    'No albums yet — tap to create one',
                    style: TextStyle(color: Colors.black45, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else
          // Horizontal scrollable album chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _existingAlbums.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final name = _existingAlbums[index];
                final selected = _selectedAlbumFromList == name;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedAlbumFromList = name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.black87
                          : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: selected
                            ? Colors.black87
                            : Colors.black12,
                      ),
                    ),
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _albumToggleChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2D2D2D)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF2D2D2D) : Colors.black12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _isPublic
                  ? const Color(0xFFE6D5B8)
                  : const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isPublic
                  ? Icons.public
                  : Icons.lock_outline,
              size: 18,
              color: _isPublic
                  ? const Color(0xFF2D2D2D)
                  : Colors.black38,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPublic ? 'Public' : 'Private',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  _isPublic
                      ? 'Visible to everyone on the public map'
                      : 'Only visible to you',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isPublic,
            onChanged: (v) => setState(() => _isPublic = v),
            thumbColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? const Color(0xFF2D2D2D)
                  : null,
            ),
            trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? const Color(0xFF2D2D2D).withValues(alpha: 0.4)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorSnapshot() {
    return _ExpandableSection(
      title: 'Sensor snapshot',
      child: Column(
        children: [
          if (widget.lux != null) ...[
            _sensorRow(
              icon: Icons.wb_sunny_outlined,
              label: 'Light',
              value: widget.luxSemantic ?? widget.luxLabel ?? '',
              detail: '${widget.lux!.toStringAsFixed(0)} lux'
                  '${widget.luxLabel != null ? ' · ${widget.luxLabel}' : ''}',
            ),
          ],
          _sensorRow(
            icon: Icons.explore_outlined,
            label: 'Direction',
            value: widget.directionSemantic,
            detail:
                '${widget.direction.toStringAsFixed(1)}° · ${widget.directionLabel}',
          ),
          _sensorRow(
            icon: Icons.screen_rotation_outlined,
            label: 'Tilt',
            value: widget.tiltSemantic,
            detail:
                '${widget.tilt.toStringAsFixed(1)}° · ${widget.tiltLabel}',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _sensorRow({
    required IconData icon,
    required String label,
    required String value,
    required String detail,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Colors.black45),
              const SizedBox(width: 10),
              SizedBox(
                width: 70,
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
                    if (value.isNotEmpty)
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: Colors.black.withValues(alpha: 0.05)),
      ],
    );
  }
}

// ── Expandable section widget ─────────────────────────────────────────────

class _ExpandableSection extends StatefulWidget {
  final String title;
  final Widget child;

  const _ExpandableSection({
    required this.title,
    required this.child,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.sensors,
                    size: 18,
                    color: Colors.black45,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _anim,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
