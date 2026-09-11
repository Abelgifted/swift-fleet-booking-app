/// Curated imagery for the premium experience (Unsplash CDN).
///
/// Every image renders through [PremiumImage] which fades in over a
/// shimmer and falls back to a branded gradient when the network is
/// unavailable — the UI never shows broken-image chrome.
abstract final class Imagery {
  static const String luxuryBus =
      'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1600&q=80';
  static const String highway =
      'https://images.unsplash.com/photo-1570125909232-eb263c188f7e?auto=format&fit=crop&w=1600&q=80';
  static const String roadTrip =
      'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=1600&q=80';
  static const String luxuryInterior =
      'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=1600&q=80';

  /// Deterministic per-trip image so result lists feel varied but stable.
  static String forTrip(String seed) {
    final images = [luxuryBus, highway, roadTrip, luxuryInterior];
    var hash = 0;
    for (final codeUnit in seed.codeUnits) {
      hash = (hash + codeUnit) % 997;
    }
    return images[hash % images.length];
  }
}
