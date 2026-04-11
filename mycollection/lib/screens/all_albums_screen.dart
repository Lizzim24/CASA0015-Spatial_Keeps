import 'package:flutter/material.dart';
import 'package:mycollection/models/grouped_location.dart';
import 'package:mycollection/screens/album_details_screen.dart';

class AllAlbumsScreen extends StatelessWidget {
  final List<GroupedLocation> locations;

  const AllAlbumsScreen({super.key, required this.locations});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        title: const Text(
          'All Locations',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
        ),
        backgroundColor: const Color(0xFFFDFCFB),
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: locations.isEmpty
          ? const Center(
              child: Text(
                'No captured locations yet',
                style: TextStyle(color: Colors.black54, fontSize: 15),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              itemCount: locations.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                final location = locations[index];

                return GestureDetector(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            image: DecorationImage(
                              image: NetworkImage(
                                location.coverImageUrl.isNotEmpty
                                    ? location.coverImageUrl
                                    : 'https://picsum.photos/seed/fallback/600/800',
                              ),
                              fit: BoxFit.cover,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        location.placeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${location.photoCount} Captures',
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
    );
  }
}
