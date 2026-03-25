class DetailEditPayload {
  const DetailEditPayload({
    required this.title,
    required this.description,
    required this.markerColorValue,
    required this.markerIconCodePoint,
  });

  final String title;
  final String description;
  final int markerColorValue;
  final int markerIconCodePoint;
}
