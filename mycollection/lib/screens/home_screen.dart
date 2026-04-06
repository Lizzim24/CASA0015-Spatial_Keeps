import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

// Simple Data Model for our Collections
class Album {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final int count;

  Album({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.count,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _firebaseStatus = 'Checking Firebase...';

  @override
  void initState() {
    super.initState();
    // Small runtime smoke test to verify Firebase is initialized
    Future.microtask(() async {
      try {
        final apps = Firebase.apps;
        setState(() {
          _firebaseStatus = 'Firebase initialized: ${apps.length} app(s)';
        });
      } catch (e) {
        setState(() {
          _firebaseStatus = 'Firebase init error: $e';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mock data to match our Ethereal aesthetic
    final List<Album> albums = [
      Album(
        id: '1',
        name: 'Golden Hour',
        description: 'Warm light captures from the balcony.',
        imageUrl: 'https://picsum.photos/seed/gold/600/800',
        count: 12,
      ),
      Album(
        id: '2',
        name: 'Urban Textures',
        description: 'Concrete and glass reflections.',
        imageUrl: 'https://picsum.photos/seed/urban/600/800',
        count: 8,
      ),
      Album(
        id: '3',
        name: 'Morning Mist',
        description: 'Soft, diffused light in the park.',
        imageUrl: 'https://picsum.photos/seed/mist/600/800',
        count: 5,
      ),
      Album(
        id: '4',
        name: 'Night Glow',
        description: 'Neon and artificial light studies.',
        imageUrl: 'https://picsum.photos/seed/night/600/800',
        count: 15,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB), // Soft White
      body: CustomScrollView(
        slivers: [
          // 1. Ethereal Header
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFFFDFCFB),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
              title: Column(
                mainAxisAlignment: Theme.of(context).platform == TargetPlatform.iOS ? MainAxisAlignment.center : MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spatial Keeps',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const Text(
                    'Your curated light collections',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                  // Runtime Firebase init status (smoke test)
                  Text(
                    _firebaseStatus,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.black87),
                onPressed: () {},
              ),
              const SizedBox(width: 12),
            ],
          ),

          // 2. Collections Grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 24.0,
                crossAxisSpacing: 16.0,
                childAspectRatio: 0.75, // Taller cards for a "gallery" look
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final album = albums[index];
                  return _buildAlbumCard(context, album, index);
                },
                childCount: albums.length,
              ),
            ),
          ),
          
          // Bottom padding for the navigation bar
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildAlbumCard(BuildContext context, Album album, int index) {
    // Add a slight vertical offset to every second card for a staggered look
    double topMargin = (index % 2 != 0) ? 20.0 : 0.0;

    return Container(
      margin: EdgeInsets.only(top: topMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Container with "Creamy Shadow"
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromRGBO(0, 0, 0, 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.network(
                  album.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Text Details
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  album.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '${album.count} Captures',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    textBaseline: TextBaseline.alphabetic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}