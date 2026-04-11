import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/photo_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      final docs = await _photoService.getPhotosByAlbum(
        albumName: widget.albumName,
        isPublic: widget.isPublic,
      );

      if (!mounted) return;
      setState(() {
        _photos = docs;
      });
    } catch (e) {
      debugPrint('AlbumDetailsScreen load error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load album photos: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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

    _loadPhotos();
  }

  Future<void> _openCapture() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CaptureScreen(
          preselectedAlbum: widget.albumName,
        ),
      ),
    );

    _loadPhotos();
  }

  String _buildSubtitle() {
    if (widget.isPublic) {
      return 'Public shared photos in this album';
    }
    return 'Your captured photos in this album';
  }

  @override
  Widget build(BuildContext context) {
    final String coverImageUrl = _photos.isNotEmpty
        ? (_photos.first.data()['imageUrl'] ?? '').toString()
        : '';

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        title: Text(
          widget.albumName,
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 52,
                          color: Colors.grey[350],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No photos found in this album',
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
                                horizontal: 18,
                                vertical: 12,
                              ),
                            ),
                            child: const Text('Add first photo'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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

                      Text(
                        widget.albumName,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_photos.length} photo${_photos.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _buildSubtitle(),
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 24),

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

                          final imageUrl = (data['imageUrl'] ?? '').toString();
                          final title = (data['title'] ?? 'Untitled').toString();
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
                                      borderRadius: BorderRadius.circular(22),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.10),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                      image: imageUrl.isNotEmpty
                                          ? DecorationImage(
                                              image: NetworkImage(imageUrl),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                      color: imageUrl.isEmpty
                                          ? Colors.grey[200]
                                          : null,
                                    ),
                                    child: imageUrl.isEmpty
                                        ? const Center(
                                            child: Icon(Icons.image_outlined),
                                          )
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
}
