import 'package:cloud_firestore/cloud_firestore.dart';

class PhotoItem {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final String placeName;
  final String locationKey;
  final List<String> tags;
  final bool isPublic;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PhotoItem({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.placeName,
    required this.locationKey,
    required this.tags,
    required this.isPublic,
    this.createdAt,
    this.updatedAt,
  });

  factory PhotoItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return PhotoItem(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      placeName: data['placeName'] ?? '',
      locationKey: data['locationKey'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      isPublic: data['isPublic'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'placeName': placeName,
      'locationKey': locationKey,
      'tags': tags,
      'isPublic': isPublic,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
