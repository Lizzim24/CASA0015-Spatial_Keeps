import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/photo_service.dart';
import 'album_edit_screen.dart';
import 'capture_screen.dart';
import 'photo_detail_screen.dart';

class AlbumDetailsScreen extends StatefulWidget {
  final String albumName;
  final bool isPublic;

  const AlbumDetailsScreen({
    super.key,
    required this.albumName,
    required this.isPublic,
  });

  @override
  State<AlbumDetailsScreen> createState() => _AlbumDetailsScreenState();
}

class _AlbumDetailsScreenState extends State<AlbumDetailsScreen> {
  final PhotoService _photoService = PhotoService();

  bool _isLoading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _photos = [];

  // Album metadata (name may change after edit)
  late String _currentAlbumName;
  String _albumNotes = '';

  @override
  void initState() {
    super.initState();
    _currentAlbumName = widget.albumName;
    _loadAll();
  }

  // ─── Data ─────────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadPhotos(), _loadAlbumMeta()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadPhotos() async {
    try {
      final docs = await _photoService.getPhotosByAlbum(
        albumName: _currentAlbumName,
        isPublic: widget.isPublic,
      );
      if (mounted) setState(() => _photos = docs);
    } catch (e) {
      debugPrint('AlbumDetailsScreen load error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load album photos: $e')),
        );
      }
    }
  }

  Future<void> _loadAlbumMeta() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || widget.isPublic) return;

      final doc = await FirebaseFirestore.instance
          .collection('albums')
          .doc('${user.uid}_$_currentAlbumName')
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _albumNotes =
              (doc.data()?['notes'] ?? '').toString().trim();
        });
      }
    } catch (e) {
      debugPrint('Album meta load error: $e');
    }
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  Future<void> _openPhotoDetail(String photoId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoDetailScreen(
          photoId: photoId,
          isEditable: !widget.isPublic,
        ),
      ),
    );
    _loadAll();
  }

  Future<void> _openCapture() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CaptureScreen(
          preselectedAlbum: _currentAlbumName,
        ),
      ),
    );
    _loadAll();
  }

  Future<void> _openEdit() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => AlbumEditScreen(
          albumName: _currentAlbumName,
          existingNotes: _albumNotes,
        ),
      ),
    );

    if (result != null && mounted) {
      // Name may have changed — update state and reload
      setState(() => _currentAlbumName = result);
      _loadAll();
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final String coverImageUrl = _photos.isNotEmpty
        ? (_photos.first.data()['imageUrl'] ?? '').toString()
        : '';

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        title: Text(
          _currentAlbumName,
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
          // Edit button — only for personal albums
          if (!widget.isPublic)
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 20, color: Colors.black54),
              tooltip: 'Edit album',
              onPressed: _openEdit,
            ),
        ],
      ),
      floatingActionButton: widget.isPublic
          ? null
          : FloatingActionButton(
              onPressed: _openCapture,
              backgroundColor: Colors.black,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Cover image ────────────────────────────────
                      if (coverImageUrl.isNotEmpty)
                        Container(
                          height: 240,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            image: DecorationImage(
                              image: NetworkImage(coverImageUrl),
                              fit: BoxFit.cover,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                        ),

                      if (coverImageUrl.isNotEmpty) const SizedBox(height: 24),

                      // ── Album name + count ─────────────────────────
                      Text(
                        _currentAlbumName,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_photos.length} photo${_photos.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),

                      // ── Notes ─────────────────────────────────────
                      if (_albumNotes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F2EE),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.notes_outlined,
                                  size: 16, color: Color(0xFFB5A48B)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _albumNotes,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ── Photo grid ─────────────────────────────────
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _photos.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.72,
                        ),
                        itemBuilder: (context, index) {
                          final doc = _photos[index];
                          final data = doc.data();
                          final imageUrl =
                              (data['imageUrl'] ?? '').toString();
                          final title =
                              (data['title'] ?? 'Untitled').toString();
                          final description =
                              (data['description'] ?? '').toString();

                          return GestureDetector(
                            onTap: () => _openPhotoDetail(doc.id),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(22),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.10),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                      image: imageUrl.isNotEmpty
                                          ? DecorationImage(
                                              image:
                                                  NetworkImage(imageUrl),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                      color: imageUrl.isEmpty
                                          ? Colors.grey[200]
                                          : null,
                                    ),
                                    child: imageUrl.isEmpty
                                        ? const Center(
                                            child: Icon(
                                                Icons.image_outlined))
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  description.isEmpty
                                      ? (widget.isPublic
                                          ? 'Tap to view'
                                          : 'Tap to edit')
                                      : description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 52, color: Colors.grey[350]),
            const SizedBox(height: 16),
            Text(
              'No photos in this album yet',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!widget.isPublic) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _openCapture,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                ),
                child: const Text('Add first photo'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _openEdit,
                child: const Text(
                  'Edit album details',
                  style: TextStyle(color: Colors.black45, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
