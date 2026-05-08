import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/photo_service.dart';
import 'photo_detail_screen.dart';

/// Shows all photos captured at a specific geographic location.
/// Uses [locationKey] (lat_lng string) to query, not albumName.
/// This is used from the map screen markers.
class LocationPhotosScreen extends StatefulWidget {
  final String locationKey;
  final String placeName;
  final bool isPublic;

  const LocationPhotosScreen({
    super.key,
    required this.locationKey,
    required this.placeName,
    required this.isPublic,
  });

  @override
  State<LocationPhotosScreen> createState() => _LocationPhotosScreenState();
}

class _LocationPhotosScreenState extends State<LocationPhotosScreen> {
  final PhotoService _photoService = PhotoService();

  bool _isLoading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _photos = [];

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    try {
      final docs = await _photoService.getPhotosByLocation(
        locationKey: widget.locationKey,
        isPublic: widget.isPublic,
      );

      // Sort newest first
      final sorted = docs.toList()
        ..sort((a, b) {
          final aTs = a.data()['createdAt'] as Timestamp? ??
              a.data()['updatedAt'] as Timestamp?;
          final bTs = b.data()['createdAt'] as Timestamp? ??
              b.data()['updatedAt'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });

      if (mounted) setState(() => _photos = sorted);
    } catch (e) {
      debugPrint('LocationPhotosScreen load error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load photos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final coverImageUrl = _photos.isNotEmpty
        ? (_photos.first.data()['imageUrl'] ?? '').toString()
        : '';

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        title: Text(
          widget.placeName.isNotEmpty ? widget.placeName : 'Location',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined,
                          size: 52, color: Colors.grey[350]),
                      const SizedBox(height: 16),
                      Text(
                        'No photos at this location',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Cover image ──────────────────────────────────
                      if (coverImageUrl.isNotEmpty)
                        Container(
                          height: 220,
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

                      if (coverImageUrl.isNotEmpty) const SizedBox(height: 20),

                      // ── Title + count ────────────────────────────────
                      Text(
                        widget.placeName.isNotEmpty
                            ? widget.placeName
                            : 'Location',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${_photos.length} photo${_photos.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: widget.isPublic
                                  ? const Color(0xFFE8F0FB)
                                  : const Color(0xFFF6F2EE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              widget.isPublic ? 'Public' : 'Personal',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: widget.isPublic
                                    ? const Color(0xFF1A5CB5)
                                    : const Color(0xFF8A7560),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── Photo grid ───────────────────────────────────
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
                          final albumName =
                              (data['albumName'] ?? '').toString();

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
                                      color: Colors.grey[200],
                                      image: imageUrl.isNotEmpty
                                          ? DecorationImage(
                                              image:
                                                  NetworkImage(imageUrl),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.08),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: imageUrl.isEmpty
                                        ? const Center(
                                            child:
                                                Icon(Icons.image_outlined))
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
                                if (albumName.isNotEmpty)
                                  const SizedBox(height: 2),
                                if (albumName.isNotEmpty)
                                  Text(
                                    albumName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
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
