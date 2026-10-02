import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import 'stadium_cupertino_picker_selection_overlay.dart';

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
  late TextEditingController _hourEntryController;
  late TextEditingController _minuteEntryController;
  late FocusNode _hourEntryFocusNode;
  late FocusNode _minuteEntryFocusNode;

  late int _hour12;
  late int _minute;
  late int _period;
  bool _isTimeEntryMode = false;
  bool _wasKeyboardVisible = false;
  final Object _entryTapRegionGroup = Object();

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
    _hourEntryController = TextEditingController();
    _minuteEntryController = TextEditingController();
    _hourEntryFocusNode = FocusNode();
    _minuteEntryFocusNode = FocusNode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (_isTimeEntryMode && _wasKeyboardVisible && !keyboardVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isTimeEntryMode) _finishTimeEntry();
      });
    }
    _wasKeyboardVisible = keyboardVisible;
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _periodCtrl.dispose();
    _hourEntryController.dispose();
    _minuteEntryController.dispose();
    _hourEntryFocusNode.dispose();
    _minuteEntryFocusNode.dispose();
    super.dispose();
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

  void _beginTimeEntry() {
    _hourEntryController.clear();
    _minuteEntryController.clear();
    if (!_isTimeEntryMode) {
      setState(() => _isTimeEntryMode = true);
    }
    _requestEntryFocus(_hourEntryFocusNode);
  }

  void _requestEntryFocus(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isTimeEntryMode) node.requestFocus();
    });
  }

  void _moveCaretToMinute({int? firstMinuteDigit}) {
    _hourEntryController.clear();
    _minuteEntryController.text = firstMinuteDigit?.toString() ?? '';
    _requestEntryFocus(_minuteEntryFocusNode);
    if (firstMinuteDigit != null) {
      _setMinuteFromEntry(firstMinuteDigit);
    }
  }

  void _onHourFieldTap() {
    if (!_isTimeEntryMode) return;
    _hourEntryController.clear();
    _minuteEntryController.clear();
    _requestEntryFocus(_hourEntryFocusNode);
  }

  void _onMinuteFieldTap() {
    if (!_isTimeEntryMode) return;
    // A lone leading 1 already selects hour 1. Tapping minutes commits it.
    _hourEntryController.clear();
    _minuteEntryController.clear();
    _requestEntryFocus(_minuteEntryFocusNode);
  }

  void _finishTimeEntry() {
    if (!_isTimeEntryMode) return;
    _hourEntryFocusNode.unfocus();
    _minuteEntryFocusNode.unfocus();
    _hourEntryController.clear();
    _minuteEntryController.clear();
    setState(() => _isTimeEntryMode = false);
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

  void _animateHourTo(int hour12) {
    final target = _nearestLoopIndex(_hourCtrl, hour12 - 1, 12);
    if (!_hourCtrl.hasClients || _hourCtrl.selectedItem == target) return;
    _hourCtrl.animateToItem(
      target,
      duration: _entryScrollDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _animateMinuteTo(int minute) {
    final target = _nearestLoopIndex(_minuteCtrl, minute, 60);
    if (!_minuteCtrl.hasClients || _minuteCtrl.selectedItem == target) return;
    _minuteCtrl.animateToItem(
      target,
      duration: _entryScrollDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _setHourFromEntry(int hour12) {
    if (hour12 < 1 || hour12 > 12 || hour12 == _hour12) return;
    _hour12 = hour12;
    _notify();
    _animateHourTo(hour12);
  }

  void _setMinuteFromEntry(int minute) {
    if (minute < 0 || minute > 59 || minute == _minute) return;
    _minute = minute;
    _notify();
    _animateMinuteTo(minute);
  }

  void _handleHourEntry(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;

    final first = int.parse(digits[0]);
    if (digits.length == 1) {
      if (first == 0) return; // A leading zero can form 01–09.
      _setHourFromEntry(first);
      if (first == 1) return; // Could still become 10, 11, or 12.
      _moveCaretToMinute();
      return;
    }

    final second = int.parse(digits[1]);
    if (first == 0) {
      if (second > 0) _setHourFromEntry(second);
      _moveCaretToMinute();
      return;
    }
    if (first == 1) {
      // 10–12 are the only valid two-digit 12-hour values beginning with 1.
      // Any other second digit is rejected; hour 1 remains selected.
      _setHourFromEntry(second <= 2 ? 10 + second : 1);
      _moveCaretToMinute();
      return;
    }

    // Normally a first digit from 2–9 has already advanced to minutes. If
    // several digits arrive in one text update, treat the next digit as the
    // first minute digit rather than losing it.
    _setHourFromEntry(first);
    _moveCaretToMinute(firstMinuteDigit: second);
  }

  void _handleMinuteEntry(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;

    final first = int.parse(digits[0]);
    if (digits.length == 1) {
      // The wheel always renders a leading zero, so 5 immediately appears 05.
      _setMinuteFromEntry(first);
      return;
    }

    final second = int.parse(digits[1]);
    final candidate = first * 10 + second;
    if (candidate <= 59) {
      _setMinuteFromEntry(candidate);
    } else {
      // Keep the valid single-digit value (e.g. 9 → 09) and discard the
      // invalid second digit rather than allowing a value above 59.
      _setMinuteFromEntry(first);
    }
    _minuteEntryController.clear();
  }

  Widget _loopingBarrel({
    required Key wheelKey,
    required FixedExtentScrollController controller,
    required List<Widget> children,
    required void Function(int) onChanged,
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
          ListWheelScrollView.useDelegate(
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

  Widget _buildEntryField({
    required Key key,
    required TextEditingController controller,
    required FocusNode focusNode,
    required TextAlign textAlign,
    required EdgeInsetsGeometry padding,
    required VoidCallback onTap,
    required ValueChanged<String> onChanged,
  }) {
    return CupertinoTextField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      textAlign: textAlign,
      textAlignVertical: TextAlignVertical.center,
      style: _kStyle.copyWith(color: CupertinoColors.transparent),
      cursorColor: resolveThemeColor(kPrimaryLabel, context),
      enableInteractiveSelection: false,
      decoration: const BoxDecoration(
        color: CupertinoColors.transparent,
        border: Border.fromBorderSide(BorderSide.none),
      ),
      padding: padding,
      autocorrect: false,
      enableSuggestions: false,
      onTap: onTap,
      onChanged: onChanged,
      onTapOutside: (_) => _finishTimeEntry(),
    );
  }

  Widget _buildEntryOverlay() {
    return Positioned.fill(
      child: Center(
        child: SizedBox(
          width: double.infinity,
          height: _itemExtent,
          child: TextFieldTapRegion(
            groupId: _entryTapRegionGroup,
            child: Row(
              children: [
                Expanded(
                  child: _buildEntryField(
                    key: const ValueKey('event-time-hour-entry'),
                    controller: _hourEntryController,
                    focusNode: _hourEntryFocusNode,
                    textAlign: TextAlign.right,
                    padding: const EdgeInsets.only(right: 12),
                    onTap: _onHourFieldTap,
                    onChanged: _handleHourEntry,
                  ),
                ),
                Expanded(
                  child: _buildEntryField(
                    key: const ValueKey('event-time-minute-entry'),
                    controller: _minuteEntryController,
                    focusNode: _minuteEntryFocusNode,
                    textAlign: TextAlign.center,
                    padding: EdgeInsets.zero,
                    onTap: _onMinuteFieldTap,
                    onChanged: _handleMinuteEntry,
                  ),
                ),
                Expanded(
                  child: IgnorePointer(child: SizedBox.expand()),
                ),
              ],
            ),
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
      onChanged: (index) {
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
      onChanged: (index) {
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