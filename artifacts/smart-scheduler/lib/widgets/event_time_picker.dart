import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import 'stadium_cupertino_picker_selection_overlay.dart';

enum _TimeEntryComponent { hour, minute }

enum _HourEntryFormat { twelveHour, twentyFourHour }

/// Three-column event-time picker with inline numeric entry for hour/minute.
///
/// Tapping the selected band opens the platform numeric keyboard. Valid hour
/// and minute edits immediately animate their corresponding looping wheels.
class EventTimePicker extends StatefulWidget {
  const EventTimePicker({
    super.key,
    required this.initialTime,
    required this.onChanged,
  });

  final DateTime initialTime;
  final ValueChanged<DateTime> onChanged;

  @override
  State<EventTimePicker> createState() => _EventTimePickerState();
}

class _EventTimePickerState extends State<EventTimePicker> {
  static const double _kMagnification = 2.35 / 2.1;
  static const Duration _entryScrollDuration = Duration(milliseconds: 260);
  static const _hourEntryFormat = _HourEntryFormat.twelveHour;

  static final _kStyleBase = TextStyle(
    inherit: false,
    fontFamily: kSFProText,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: kPrimaryLabel,
    letterSpacing: kTracking17,
  );

  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;
  late FixedExtentScrollController _periodCtrl;
  late TextEditingController _entryController;
  late FocusNode _entryFocusNode;

  late int _hour12;
  late int _minute;
  late int _period;
  _TimeEntryComponent _entryComponent = _TimeEntryComponent.hour;
  String _hourEntryDigits = '';
  String _minuteEntryDigits = '';
  bool _isTimeEntryMode = false;
  bool _wasKeyboardVisible = false;
  bool _isWheelInteractionActive = false;
  bool _isFinishingTimeEntry = false;
  bool _suppressHourWheelCallbacks = false;
  bool _suppressMinuteWheelCallbacks = false;
  bool _suppressPeriodWheelCallbacks = false;
  int _wheelInteractionGeneration = 0;
  int _hourAnimationGeneration = 0;
  int _minuteAnimationGeneration = 0;
  int _periodAnimationGeneration = 0;

  @override
  void initState() {
    super.initState();
    final time = widget.initialTime;
    _period = time.hour >= 12 ? 1 : 0;
    _hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    _minute = time.minute;
    _hourCtrl = FixedExtentScrollController(initialItem: _hour12 - 1);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
    _periodCtrl = FixedExtentScrollController(initialItem: _period);
    _entryController = TextEditingController();
    _entryFocusNode = FocusNode();
    _entryFocusNode.addListener(_handleEntryFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (_isTimeEntryMode && _wasKeyboardVisible && !keyboardVisible) {
      final wheelGeneration = _wheelInteractionGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_isTimeEntryMode) return;
        if (_isWheelInteractionActive ||
            wheelGeneration != _wheelInteractionGeneration) {
          _requestEntryFocus();
          return;
        }
        _finishTimeEntry();
      });
    }
    _wasKeyboardVisible = keyboardVisible;
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _periodCtrl.dispose();
    _entryController.dispose();
    _entryFocusNode.removeListener(_handleEntryFocusChange);
    _entryFocusNode.dispose();
    super.dispose();
  }

  void _handleEntryFocusChange() {
    if (!_entryFocusNode.hasFocus &&
        _isTimeEntryMode &&
        _isWheelInteractionActive &&
        !_isFinishingTimeEntry) {
      // Keep the native keypad attached while the wheel is being dragged.
      // iOS can implicitly resign a text field when a scroll gesture starts.
      _entryFocusNode.requestFocus();
    }
  }

  double get _itemExtent => cupertinoDatePickerItemExtent(context);

  double get _height => cupertinoDatePickerHeight(context);

  TextStyle get _kStyle => resolveThemeTextStyle(_kStyleBase, context);

  static int _positiveModulo(int value, int divisor) =>
      ((value % divisor) + divisor) % divisor;

  int _nearestLoopIndex(
    FixedExtentScrollController controller,
    int desiredIndex,
    int itemCount,
  ) {
    final currentIndex = controller.hasClients
        ? controller.selectedItem
        : desiredIndex;
    final currentModulo = _positiveModulo(currentIndex, itemCount);
    final forward = _positiveModulo(desiredIndex - currentModulo, itemCount);
    final backward = forward - itemCount;
    return currentIndex +
        (forward.abs() <= backward.abs() ? forward : backward);
  }

  String get _acceptedEntryDigits => '$_hourEntryDigits$_minuteEntryDigits';

  void _beginTimeEntry() {
    _hourEntryDigits = '';
    _minuteEntryDigits = '';
    _entryComponent = _TimeEntryComponent.hour;
    _entryController.clear();
    if (!_isTimeEntryMode) {
      setState(() => _isTimeEntryMode = true);
    }
    _requestEntryFocus();
  }

  void _requestEntryFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isTimeEntryMode) _entryFocusNode.requestFocus();
    });
  }

  void _finishTimeEntry() {
    if (!_isTimeEntryMode) return;
    _isFinishingTimeEntry = true;
    _isWheelInteractionActive = false;
    _wheelInteractionGeneration++;
    _entryFocusNode.unfocus();
    _entryController.clear();
    _hourEntryDigits = '';
    _minuteEntryDigits = '';
    _entryComponent = _TimeEntryComponent.hour;
    setState(() => _isTimeEntryMode = false);
    _isFinishingTimeEntry = false;
  }

  void _notify() {
    final hour24 = _period == 0
        ? (_hour12 == 12 ? 0 : _hour12)
        : (_hour12 == 12 ? 12 : _hour12 + 12);
    widget.onChanged(
      DateTime(
        widget.initialTime.year,
        widget.initialTime.month,
        widget.initialTime.day,
        hour24,
        _minute,
      ),
    );
  }

  Future<void> _animateHourTo(int hour12) async {
    final target = _nearestLoopIndex(_hourCtrl, hour12 - 1, 12);
    if (!_hourCtrl.hasClients || _hourCtrl.selectedItem == target) return;
    final generation = ++_hourAnimationGeneration;
    _suppressHourWheelCallbacks = true;
    try {
      await _hourCtrl.animateToItem(
        target,
        duration: _entryScrollDuration,
        curve: Curves.easeOutCubic,
      );
    } finally {
      if (generation == _hourAnimationGeneration) {
        _suppressHourWheelCallbacks = false;
      }
    }
  }

  Future<void> _animateMinuteTo(int minute) async {
    final target = _nearestLoopIndex(_minuteCtrl, minute, 60);
    if (!_minuteCtrl.hasClients || _minuteCtrl.selectedItem == target) return;
    final generation = ++_minuteAnimationGeneration;
    _suppressMinuteWheelCallbacks = true;
    try {
      await _minuteCtrl.animateToItem(
        target,
        duration: _entryScrollDuration,
        curve: Curves.easeOutCubic,
      );
    } finally {
      if (generation == _minuteAnimationGeneration) {
        _suppressMinuteWheelCallbacks = false;
      }
    }
  }

  Future<void> _animatePeriodTo(int period) async {
    if (!_periodCtrl.hasClients || _periodCtrl.selectedItem == period) return;
    final generation = ++_periodAnimationGeneration;
    _suppressPeriodWheelCallbacks = true;
    try {
      await _periodCtrl.animateToItem(
        period,
        duration: _entryScrollDuration,
        curve: Curves.easeOutCubic,
      );
    } finally {
      if (generation == _periodAnimationGeneration) {
        _suppressPeriodWheelCallbacks = false;
      }
    }
  }

  void _setHourFromEntry(int hour12) {
    if (hour12 < 1 || hour12 > 12 || hour12 == _hour12) return;
    _hour12 = hour12;
    _notify();
    _animateHourTo(hour12);
  }

  void _setHourFromEntryValue(int hourValue) {
    if (_hourEntryFormat == _HourEntryFormat.twelveHour) {
      _setHourFromEntry(hourValue);
      return;
    }

    final hour12 = hourValue % 12 == 0 ? 12 : hourValue % 12;
    final period = hourValue >= 12 ? 1 : 0;
    final hourChanged = hour12 != _hour12;
    final periodChanged = period != _period;
    if (!hourChanged && !periodChanged) return;
    _hour12 = hour12;
    _period = period;
    _notify();
    if (hourChanged) _animateHourTo(hour12);
    if (periodChanged) _animatePeriodTo(period);
  }

  void _setMinuteFromEntry(int minute) {
    if (minute < 0 || minute > 59 || minute == _minute) return;
    _minute = minute;
    _notify();
    _animateMinuteTo(minute);
  }

  bool _hourCanBeTwoDigitPrefix(int firstDigit) {
    return switch (_hourEntryFormat) {
      _HourEntryFormat.twelveHour => firstDigit == 0 || firstDigit == 1,
      _HourEntryFormat.twentyFourHour =>
        firstDigit == 0 || firstDigit == 1 || firstDigit == 2,
    };
  }

  bool _isValidTwoDigitHour(int candidate) {
    return switch (_hourEntryFormat) {
      _HourEntryFormat.twelveHour => candidate >= 10 && candidate <= 12,
      _HourEntryFormat.twentyFourHour => candidate >= 0 && candidate <= 23,
    };
  }

  int? _meaningfulHourValue(String digits) {
    if (digits.isEmpty) return null;
    final candidate = int.tryParse(digits);
    if (candidate == null) return null;
    return switch (_hourEntryFormat) {
      _HourEntryFormat.twelveHour when candidate >= 1 && candidate <= 12 =>
        candidate,
      _HourEntryFormat.twentyFourHour when candidate <= 23 => candidate,
      _ => null,
    };
  }

  void _acceptDigit(int digit) {
    if (_entryComponent == _TimeEntryComponent.hour) {
      _acceptHourDigit(digit);
    } else {
      _acceptMinuteDigit(digit);
    }
  }

  void _acceptHourDigit(int digit) {
    if (_hourEntryDigits.isEmpty) {
      _hourEntryDigits = '$digit';
      if (digit == 0) return; // A leading zero is only a pending prefix.
      _setHourFromEntryValue(digit);
      if (!_hourCanBeTwoDigitPrefix(digit)) {
        _entryComponent = _TimeEntryComponent.minute;
      }
      return;
    }

    final firstDigit = int.parse(_hourEntryDigits);
    if (firstDigit == 0 && _hourEntryFormat == _HourEntryFormat.twelveHour) {
      if (digit == 0) return;
      _hourEntryDigits = '0$digit';
      _setHourFromEntryValue(digit);
      _entryComponent = _TimeEntryComponent.minute;
      return;
    }

    final candidate = firstDigit * 10 + digit;
    if (_isValidTwoDigitHour(candidate)) {
      _hourEntryDigits = '$_hourEntryDigits$digit';
      _setHourFromEntryValue(candidate);
      _entryComponent = _TimeEntryComponent.minute;
      return;
    }

    if (firstDigit == 0) return;

    // The attempted second hour digit is discarded. A pending 1 remains the
    // selected hour, and the next newly typed digit belongs to minutes.
    _entryComponent = _TimeEntryComponent.minute;
  }

  void _acceptMinuteDigit(int digit) {
    if (_minuteEntryDigits.isEmpty) {
      _minuteEntryDigits = '$digit';
      _setMinuteFromEntry(digit);
      return;
    }

    if (_minuteEntryDigits.length >= 2) return;
    final candidate = int.parse('$_minuteEntryDigits$digit');
    if (candidate > 59) return;
    _minuteEntryDigits = '$_minuteEntryDigits$digit';
    _setMinuteFromEntry(candidate);
  }

  void _backspaceEntry() {
    if (_entryComponent == _TimeEntryComponent.minute &&
        _minuteEntryDigits.isNotEmpty) {
      _minuteEntryDigits = _minuteEntryDigits.substring(
        0,
        _minuteEntryDigits.length - 1,
      );
      if (_minuteEntryDigits.isNotEmpty) {
        _setMinuteFromEntry(int.parse(_minuteEntryDigits));
      }
      return;
    }

    if (_entryComponent == _TimeEntryComponent.minute) {
      _entryComponent = _TimeEntryComponent.hour;
    }
    if (_hourEntryDigits.isEmpty) return;

    _hourEntryDigits = _hourEntryDigits.substring(
      0,
      _hourEntryDigits.length - 1,
    );
    final remainingHour = _meaningfulHourValue(_hourEntryDigits);
    if (remainingHour != null) _setHourFromEntryValue(remainingHour);
  }

  void _handleEntryTextChanged(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    final accepted = _acceptedEntryDigits;
    var commonPrefixLength = 0;
    while (commonPrefixLength < accepted.length &&
        commonPrefixLength < digits.length &&
        accepted[commonPrefixLength] == digits[commonPrefixLength]) {
      commonPrefixLength++;
    }

    while (_acceptedEntryDigits.length > commonPrefixLength) {
      _backspaceEntry();
    }
    for (var i = commonPrefixLength; i < digits.length; i++) {
      _acceptDigit(int.parse(digits[i]));
    }
    _syncEntryController();
  }

  void _syncEntryController() {
    final accepted = _acceptedEntryDigits;
    if (_entryController.text == accepted) return;
    _entryController.value = TextEditingValue(
      text: accepted,
      selection: TextSelection.collapsed(offset: accepted.length),
    );
  }

  void _onManualWheelScrollStart(_TimeEntryComponent? component) {
    _isWheelInteractionActive = true;
    _wheelInteractionGeneration++;
    if (component == _TimeEntryComponent.hour) {
      _hourAnimationGeneration++;
      _suppressHourWheelCallbacks = false;
    } else if (component == _TimeEntryComponent.minute) {
      _minuteAnimationGeneration++;
      _suppressMinuteWheelCallbacks = false;
    } else {
      _periodAnimationGeneration++;
      _suppressPeriodWheelCallbacks = false;
    }
    if (!_isTimeEntryMode) return;

    // Direct manipulation is authoritative; no pending digit may later
    // overwrite the wheel the user just changed.
    _hourEntryDigits = '';
    _minuteEntryDigits = '';
    _entryComponent = component ?? _TimeEntryComponent.hour;
    _syncEntryController();
  }

  void _onManualWheelScrollEnd() {
    if (!_isWheelInteractionActive) return;
    _isWheelInteractionActive = false;
    _wheelInteractionGeneration++;
    if (_isTimeEntryMode) _requestEntryFocus();
  }

  Widget _loopingBarrel({
    required Key wheelKey,
    required FixedExtentScrollController controller,
    required List<Widget> children,
    required void Function(int) onChanged,
    _TimeEntryComponent? entryComponent,
    double offAxisFraction = 0.0,
    bool capStart = true,
    bool capEnd = true,
    bool loop = true,
  }) {
    final count = children.length;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: _isTimeEntryMode
          ? null
          : (details) {
              final centerY = _height / 2;
              if ((details.localPosition.dy - centerY).abs() <=
                  _itemExtent / 2) {
                _beginTimeEntry();
              }
            },
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.depth != 0) return false;
              if (notification is ScrollStartNotification &&
                  notification.dragDetails != null) {
                _onManualWheelScrollStart(entryComponent);
              }
              if (notification is ScrollEndNotification) {
                _onManualWheelScrollEnd();
              }
              // Keep the wheel's drag updates from reaching an enclosing
              // ScrollView's on-drag keyboard dismissal handler.
              return notification is ScrollUpdateNotification;
            },
            child: ListWheelScrollView.useDelegate(
              key: wheelKey,
              controller: controller,
              itemExtent: _itemExtent,
              physics: const FixedExtentScrollPhysics(),
              diameterRatio: 1.07,
              perspective: 0.003,
              squeeze: 1.25,
              magnification: _kMagnification,
              useMagnifier: true,
              overAndUnderCenterOpacity: 0.447,
              offAxisFraction: offAxisFraction,
              childDelegate: loop
                  ? ListWheelChildLoopingListDelegate(children: children)
                  : ListWheelChildListDelegate(children: children),
              onSelectedItemChanged: loop
                  ? (index) => onChanged(_positiveModulo(index, count))
                  : onChanged,
            ),
          ),
          IgnorePointer(
            child: Center(
              child: SizedBox(
                height: _itemExtent,
                width: double.infinity,
                child: StadiumCupertinoPickerSelectionOverlay(
                  capStartEdge: capStart,
                  capEndEdge: capEnd,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryField() {
    return CupertinoTextField(
      key: const ValueKey('event-time-numeric-input'),
      controller: _entryController,
      focusNode: _entryFocusNode,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      textAlign: TextAlign.center,
      textAlignVertical: TextAlignVertical.center,
      style: _kStyle.copyWith(color: CupertinoColors.transparent),
      cursorColor: CupertinoColors.transparent,
      cursorWidth: 0,
      showCursor: false,
      enableInteractiveSelection: false,
      decoration: const BoxDecoration(
        color: CupertinoColors.transparent,
        border: Border.fromBorderSide(BorderSide.none),
      ),
      padding: EdgeInsets.zero,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: _handleEntryTextChanged,
    );
  }

  Widget _buildEntryOverlay() {
    return Positioned.fill(
      child: Center(
        child: SizedBox(
          width: double.infinity,
          height: _itemExtent,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: IgnorePointer(child: _buildEntryField()),
              ),
              Expanded(child: IgnorePointer(child: SizedBox.expand())),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hourPicker = _loopingBarrel(
      wheelKey: const ValueKey('event-time-hour-wheel'),
      controller: _hourCtrl,
      offAxisFraction: -0.60,
      capStart: true,
      capEnd: false,
      entryComponent: _TimeEntryComponent.hour,
      onChanged: (index) {
        if (_suppressHourWheelCallbacks) return;
        _hour12 = index + 1;
        _notify();
      },
      children: List.generate(
        12,
        (index) => Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text('${index + 1}', style: _kStyle),
          ),
        ),
      ),
    );
    final minutePicker = _loopingBarrel(
      wheelKey: const ValueKey('event-time-minute-wheel'),
      controller: _minuteCtrl,
      offAxisFraction: 0,
      capStart: false,
      capEnd: false,
      entryComponent: _TimeEntryComponent.minute,
      onChanged: (index) {
        if (_suppressMinuteWheelCallbacks) return;
        _minute = index;
        _notify();
      },
      children: List.generate(
        60,
        (index) => Center(
          child: Text(index.toString().padLeft(2, '0'), style: _kStyle),
        ),
      ),
    );
    final periodPicker = _loopingBarrel(
      wheelKey: const ValueKey('event-time-period-wheel'),
      controller: _periodCtrl,
      offAxisFraction: 0.45,
      capStart: false,
      capEnd: true,
      loop: false,
      onChanged: (index) {
        if (_suppressPeriodWheelCallbacks) return;
        _period = index;
        _notify();
      },
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text('AM', style: _kStyle),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text('PM', style: _kStyle),
          ),
        ),
      ],
    );

    return SizedBox(
      height: _height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Row(
            children: [
              Expanded(child: hourPicker),
              Expanded(child: minutePicker),
              Expanded(child: periodPicker),
            ],
          ),
          if (_isTimeEntryMode) _buildEntryOverlay(),
        ],
      ),
    );
  }
}
