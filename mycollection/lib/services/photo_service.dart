import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

import '../models/grouped_location.dart';

class PhotoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String buildLocationKey(double lat, double lng) {
    return '${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
  }

  Future<String> uploadImage(File file) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
    final ref = _storage.ref().child('photos/${user.uid}/$fileName');

    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> createPhoto({
    required File imageFile,
    required String title,
    required String description,
    required double latitude,
    required double longitude,
    required String placeName,
    required List<String> tags,
    required bool isPublic,
    required String albumName,
    double? lux,
    double? direction,
    double? tilt,
    String? luxLabel,
    String? directionLabel,
    String? tiltLabel,
    String? luxSemantic,
    String? directionSemantic,
    String? tiltSemantic,
    List<String>? spatialTags,
    String? spatialMood,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final imageUrl = await uploadImage(imageFile);
    final locationKey = buildLocationKey(latitude, longitude);

    await _firestore.collection('photos').add({
      'ownerId': user.uid,
      'albumName': albumName.trim().isEmpty ? 'Uncategorised' : albumName.trim(),
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'placeName': placeName,
      'locationKey': locationKey,
      'tags': tags,
      'isPublic': isPublic,
      'lux': lux,
      'luxLabel': luxLabel,
      'luxSemantic': luxSemantic,
      'directionDegrees': direction,
      'directionLabel': directionLabel,
      'directionSemantic': directionSemantic,
      'tiltDegrees': tilt,
      'tiltLabel': tiltLabel,
      'tiltSemantic': tiltSemantic,
      'spatialTags': spatialTags ?? [],
      'spatialMood': spatialMood,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getMyPhotos() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final snapshot = await _firestore
        .collection('photos')
        .where('ownerId', isEqualTo: user.uid)
        .get();

    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getPublicPhotos({
    String? tag,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('photos')
        .where('isPublic', isEqualTo: true);

    if (tag != null && tag.trim().isNotEmpty) {
      query = query.where('tags', arrayContains: tag.trim());
    }

    final snapshot = await query.get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getPhotosByLocation({
    required String locationKey,
    required bool isPublic,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('photos')
        .where('locationKey', isEqualTo: locationKey);

    if (isPublic) {
      query = query.where('isPublic', isEqualTo: true);
    } else {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      query = query.where('ownerId', isEqualTo: user.uid);
    }

    final snapshot = await query.get();
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getPhotosByAlbum({
    required String albumName,
    required bool isPublic,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('photos')
        .where('albumName', isEqualTo: albumName);

    if (isPublic) {
      query = query.where('isPublic', isEqualTo: true);
    } else {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      query = query.where('ownerId', isEqualTo: user.uid);
    }

    final snapshot = await query.get();
    final docs = snapshot.docs.toList();

    docs.sort((a, b) {
      final aTs =
          a.data()['createdAt'] as Timestamp? ?? a.data()['updatedAt'] as Timestamp?;
      final bTs =
          b.data()['createdAt'] as Timestamp? ?? b.data()['updatedAt'] as Timestamp?;

      if (aTs == null && bTs == null) return 0;
      if (aTs == null) return 1;
      if (bTs == null) return -1;

      return bTs.compareTo(aTs);
    });

    return docs;
  }

  Future<void> updatePhoto({
    required String photoId,
    required String title,
    required String description,
    required List<String> tags,
    required bool isPublic,
    String? albumName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final doc = await _firestore.collection('photos').doc(photoId).get();
    final data = doc.data();

    if (data == null) {
      throw Exception('Photo not found');
    }

    if (data['ownerId'] != user.uid) {
      throw Exception('Not allowed to edit this photo');
    }

    final updateData = <String, dynamic>{
      'title': title,
      'description': description,
      'tags': tags,
      'isPublic': isPublic,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (albumName != null && albumName.trim().isNotEmpty) {
      updateData['albumName'] = albumName.trim();
    }

    await _firestore.collection('photos').doc(photoId).update(updateData);
  }

  List<GroupedLocation> groupPhotosByLocation(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final Map<String, List<Map<String, dynamic>>> groupedRaw = {};

    for (final doc in docs) {
      final data = doc.data();
      final key = data['locationKey'] as String? ?? '';
      if (key.isEmpty) continue;

      groupedRaw.putIfAbsent(key, () => []);
      groupedRaw[key]!.add(data);
    }

    final List<GroupedLocation> result = [];

    for (final entry in groupedRaw.entries) {
      final photos = entry.value;
      if (photos.isEmpty) continue;

      final first = photos.first;

      double luxTotal = 0;
      int luxCount = 0;

      for (final p in photos) {
        final lux = p['lux'];
        if (lux is num) {
          luxTotal += lux.toDouble();
          luxCount++;
        }
      }

      result.add(
        GroupedLocation(
          locationKey: entry.key,
          placeName: (first['placeName'] ?? 'Unknown Place').toString(),
          latitude: (first['latitude'] ?? 0).toDouble(),
          longitude: (first['longitude'] ?? 0).toDouble(),
          coverImageUrl: (first['imageUrl'] ?? '').toString(),
          photoCount: photos.length,
          avgLux: luxCount > 0 ? luxTotal / luxCount : 0,
        ),
      );
    }

    return result;
  }

  List<GroupedLocation> groupPhotosByAlbum(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final Map<String, List<Map<String, dynamic>>> groupedRaw = {};

    for (final doc in docs) {
      final data = doc.data();
      final albumName = (data['albumName'] ?? '').toString().trim();
      if (albumName.isEmpty) continue;

      groupedRaw.putIfAbsent(albumName, () => []);
      groupedRaw[albumName]!.add(data);
    }

    final List<GroupedLocation> result = [];

    for (final entry in groupedRaw.entries) {
      final albumName = entry.key;
      final photos = entry.value;
      if (photos.isEmpty) continue;

      final first = photos.first;

      double luxTotal = 0;
      int luxCount = 0;

      for (final p in photos) {
        final lux = p['lux'];
        if (lux is num) {
          luxTotal += lux.toDouble();
          luxCount++;
        }
      }

      result.add(
        GroupedLocation(
          locationKey: albumName,
          placeName: albumName,
          latitude: (first['latitude'] ?? 0).toDouble(),
          longitude: (first['longitude'] ?? 0).toDouble(),
          coverImageUrl: (first['imageUrl'] ?? '').toString(),
          photoCount: photos.length,
          avgLux: luxCount > 0 ? luxTotal / luxCount : 0,
        ),
      );
    }

    result.sort((a, b) => b.photoCount.compareTo(a.photoCount));
    return result;
  }

  Future<List<GroupedLocation>> getMyGroupedLocations() async {
    final docs = await getMyPhotos();
    return groupPhotosByLocation(docs);
  }

  Future<List<GroupedLocation>> getPublicGroupedLocations({String? tag}) async {
    final docs = await getPublicPhotos(tag: tag);
    return groupPhotosByLocation(docs);
  }

  Future<List<GroupedLocation>> getMyGroupedAlbums() async {
    final docs = await getMyPhotos();
    return groupPhotosByAlbum(docs);
  }

  Future<List<GroupedLocation>> getPublicGroupedAlbums() async {
    final docs = await getPublicPhotos();
    return groupPhotosByAlbum(docs);
  }
}