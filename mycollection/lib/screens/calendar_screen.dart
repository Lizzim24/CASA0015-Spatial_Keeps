import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'calendar_day_photos_screen.dart';

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> _weekdayShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

String _formatMonthYear(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

String _dayKey(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

class ArchivedPhoto {
  final String id;
  final String title;
  final String imageUrl;
  final DateTime createdAt;
  final double? lux;
  final String luxSemantic;
  final String directionSemantic;
  final String tiltSemantic;
  final String placeName;

  ArchivedPhoto({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.createdAt,
    required this.lux,
    required this.luxSemantic,
    required this.directionSemantic,
    required this.tiltSemantic,
    required this.placeName,
  });
}

class DayArchive {
  final DateTime date;
  final List<ArchivedPhoto> photos;

  DayArchive({required this.date, required this.photos});

  ArchivedPhoto get coverPhoto => photos.first;
  bool get hasMultiple => photos.length > 1;
  int get count => photos.length;

  String get moodSummary {
    final cover = coverPhoto;
    return '${cover.luxSemantic} · ${cover.directionSemantic} · ${cover.tiltSemantic}';
  }
}

enum ArchiveTab { archive, spatial, insights }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool _isLoading = true;
  final Map<String, DayArchive> _archivesByDay = {};
  ArchiveTab _currentTab = ArchiveTab.archive;

  @override
  void initState() {
    super.initState();
    _loadArchives();
  }

  String _topLabel(Map<String, int> counts, {required String fallback}) {
    if (counts.isEmpty) return fallback;
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  String _timeBucket(int hour) {
    if (hour >= 5 && hour < 12) return 'Morning';
    if (hour >= 12 && hour < 17) return 'Afternoon';
    if (hour >= 17 && hour < 21) return 'Evening';
    return 'Night';
  }

  String _buildSpaceStory({
    required int totalPhotos,
    required int activeDays,
    required String topLight,
    required String topDirection,
    required String topLocation,
    required String topTime,
  }) {
    if (totalPhotos == 0) {
      return 'No spatial records have been captured yet.';
    }

    return 'Your archive shows a pattern of $topLight environments, most often recorded at $topLocation, with captures typically happening in the $topTime. The dominant viewing behaviour suggests $topDirection, forming a personal record of how you experience space across $activeDays active day${activeDays == 1 ? '' : 's'}.';
  }

  Future<void> _loadArchives() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('photos')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      final List<ArchivedPhoto> photos = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final Timestamp? createdTs =
            data['createdAt'] as Timestamp? ?? data['updatedAt'] as Timestamp?;
        if (createdTs == null) continue;

        photos.add(
          ArchivedPhoto(
            id: doc.id,
            title: (data['title'] ?? 'Untitled').toString(),
            imageUrl: (data['imageUrl'] ?? '').toString(),
            createdAt: createdTs.toDate(),
            lux: (data['lux'] as num?)?.toDouble(),
            luxSemantic: (data['luxSemantic'] ?? 'Unknown Light').toString(),
            directionSemantic:
                (data['directionSemantic'] ?? 'Unknown Direction').toString(),
            tiltSemantic: (data['tiltSemantic'] ?? 'Unknown Perspective')
                .toString(),
            placeName: (data['placeName'] ?? 'Unknown Place').toString(),
          ),
        );
      }

      photos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final Map<String, List<ArchivedPhoto>> grouped = {};
      for (final photo in photos) {
        final key = _dayKey(photo.createdAt);
        grouped.putIfAbsent(key, () => []);
        grouped[key]!.add(photo);
      }

      _archivesByDay.clear();
      for (final entry in grouped.entries) {
        final date = _startOfDay(entry.value.first.createdAt);
        _archivesByDay[entry.key] = DayArchive(date: date, photos: entry.value);
      }
    } catch (e) {
      debugPrint('Calendar load error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load archive: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<DateTime> _buildMonthList() {
    if (_archivesByDay.isEmpty) {
      final now = DateTime.now();
      return [DateTime(now.year, now.month)];
    }

    final dates = _archivesByDay.values.map((e) => e.date).toList()
      ..sort((a, b) => b.compareTo(a));

    final newest = dates.first;
    final oldest = dates.last;

    final List<DateTime> months = [];
    DateTime cursor = DateTime(oldest.year, oldest.month);

    while (!cursor.isAfter(DateTime(newest.year, newest.month))) {
      months.add(DateTime(cursor.year, cursor.month));
      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    months.sort((a, b) => b.compareTo(a));
    return months;
  }

  void _openDayArchive(DayArchive archive) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CalendarDayPhotosScreen(date: archive.date, photos: archive.photos),
      ),
    );
  }

  Color _semanticTint(String semantic) {
    final text = semantic.toLowerCase();

    if (text.contains('dim')) {
      return const Color(0xFF5D6470);
    }
    if (text.contains('soft')) {
      return const Color(0xFFD8C39A);
    }
    if (text.contains('balanced')) {
      return const Color(0xFFE6D5B8);
    }
    if (text.contains('open')) {
      return const Color(0xFFF0E6C9);
    }
    if (text.contains('intense')) {
      return const Color(0xFFF8EDCF);
    }

    return const Color(0xFFE6D5B8);
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        children: [
          const Text(
            'Spatial Archive',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTopTab(
                  label: 'Archive',
                  icon: Icons.calendar_today_outlined,
                  active: _currentTab == ArchiveTab.archive,
                  onTap: () {
                    setState(() => _currentTab = ArchiveTab.archive);
                  },
                ),
                const SizedBox(width: 10),
                _buildTopTab(
                  label: 'Spatial',
                  icon: Icons.auto_awesome_outlined,
                  active: _currentTab == ArchiveTab.spatial,
                  onTap: () {
                    setState(() => _currentTab = ArchiveTab.spatial);
                  },
                ),
                const SizedBox(width: 10),
                _buildTopTab(
                  label: 'Insights',
                  icon: Icons.bar_chart_outlined,
                  active: _currentTab == ArchiveTab.insights,
                  onTap: () {
                    setState(() => _currentTab = ArchiveTab.insights);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTab({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.black87 : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: active ? Colors.black87 : Colors.black12),
          boxShadow: active
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: active ? Colors.white : Colors.black54),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.black54,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchiveView() {
    final months = _buildMonthList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [_buildTopHeader(), ...months.map(_buildMonthSection)],
    );
  }

  Widget _buildSpatialView() {
    final allArchives = _archivesByDay.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        _buildTopHeader(),
        const SizedBox(height: 8),
        const Text(
          'Spatial Highlights',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        ...allArchives.take(12).map((archive) {
          final cover = archive.coverPhoto;
          final tint = _semanticTint(cover.luxSemantic);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.grey[200],
                    image: cover.imageUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(cover.imageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${archive.date.day} ${_monthNames[archive.date.month - 1]}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        archive.moodSummary,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChip(cover.luxSemantic, tint),
                          _buildChip(
                            cover.directionSemantic,
                            const Color(0xFFF2F2F2),
                          ),
                          _buildChip(
                            cover.tiltSemantic,
                            const Color(0xFFF2F2F2),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInsightsView() {
    final archives = _archivesByDay.values.toList();

    int totalPhotos = 0;
    final Map<String, int> lightCounts = {};
    final Map<String, int> directionCounts = {};
    final Map<String, int> locationCounts = {};
    final Map<String, int> timeBucketCounts = {};

    for (final archive in archives) {
      totalPhotos += archive.photos.length;

      for (final photo in archive.photos) {
        lightCounts[photo.luxSemantic] =
            (lightCounts[photo.luxSemantic] ?? 0) + 1;
        directionCounts[photo.directionSemantic] =
            (directionCounts[photo.directionSemantic] ?? 0) + 1;
        locationCounts[photo.placeName] =
            (locationCounts[photo.placeName] ?? 0) + 1;

        final hour = photo.createdAt.hour;
        final bucket = _timeBucket(hour);
        timeBucketCounts[bucket] = (timeBucketCounts[bucket] ?? 0) + 1;
      }
    }

    String topLight = _topLabel(lightCounts, fallback: 'No light data');
    String topDirection = _topLabel(
      directionCounts,
      fallback: 'No direction data',
    );
    String topLocation = _topLabel(
      locationCounts,
      fallback: 'No location data',
    );
    String topTime = _topLabel(
      timeBucketCounts,
      fallback: 'No activity pattern',
    );

    final story = _buildSpaceStory(
      totalPhotos: totalPhotos,
      activeDays: archives.length,
      topLight: topLight,
      topDirection: topDirection,
      topLocation: topLocation,
      topTime: topTime,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        _buildTopHeader(),
        const SizedBox(height: 8),
        const Text(
          'Spatial Insights',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 18),

        _buildInsightCard(
          title: 'Archive Volume',
          value: '$totalPhotos captures',
          subtitle:
              '${archives.length} active day${archives.length == 1 ? '' : 's'}',
        ),

        _buildInsightCard(
          title: 'Most Frequent Location',
          value: topLocation,
          subtitle:
              'The place you most often recorded as part of your spatial memory',
        ),

        _buildInsightCard(
          title: 'Dominant Light Mood',
          value: topLight,
          subtitle:
              'The most common environmental light quality across your archive',
        ),

        _buildInsightCard(
          title: 'Viewing Behaviour',
          value: topDirection,
          subtitle:
              'The most common facing orientation in your captured experiences',
        ),

        _buildInsightCard(
          title: 'Active Time Pattern',
          value: topTime,
          subtitle:
              'The time period when you most frequently capture your environment',
        ),

        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Space Story',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                story,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildMonthSection(DateTime monthDate) {
    final year = monthDate.year;
    final month = monthDate.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDay = DateTime(year, month, 1);
    final mondayOffset = firstDay.weekday - 1;

    final List<Widget> cells = [];

    for (int i = 0; i < mondayOffset; i++) {
      cells.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final key = _dayKey(date);
      final archive = _archivesByDay[key];
      cells.add(_buildDayCell(date, archive));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              _formatMonthYear(monthDate),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: _weekdayShort.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 8,
            children: cells,
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(DateTime date, DayArchive? archive) {
    if (archive == null) {
      return Center(
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.grey[400],
          ),
        ),
      );
    }

    final tint = _semanticTint(archive.coverPhoto.luxSemantic);

    return GestureDetector(
      onTap: () => _openDayArchive(archive),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
              border: Border.all(color: tint, width: 2),
              image: archive.coverPhoto.imageUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(archive.coverPhoto.imageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: archive.coverPhoto.imageUrl.isEmpty
                ? Center(
                    child: Text(
                      '${date.day}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.16),
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
          ),
          if (archive.hasMultiple)
            Positioned(
              bottom: 2,
              right: 4,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadArchives,
                child: Builder(
                  builder: (context) {
                    switch (_currentTab) {
                      case ArchiveTab.archive:
                        return _buildArchiveView();
                      case ArchiveTab.spatial:
                        return _buildSpatialView();
                      case ArchiveTab.insights:
                        return _buildInsightsView();
                    }
                  },
                ),
              ),
      ),
    );
  }
}
