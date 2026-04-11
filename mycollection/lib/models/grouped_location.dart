class GroupedLocation {
  final String locationKey;
  final String placeName;
  final double latitude;
  final double longitude;
  final String coverImageUrl;
  final int photoCount;
  final double avgLux;

  GroupedLocation({
    required this.locationKey,
    required this.placeName,
    required this.latitude,
    required this.longitude,
    required this.coverImageUrl,
    required this.photoCount,
    required this.avgLux,
  });
}
