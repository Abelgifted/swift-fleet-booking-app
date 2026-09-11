import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/api_config.dart';
import '../config/premium_theme.dart';
import '../services/api_diagnostics.dart';
import '../services/api_service.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_card.dart';
import '../widgets/responsive.dart';

/// Developer-facing health check for the fleet backend.
///
/// Shows the resolved base URL, probes every endpoint and prints the raw
/// response so a broken proxy or an empty dataset is immediately obvious.
class ApiDiagnosticsScreen extends StatefulWidget {
  const ApiDiagnosticsScreen({super.key});

  @override
  State<ApiDiagnosticsScreen> createState() => _ApiDiagnosticsScreenState();
}

class _ApiDiagnosticsScreenState extends State<ApiDiagnosticsScreen> {
  List<EndpointProbe> _probes = const [];
  bool _running = false;
  String? _fatal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _fatal = null;
    });
    try {
      final probes = await ApiDiagnostics.runAll();
      if (!mounted) return;
      setState(() => _probes = probes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _fatal = '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  int get _okCount => _probes.where((p) => p.ok).length;

  @override
  Widget build(BuildContext context) {
    final isPhone = Breakpoints.isPhone(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('API diagnostics'),
        actions: [
          IconButton(
            tooltip: 'Re-run health check',
            onPressed: _running ? null : _run,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _run,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            ContentShell(
              maxWidth: isPhone ? 720 : 900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _connectionCard(),
                  const SizedBox(height: 20),
                  if (_fatal != null) ...[
                    _fatalCard(_fatal!),
                    const SizedBox(height: 20),
                  ],
                  if (_running && _probes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    SectionHeader(
                      eyebrowText: 'Endpoints',
                      title: _probes.isEmpty
                          ? 'No results'
                          : '$_okCount of ${_probes.length} responding',
                    ),
                    const SizedBox(height: 14),
                    for (final probe in _probes) ...[
                      _ProbeCard(probe: probe, onCopy: _copy),
                      const SizedBox(height: 14),
                    ],
                  ],
                  const SizedBox(height: 10),
                  _trafficCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Connection summary ──────────────────────────────────────────

  Widget _connectionCard() {
    final allOk = _probes.isNotEmpty && _probes.every((p) => p.ok);
    final anyOk = _probes.any((p) => p.ok);
    final color = _probes.isEmpty
        ? Lux.goldDeep
        : allOk
            ? Lux.success
            : anyOk
                ? Lux.goldDeep
                : Lux.error;
    final label = _probes.isEmpty
        ? 'Not checked yet'
        : allOk
            ? 'Backend reachable'
            : anyOk
                ? 'Partially reachable'
                : 'Backend unreachable';

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: Lux.title(context, size: 16)),
              ),
              if (_running)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _kv('Base URL', ApiConfig.baseUrl),
          const SizedBox(height: 8),
          _kv('API key', _maskKey(ApiConfig.apiKey)),
          const SizedBox(height: 8),
          _kv('Store ID', ApiConfig.storeId),
          const SizedBox(height: 8),
          _kv('Connect timeout', '${ApiConfig.connectTimeout.inSeconds}s'),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: PremiumButton(
                  label: _running ? 'Checking…' : 'Test connection',
                  icon: Icons.wifi_tethering_rounded,
                  loading: _running,
                  onPressed: _running ? null : _run,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _maskKey(String key) {
    if (key.length <= 12) return key;
    return '${key.substring(0, 10)}…${key.substring(key.length - 4)}';
  }

  Widget _kv(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 116,
          child: Text(label, style: Lux.caption(context, size: 12)),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: Lux.goldDeep,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _fatalCard(String message) {
    return PremiumCard(
      color: Lux.errorSoft,
      border: Border.all(color: Lux.error.withValues(alpha: 0.3)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Lux.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: Lux.body(context, size: 13)),
          ),
        ],
      ),
    );
  }

  // ── Live traffic ────────────────────────────────────────────────

  Widget _trafficCard() {
    final entries = ApiService.log;
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow('Recent traffic'),
                    const SizedBox(height: 6),
                    Text('${entries.length} exchange(s)',
                        style: Lux.title(context, size: 15)),
                  ],
                ),
              ),
              TextButton(
                onPressed: entries.isEmpty
                    ? null
                    : () => setState(ApiService.clearLog),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Verbose console logging',
                style: Lux.title(context, size: 14.5)),
            subtitle: Text(
              'Print every request and response to the Flutter console',
              style: Lux.caption(context, size: 11.5),
            ),
            value: ApiService.debugLogging,
            onChanged: (v) => setState(() => ApiService.debugLogging = v),
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No requests recorded yet. Run a search or tap Test connection.',
                style: Lux.body(context, size: 13),
              ),
            )
          else
            for (final e in entries.take(12))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      e.ok ? Icons.check_circle_outline_rounded
                           : Icons.error_outline_rounded,
                      size: 16,
                      color: e.ok ? Lux.success : Lux.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        e.headline,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    if (e.detail.length < 400)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Copy response',
                        onPressed: () => _copy(e.detail),
                        icon: const Icon(Icons.copy_rounded, size: 15),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// One endpoint's result, with the raw body behind an expander.
class _ProbeCard extends StatelessWidget {
  final EndpointProbe probe;
  final void Function(String) onCopy;

  const _ProbeCard({required this.probe, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final color = probe.ok ? Lux.success : Lux.error;
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(probe.label, style: Lux.title(context, size: 15.5)),
              ),
              StatusBadge(
                label: '${probe.statusCode ?? 'ERR'}',
                color: color,
                icon: probe.ok
                    ? Icons.check_rounded
                    : Icons.close_rounded,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('${probe.durationMs}ms',
                  style: Lux.caption(context, size: 11.5)),
              if (probe.rowCount != null) ...[
                Text('  ·  ', style: Lux.caption(context, size: 11.5)),
                Text(
                  '${probe.rowCount} row${probe.rowCount == 1 ? '' : 's'}',
                  style: Lux.caption(context, size: 11.5).copyWith(
                    color: probe.isUnexpectedlyEmpty ? Lux.goldDeep : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            probe.url,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.5,
              color: Lux.goldDeep,
            ),
          ),
          if (probe.error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Lux.errorSoft,
                borderRadius: BorderRadius.circular(Lux.rSm),
                border: Border.all(color: Lux.error.withValues(alpha: 0.3)),
              ),
              child: Text(
                probe.error!,
                style: Lux.body(context, size: 12.5)
                    .copyWith(color: Lux.error),
              ),
            ),
          ],
          if (probe.isUnexpectedlyEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Lux.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Lux.rSm),
                border: Border.all(color: Lux.gold.withValues(alpha: 0.35)),
              ),
              child: Text(
                'Endpoint responded successfully but returned no rows. '
                'This is a backend data issue, not a connection problem.',
                style: Lux.body(context, size: 12.5),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 4),
              title: Text('Raw response', style: Lux.title(context, size: 13.5)),
              children: [
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 280),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Lux.darkBg
                        : const Color(0xFFF7F5F0),
                    borderRadius: BorderRadius.circular(Lux.rSm),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      probe.body,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        height: 1.45,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: GhostButton(
                    label: 'Copy response',
                    icon: Icons.copy_rounded,
                    onPressed: () => onCopy(probe.body),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
