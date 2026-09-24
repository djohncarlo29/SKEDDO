import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Uses the native SwiftUI slider row on iOS. Callers keep their Flutter
/// implementation for every other platform.
class NativeFluidSliderRow extends StatefulWidget {
  final double value;
  final double minimumValue;
  final double maximumValue;
  final String minimumIcon;
  final String maximumIcon;
  final double iconSize;
  final Color accentColor;
  final bool darkMode;
  final double height;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final ValueChanged<double>? onChangeStart;

  const NativeFluidSliderRow({
    super.key,
    required this.value,
    required this.minimumValue,
    required this.maximumValue,
    required this.minimumIcon,
    required this.maximumIcon,
    required this.iconSize,
    required this.accentColor,
    required this.darkMode,
    required this.height,
    required this.onChanged,
    required this.onChangeEnd,
    this.onChangeStart,
  });

  @override
  State<NativeFluidSliderRow> createState() => _NativeFluidSliderRowState();
}

class _NativeFluidSliderRowState extends State<NativeFluidSliderRow> {
  MethodChannel? _methodChannel;
  StreamSubscription<dynamic>? _eventSubscription;

  String _methodChannelName(int viewId) =>
      'com.smartscheduler/native_fluid_slider/$viewId';
  String _eventChannelName(int viewId) =>
      'com.smartscheduler/native_fluid_slider_events/$viewId';

  Map<String, Object> _configuration() => {
    'value': widget.value,
    'minimumValue': widget.minimumValue,
    'maximumValue': widget.maximumValue,
    'minimumIcon': widget.minimumIcon,
    'maximumIcon': widget.maximumIcon,
    'iconSize': widget.iconSize,
    'accentColor': widget.accentColor.toARGB32(),
    'darkMode': widget.darkMode,
  };

  void _onPlatformViewCreated(int viewId) {
    final methodChannel = MethodChannel(_methodChannelName(viewId));
    _methodChannel = methodChannel;
    _eventSubscription = EventChannel(
      _eventChannelName(viewId),
    ).receiveBroadcastStream().listen(_handleNativeEvent);
    unawaited(methodChannel.invokeMethod<void>('update', _configuration()));
  }

  void _handleNativeEvent(dynamic event) {
    if (event is! Map) return;
    final value = event['value'];
    if (value is! num) return;
    final normalized = value.toDouble();
    switch (event['phase']) {
      case 'start':
        widget.onChangeStart?.call(normalized);
        break;
      case 'change':
        widget.onChanged(normalized);
        break;
      case 'end':
        widget.onChangeEnd(normalized);
        break;
    }
  }

  @override
  void didUpdateWidget(covariant NativeFluidSliderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.minimumValue != widget.minimumValue ||
        oldWidget.maximumValue != widget.maximumValue ||
        oldWidget.minimumIcon != widget.minimumIcon ||
        oldWidget.maximumIcon != widget.maximumIcon ||
        oldWidget.iconSize != widget.iconSize ||
        oldWidget.accentColor != widget.accentColor ||
        oldWidget.darkMode != widget.darkMode) {
      final methodChannel = _methodChannel;
      if (methodChannel != null) {
        unawaited(methodChannel.invokeMethod<void>('update', _configuration()));
      }
    }
  }

  @override
  void dispose() {
    unawaited(_eventSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    width: double.infinity,
    child: UiKitView(
      viewType: 'com.smartscheduler/native_fluid_slider',
      creationParams: _configuration(),
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
    ),
  );
}