import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Shown when creating a new album or editing an existing one.
/// For a new album: [albumName] is null, user fills in the name.
/// For edit: [albumName] is pre-filled, user can rename + add notes.
class AlbumEditScreen extends StatefulWidget {
  final String? albumName;     // null = create new
  final String? existingNotes; // pre-fill notes if editing

  const AlbumEditScreen({
    super.key,
    this.albumName,
    this.existingNotes,
  });

  @override
  State<AlbumEditScreen> createState() => _AlbumEditScreenState();
}

class _AlbumEditScreenState extends State<AlbumEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;

  bool _isSaving = false;
  bool get _isNew => widget.albumName == null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.albumName ?? '');
    _notesController = TextEditingController(text: widget.existingNotes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ─── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an album name.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      if (_isNew) {
        // Creating a new album — just return the name to the caller.
        // The album is "created" when the first photo is added to it.
        if (!mounted) return;
        Navigator.pop(context, newName);
        return;
      }

      // Editing existing album — rename all photos in this album
      // and update the album metadata doc if it exists.
      final oldName = widget.albumName!;

      if (newName != oldName) {
        // Batch-rename all photos
        final snapshot = await FirebaseFirestore.instance
            .collection('photos')
            .where('ownerId', isEqualTo: user.uid)
            .where('albumName', isEqualTo: oldName)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final doc in snapshot.docs) {
            batch.update(doc.reference, {
              'albumName': newName,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          await batch.commit();
        }
      }

      // Save album metadata (notes) to a separate 'albums' collection
      await FirebaseFirestore.instance
          .collection('albums')
          .doc('${user.uid}_$newName')
          .set({
        'ownerId': user.uid,
        'albumName': newName,
        'notes': _notesController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Album updated.'),
          backgroundColor: Colors.black87,
        ),
      );
      Navigator.pop(context, newName); // return new name to caller
    } catch (e) {
      debugPrint('Album save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        title: Text(
          _isNew ? 'New Album' : 'Edit Album',
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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSaving ? null : _save,
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
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isNew ? 'Create' : 'Save',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Icon preview ────────────────────────────────────────────
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F2EE),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  size: 36,
                  color: Color(0xFFB5A48B),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Album name ──────────────────────────────────────────────
            _sectionLabel('Album name'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _nameController,
              hint: 'e.g. Shoreditch walks',
              icon: Icons.folder_outlined,
              autofocus: _isNew,
            ),

            const SizedBox(height: 24),

            // ── Notes ───────────────────────────────────────────────────
            _sectionLabel('Notes'),
            const SizedBox(height: 4),
            const Text(
              'A short description or context for this album.',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _notesController,
              hint: 'What is this album about?',
              icon: Icons.notes_outlined,
              maxLines: 4,
            ),

            if (!_isNew) ...[
              const SizedBox(height: 32),
              _buildRenameWarning(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool autofocus = false,
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
        autofocus: autofocus,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
          prefixIcon: Icon(icon, size: 18, color: Colors.black38),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildRenameWarning() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEFD89A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 16, color: Color(0xFF9A7B2E)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Renaming will update all photos in this album. This cannot be undone.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF7A5E1A),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
