class LyricLine {
  final Duration time;
  final String original;
  final String? translation;

  LyricLine({
    required this.time,
    required this.original,
    this.translation,
  });

  @override
  String toString() {
    if (translation != null) {
      return '$original\n$translation';
    }
    return original;
  }
}
