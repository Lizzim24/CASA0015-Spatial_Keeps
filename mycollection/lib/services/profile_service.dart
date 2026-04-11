import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<void> ensureUserDocument() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final ref = _firestore.collection('users').doc(user.uid);
    final doc = await ref.get();

    if (!doc.exists) {
      await ref.set({
        'displayName': user.displayName ?? 'Spatial Curator',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'bio': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'settings': {
          'privateByDefault': false,
          'allowPublicSharing': true,
          'notificationsEnabled': true,
          'weeklyInsights': true,
        },
      });
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    await ensureUserDocument();

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data() ?? {};
  }

  Future<void> updateUserProfile({
    required String displayName,
    required String bio,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    await user.updateDisplayName(displayName);

    await _firestore.collection('users').doc(user.uid).set({
      'displayName': displayName,
      'bio': bio,
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> uploadAvatar(File file) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final ref = FirebaseStorage.instance
        .ref()
        .child('avatars/${user.uid}/profile.jpg');

    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    await _firestore.collection('users').doc(user.uid).set({
      'photoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await user.updatePhotoURL(url);

    return url;
  }

  Future<void> removeAvatar() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('avatars/${user.uid}/profile.jpg');
      await ref.delete();
    } catch (_) {
      // 删除失败不阻止后续 profile 更新
    }

    await _firestore.collection('users').doc(user.uid).set({
      'photoUrl': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await user.updatePhotoURL(null);
  }

  Future<Map<String, dynamic>> getUserSettings() async {
    final profile = await getUserProfile();
    return Map<String, dynamic>.from(profile['settings'] ?? {});
  }

  Future<void> updateUserSettings(Map<String, dynamic> settings) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    await _firestore.collection('users').doc(user.uid).set({
      'settings': settings,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> getProfileStats() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final snapshot = await _firestore
        .collection('photos')
        .where('ownerId', isEqualTo: user.uid)
        .get();

    final docs = snapshot.docs;

    int captures = docs.length;
    int shared = 0;

    final Set<String> uniqueTags = {};
    final Set<String> uniqueLocations = {};
    final Set<String> activeDayKeys = {};

    for (final doc in docs) {
      final data = doc.data();

      if ((data['isPublic'] ?? false) == true) {
        shared++;
      }

      final tags = List<String>.from(data['tags'] ?? []);
      uniqueTags.addAll(tags);

      final placeName = (data['placeName'] ?? '').toString().trim();
      final locationKey = (data['locationKey'] ?? '').toString().trim();

      if (placeName.isNotEmpty) {
        uniqueLocations.add(placeName);
      } else if (locationKey.isNotEmpty) {
        uniqueLocations.add(locationKey);
      }

      final createdTs =
          data['createdAt'] as Timestamp? ?? data['updatedAt'] as Timestamp?;
      if (createdTs != null) {
        final d = createdTs.toDate();
        final month = d.month.toString().padLeft(2, '0');
        final day = d.day.toString().padLeft(2, '0');
        final dayKey = '${d.year}-$month-$day';
        activeDayKeys.add(dayKey);
      }
    }

    return {
      'captures': captures,
      'tags': uniqueTags.length,
      'shared': shared,
      'locations': uniqueLocations.length,
      'activeDays': activeDayKeys.length,
    };
  }

  Future<List<Map<String, dynamic>>> exportMyPhotos() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final snapshot = await _firestore
        .collection('photos')
        .where('ownerId', isEqualTo: user.uid)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
  }

  Future<String> exportMyPhotosAsPrettyJson() async {
    final photos = await exportMyPhotos();
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(photos);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
