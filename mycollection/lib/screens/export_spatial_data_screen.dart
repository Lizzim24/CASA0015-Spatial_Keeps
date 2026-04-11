import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/profile_service.dart';

class ExportSpatialDataScreen extends StatefulWidget {
  const ExportSpatialDataScreen({super.key});

  @override
  State<ExportSpatialDataScreen> createState() => _ExportSpatialDataScreenState();
}

class _ExportSpatialDataScreenState extends State<ExportSpatialDataScreen> {
  final ProfileService _profileService = ProfileService();

  bool _isLoading = true;
  String _jsonPreview = '';

  @override
  void initState() {
    super.initState();
    _loadExport();
  }

  Future<void> _loadExport() async {
    try {
      final json = await _profileService.exportMyPhotosAsPrettyJson();
      if (!mounted) return;
      setState(() {
        _jsonPreview = json;
      });
    } catch (e) {
      debugPrint('Export load error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export data: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _jsonPreview));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        title: const Text('Export Spatial Data'),
        backgroundColor: const Color(0xFFFDFCFB),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _copyToClipboard,
              child: const Text('Copy'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black12),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _jsonPreview.isEmpty ? 'No export data available' : _jsonPreview,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
