class DetailEditPayload {
  const DetailEditPayload({
    required this.title,
    required this.description,
    required this.markerColorValue,
    required this.markerIconCodePoint,
    this.localImagePath,
    this.removeImage = false,
  });

  final String title;
  final String description;
  final int markerColorValue;
  final int markerIconCodePoint;

  /// New local image path picked by user (gallery), if any.
  final String? localImagePath;

  /// If true, remove image on server (and from event).
  /// If [localImagePath] is set, this should be false.
  final bool removeImage;
}
