/// Platform-aware premium image: CachedNetworkImage on native (disk
/// cache), browser-cached Image.network on web. Both share the shimmer
/// placeholder + branded fallback.
library;

export 'premium_image_web.dart'
    if (dart.library.io) 'premium_image_native.dart';
