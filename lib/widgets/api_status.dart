import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/premium_theme.dart';
import '../services/api_service.dart';

/// Reachability of the fleet backend.
enum ApiReachability { unknown, checking, online, offline }

/// Compact status pill: a coloured dot plus a short label.
///
/// Used on the dashboard and search screens so a dead proxy is visible at a
/// glance instead of hiding behind a disabled button.
class ApiStatusPill extends StatelessWidget {
  final ApiReachability state;

  /// Optional latency in ms, shown when the probe succeeded.
  final int? latencyMs;

  final VoidCallback? onTap;

  const ApiStatusPill({
    super.key,
    required this.state,
    this.latencyMs,
    this.onTap,
  });

  Color get _color => switch (state) {
        ApiReachability.online => Lux.success,
        ApiReachability.offline => Lux.error,
        ApiReachability.checking => Lux.goldDeep,
        ApiReachability.unknown => Lux.goldDeep,
      };

  String get _label => switch (state) {
        ApiReachability.online =>
          latencyMs == null ? 'API online' : 'API online · ${latencyMs}ms',
        ApiReachability.offline => 'API offline',
        ApiReachability.checking => 'Checking…',
        ApiReachability.unknown => 'API status',
      };

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == ApiReachability.checking)
            SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                valueColor: AlwaysStoppedAnimation(_color),
              ),
            )
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _color),
            ),
          const SizedBox(width: 7),
          Text(
            _label,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: _color,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return pill;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: pill,
    );
  }
}

/// Settings row that probes the backend on mount and shows the resolved
/// base URL, with a green/red indicator.
class ApiStatusTile extends StatefulWidget {
  final VoidCallback? onOpenDiagnostics;

  const ApiStatusTile({super.key, this.onOpenDiagnostics});

  @override
  State<ApiStatusTile> createState() => _ApiStatusTileState();
}

class _ApiStatusTileState extends State<ApiStatusTile> {
  ApiReachability _state = ApiReachability.unknown;
  int? _latency;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => check());
  }

  Future<void> check() async {
    if (!mounted) return;
    setState(() {
      _state = ApiReachability.checking;
      _error = null;
    });
    try {
      final entry = await ApiService().ping();
      if (!mounted) return;
      setState(() {
        _state = ApiReachability.online;
        _latency = entry.durationMs;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = ApiReachability.offline;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = ApiReachability.offline;
        _error = '$e';
      });
    }
  }

  Color get _color => switch (_state) {
        ApiReachability.online => Lux.success,
        ApiReachability.offline => Lux.error,
        _ => Lux.goldDeep,
      };

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (_state) {
      ApiReachability.online => 'Reachable in ${_latency ?? 0}ms',
      ApiReachability.offline => _error ?? 'Not reachable',
      ApiReachability.checking => 'Checking connection…',
      ApiReachability.unknown => 'Tap to test the connection',
    };

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _color.withValues(alpha: 0.12),
          border: Border.all(color: _color.withValues(alpha: 0.3)),
        ),
        child: Icon(
          _state == ApiReachability.online
              ? Icons.cloud_done_outlined
              : _state == ApiReachability.offline
                  ? Icons.cloud_off_outlined
                  : Icons.cloud_queue_outlined,
          size: 19,
          color: _color,
        ),
      ),
      title: Row(
        children: [
          Text('API connection', style: Lux.title(context, size: 14.5)),
          const SizedBox(width: 8),
          if (_state == ApiReachability.checking)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            )
          else
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: _color),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(subtitle, style: Lux.caption(context, size: 11.5)),
          const SizedBox(height: 2),
          Text(
            ApiService.resolvedBaseUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.5,
              color: Lux.goldDeep,
            ),
          ),
        ],
      ),
      trailing: IconButton(
        tooltip: 'Re-test',
        onPressed: _state == ApiReachability.checking ? null : check,
        icon: const Icon(Icons.refresh_rounded, size: 18),
      ),
      onTap: widget.onOpenDiagnostics,
    );
  }
}
