import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/premium_theme.dart';

/// Scale-on-press wrapper for micro-interactions on tappable cards.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

/// Friendly full-width error with retry (used by lists + screens).
class AppErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  const AppErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.error_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Lux.error.withValues(alpha: 0.1),
              border: Border.all(color: Lux.error.withValues(alpha: 0.32)),
            ),
            child: Icon(icon, size: 30, color: Lux.error),
          ),
          const SizedBox(height: 18),
          Text(
            'Something interrupted us',
            textAlign: TextAlign.center,
            style: Lux.headline(context, size: 19),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Lux.body(context, size: 13.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 190,
            child: FilledButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                onRetry();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Check your connection and try again.',
            textAlign: TextAlign.center,
            style: Lux.caption(context, size: 11),
          ),
        ],
      ),
    );
  }
}

/// Global error handling: framework + async zone errors.
///
/// Call [ErrorHandler.init] before `runApp`. In production, forward
/// `details` / `error` to Crashlytics/Sentry from the marked spots.
class ErrorHandler {
  ErrorHandler._();

  static void init() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      // TODO(prod): crashReporter.recordFlutterError(details);
    };
    // Never render a blank screen: any widget build exception shows a
    // visible, themed fallback instead of the default grey/white box.
    ErrorWidget.builder = (details) => _ErrorFallback(details: details);
  }

  /// Maps technical failures to friendly one-liners.
  static String friendly(Object error) {
    final msg = '$error';
    if (msg.contains('No internet') ||
        msg.contains('connection') ||
        msg.contains('SocketException')) {
      return 'No internet connection. Check your network and retry.';
    }
    if (msg.contains('timed out')) {
      return 'The request timed out. Please try again.';
    }
    if (msg.contains('Unauthorized')) {
      return 'Your session expired. Please log in again.';
    }
    return 'Something went wrong. Please try again.';
  }
}

/// Replacement for Flutter's default grey ErrorWidget — keeps screens
/// visibly non-blank when a build throws.
class _ErrorFallback extends StatelessWidget {
  final FlutterErrorDetails details;

  const _ErrorFallback({required this.details});

  @override
  Widget build(BuildContext context) {
    debugPrint('ErrorFallback painted: ${details.exception}');
    final message = kReleaseMode
        ? 'Something went wrong here.\nPlease try again.'
        : 'Build error:\n${details.exception}';
    return Container(
      width: double.infinity,
      color: Lux.ink,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Lux.goldBright, fontSize: 13),
      ),
    );
  }
}
