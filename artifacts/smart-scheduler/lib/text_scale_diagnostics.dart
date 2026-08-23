import 'package:flutter/cupertino.dart';
import 'app_settings.dart';
import 'app_theme.dart';

const _diagnosticSizes = <double>[8, 12, 16, 20, 24, 32, 40, 48, 64, 80];

class TextScaleDiagnosticsSection extends StatefulWidget {
  const TextScaleDiagnosticsSection({super.key});

  @override
  State<TextScaleDiagnosticsSection> createState() =>
      _TextScaleDiagnosticsSectionState();
}

class _TextScaleDiagnosticsSectionState
    extends State<TextScaleDiagnosticsSection> {
  Map<Object?, Object?>? _payload;
  String? _error;
  int _selectedPosition = 0;
  final Map<int, _DiagnosticSnapshot> _snapshots = <int, _DiagnosticSnapshot>{};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final payload = await fetchTextScaleDiagnosticProfile().timeout(
        const Duration(seconds: 8),
      );
      if (!mounted) return;
      if (payload == null || _parseProfile(payload) == null) {
        setState(() {
          _payload = null;
          _error =
              'Android returned an incomplete text-scale profile. Check that this is the diagnostic APK and tap Refresh native profile.';
        });
        return;
      }
      setState(() {
        _payload = payload;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _payload = null;
        _error = 'Native profile request failed or timed out: $error';
      });
    }
  }

  void _capture(BuildContext context) {
    final payload = _payload;
    if (payload == null) return;
    final profile = _parseProfile(payload);
    if (profile == null) return;
    final scaler = MediaQuery.textScalerOf(context);
    final currentScale =
        (payload['currentScale'] as num?)?.toDouble() ?? scaler.scale(16) / 16;
    final flutterTextScaleFactor = scaler.scale(16) / 16;
    var nativeIndex = 0;
    var closest = double.infinity;
    for (var i = 0; i < profile.stops.length; i++) {
      final distance = (profile.stops[i] - currentScale).abs();
      if (distance < closest) {
        closest = distance;
        nativeIndex = i;
      }
    }
    final nativeRatios = profile.curves[nativeIndex];
    final values = <_DiagnosticValue>[
      for (var i = 0; i < _diagnosticSizes.length; i++)
        _DiagnosticValue(
          size: _diagnosticSizes[i],
          flutter: scaler.scale(_diagnosticSizes[i]),
          native: _interpolatedNativeValue(
            _diagnosticSizes[i],
            profile.probeSizes,
            nativeRatios,
          ),
        ),
    ];
    final metrics = _parseMetrics(payload['activeMetrics']);
    final nativeMetrics = nativeIndex < profile.stopMetrics.length
        ? profile.stopMetrics[nativeIndex]
        : null;
    setState(() {
      _snapshots[_selectedPosition] = _DiagnosticSnapshot(
        osPosition: _selectedPosition,
        nativeCurrentScale: currentScale,
        flutterTextScaleFactor: flutterTextScaleFactor,
        nativeStop: profile.stops[nativeIndex],
        nativeIndex: nativeIndex,
        fontScale: (payload['activeConfigurationFontScale'] as num?)
            ?.toDouble(),
        metrics: metrics,
        nativeMetrics: nativeMetrics,
        values: values,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = resolveThemeColor(kCardColor, context);
    final labelColor = resolveThemeColor(kPrimaryLabel, context);
    final secondaryColor = resolveThemeColor(kSecondaryLabel, context);
    final profile = _payload == null ? null : _parseProfile(_payload!);
    final usesSystem = appTextSizeUsesSystemNotifier.value;
    final snapshot = _snapshots[_selectedPosition];

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Diagnostic only. This page never changes text-size settings.',
              style: TextStyle(
                fontFamily: kSFProText,
                fontSize: 14,
                color: secondaryColor,
              ),
            ),
            const SizedBox(height: 12),
            if (!usesSystem)
              _DiagnosticNotice(
                text:
                    'Select System before capturing. Measurements use the real ambient Flutter scaler, not Custom.',
                color: secondaryColor,
              ),
            if (_error != null)
              _DiagnosticNotice(
                text: 'Profile error: $_error',
                color: labelColor,
              ),
            if (profile == null && _error == null)
              _DiagnosticNotice(
                text: 'Loading native profile…',
                color: secondaryColor,
              ),
            if (profile != null) ...[
              _buildPositionPicker(context, cardColor, labelColor),
              const SizedBox(height: 12),
              CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(vertical: 11),
                onPressed: usesSystem ? () => _capture(context) : null,
                child: Text('Capture N${_selectedPosition + 1}'),
              ),
              const SizedBox(height: 14),
              if (snapshot != null)
                _SnapshotCard(
                  snapshot: snapshot,
                  cardColor: cardColor,
                  labelColor: labelColor,
                  secondaryColor: secondaryColor,
                )
              else
                _DiagnosticNotice(
                  text:
                      'Set the phone to N${_selectedPosition + 1}, return here, and tap Capture.',
                  color: secondaryColor,
                ),
              const SizedBox(height: 14),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _refresh,
                child: const Text('Refresh native profile'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPositionPicker(
    BuildContext context,
    Color cardColor,
    Color labelColor,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(kCardCornerRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: _selectedPosition,
          children: <int, Widget>{
            for (var i = 0; i < 5; i++)
              i: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'N${i + 1}',
                  style: TextStyle(color: labelColor, fontSize: 13),
                ),
              ),
          },
          onValueChanged: (value) {
            if (value != null) setState(() => _selectedPosition = value);
          },
        ),
      ),
    );
  }

  _NativeProfile? _parseProfile(Map<Object?, Object?> payload) {
    final rawStops = payload['stops'];
    final rawProbes = payload['probeSizes'];
    final rawCurves = payload['curves'];
    if (rawStops is! List ||
        rawProbes is! List ||
        rawCurves is! List ||
        rawStops.length != rawCurves.length) {
      return null;
    }
    final stops = rawStops.whereType<num>().map((e) => e.toDouble()).toList();
    final probes = rawProbes.whereType<num>().map((e) => e.toDouble()).toList();
    final curves = <List<double>>[];
    for (final rawCurve in rawCurves) {
      if (rawCurve is! List) return null;
      curves.add(rawCurve.whereType<num>().map((e) => e.toDouble()).toList());
    }
    final rawStopMetrics = payload['stopMetrics'];
    final stopMetrics = rawStopMetrics is List
        ? rawStopMetrics.map(_parseMetrics).toList()
        : <_DiagnosticMetrics?>[];
    if (stops.isEmpty || probes.length < 2) return null;
    return _NativeProfile(
      stops: stops,
      probeSizes: probes,
      curves: curves,
      stopMetrics: stopMetrics,
    );
  }
}

class _NativeProfile {
  final List<double> stops;
  final List<double> probeSizes;
  final List<List<double>> curves;
  final List<_DiagnosticMetrics?> stopMetrics;
  const _NativeProfile({
    required this.stops,
    required this.probeSizes,
    required this.curves,
    required this.stopMetrics,
  });
}

class _DiagnosticSnapshot {
  final int osPosition;
  final double nativeCurrentScale;
  final double flutterTextScaleFactor;
  final double nativeStop;
  final int nativeIndex;
  final double? fontScale;
  final _DiagnosticMetrics? metrics;
  final _DiagnosticMetrics? nativeMetrics;
  final List<_DiagnosticValue> values;
  const _DiagnosticSnapshot({
    required this.osPosition,
    required this.nativeCurrentScale,
    required this.flutterTextScaleFactor,
    required this.nativeStop,
    required this.nativeIndex,
    required this.fontScale,
    required this.metrics,
    required this.nativeMetrics,
    required this.values,
  });
}

class _DiagnosticValue {
  final double size;
  final double flutter;
  final double native;
  const _DiagnosticValue({
    required this.size,
    required this.flutter,
    required this.native,
  });
  double get difference => flutter - native;
}

class _DiagnosticMetrics {
  final double density;
  final double scaledDensity;
  final int densityDpi;
  final double ratio;
  const _DiagnosticMetrics({
    required this.density,
    required this.scaledDensity,
    required this.densityDpi,
    required this.ratio,
  });
}

double _interpolatedNativeValue(
  double size,
  List<double> probes,
  List<double> ratios,
) {
  if (ratios.isEmpty) return size;
  if (size <= probes.first) return size * ratios.first;
  for (var i = 1; i < probes.length && i < ratios.length; i++) {
    if (size <= probes[i]) {
      final t = (size - probes[i - 1]) / (probes[i] - probes[i - 1]);
      final ratio = ratios[i - 1] + (ratios[i] - ratios[i - 1]) * t;
      return size * ratio;
    }
  }
  return size * ratios.last;
}

_DiagnosticMetrics? _parseMetrics(Object? raw) {
  if (raw is! Map) return null;
  final density = (raw['density'] as num?)?.toDouble();
  final scaledDensity = (raw['scaledDensity'] as num?)?.toDouble();
  final densityDpi = (raw['densityDpi'] as num?)?.toInt();
  final ratio = (raw['scaledDensityOverDensity'] as num?)?.toDouble();
  if (density == null ||
      scaledDensity == null ||
      densityDpi == null ||
      ratio == null) {
    return null;
  }
  return _DiagnosticMetrics(
    density: density,
    scaledDensity: scaledDensity,
    densityDpi: densityDpi,
    ratio: ratio,
  );
}

class _DiagnosticNotice extends StatelessWidget {
  final String text;
  final Color color;
  const _DiagnosticNotice({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: TextStyle(fontFamily: kSFProText, fontSize: 14, color: color),
      ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  final _DiagnosticSnapshot snapshot;
  final Color cardColor;
  final Color labelColor;
  final Color secondaryColor;
  const _SnapshotCard({
    required this.snapshot,
    required this.cardColor,
    required this.labelColor,
    required this.secondaryColor,
  });

  String _number(double? value) =>
      value == null ? '—' : value.toStringAsFixed(6);

  @override
  Widget build(BuildContext context) {
    final metrics = snapshot.metrics;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(kCardCornerRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'N${snapshot.osPosition + 1} captured',
              style: TextStyle(
                fontFamily: kSFProText,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 8),
            _MetricLine(
              'Configuration.fontScale',
              _number(snapshot.fontScale),
              secondaryColor,
            ),
            _MetricLine(
              'Flutter textScaleFactor',
              _number(snapshot.flutterTextScaleFactor),
              secondaryColor,
            ),
            _MetricLine(
              'Native currentScale',
              _number(snapshot.nativeCurrentScale),
              secondaryColor,
            ),
            _MetricLine(
              'Native stop value',
              _number(snapshot.nativeStop),
              secondaryColor,
            ),
            _MetricLine(
              'DisplayMetrics.density',
              _number(metrics?.density),
              secondaryColor,
            ),
            _MetricLine(
              'DisplayMetrics.scaledDensity',
              _number(metrics?.scaledDensity),
              secondaryColor,
            ),
            _MetricLine(
              'densityDpi',
              '${metrics?.densityDpi ?? '—'}',
              secondaryColor,
            ),
            _MetricLine(
              'scaledDensity / density',
              _number(metrics?.ratio),
              secondaryColor,
            ),
            const SizedBox(height: 8),
            Text(
              'Native createConfigurationContext() metrics',
              style: TextStyle(fontSize: 13, color: labelColor),
            ),
            _MetricLine(
              'density',
              _number(snapshot.nativeMetrics?.density),
              secondaryColor,
            ),
            _MetricLine(
              'scaledDensity',
              _number(snapshot.nativeMetrics?.scaledDensity),
              secondaryColor,
            ),
            _MetricLine(
              'densityDpi',
              '${snapshot.nativeMetrics?.densityDpi ?? '—'}',
              secondaryColor,
            ),
            _MetricLine(
              'scaledDensity / density',
              _number(snapshot.nativeMetrics?.ratio),
              secondaryColor,
            ),
            const SizedBox(height: 12),
            const _DiagnosticHeader(),
            for (final value in snapshot.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        _number(value.size),
                        style: TextStyle(
                          fontFamily: kSFProText,
                          fontSize: 12,
                          color: secondaryColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _number(value.flutter),
                        style: TextStyle(
                          fontFamily: kSFProText,
                          fontSize: 12,
                          color: labelColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _number(value.native),
                        style: TextStyle(
                          fontFamily: kSFProText,
                          fontSize: 12,
                          color: labelColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _number(value.difference),
                        style: TextStyle(
                          fontFamily: kSFProText,
                          fontSize: 12,
                          color: labelColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticHeader extends StatelessWidget {
  const _DiagnosticHeader();
  @override
  Widget build(BuildContext context) {
    final color = resolveThemeColor(kSecondaryLabel, context);
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text('sp', style: TextStyle(fontSize: 11, color: color)),
        ),
        Expanded(
          child: Text('Flutter', style: TextStyle(fontSize: 11, color: color)),
        ),
        Expanded(
          child: Text('Native', style: TextStyle(fontSize: 11, color: color)),
        ),
        Expanded(
          child: Text('Diff', style: TextStyle(fontSize: 11, color: color)),
        ),
      ],
    );
  }
}

class _MetricLine extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricLine(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 13, color: color)),
          ),
          Text(value, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }
}
