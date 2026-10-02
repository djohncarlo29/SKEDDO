import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'wheel_option_text.dart';

/// Retains Flutter's compact date picker in portrait and expands its wheels in
/// landscape, where the stock picker caps its column group at 320 points.
class CupertinoDatePickerWithFullWidthSelection extends StatefulWidget {
  const CupertinoDatePickerWithFullWidthSelection({
    super.key,
    required this.itemExtent,
    required this.initialDateTime,
    required this.onDateTimeChanged,
    this.minimumDate,
    this.maximumDate,
  });

  final double itemExtent;
  final DateTime initialDateTime;
  final DateTime? minimumDate;
  final DateTime? maximumDate;
  final ValueChanged<DateTime> onDateTimeChanged;

  @override
  State<CupertinoDatePickerWithFullWidthSelection> createState() =>
      _CupertinoDatePickerWithFullWidthSelectionState();
}

class _CupertinoDatePickerWithFullWidthSelectionState
    extends State<CupertinoDatePickerWithFullWidthSelection> {
  static const double _magnification = 2.35 / 2.1;
  static const double _squeeze = 1.25;
  static const double _wheelItemHorizontalInset = 12.0;
  static const int _minimumYear = 1;
  static const int _maximumYear = 9999;
  static const int _daysPerMonthPicker = 31;
  static const int _monthsPerYear = 12;

  late DateTime _selectedDate;
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedDay;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _yearController;
  List<double>? _landscapeColumnWidths;
  bool? _isLandscape;
  bool _isMonthPickerScrolling = false;
  bool _isDayPickerScrolling = false;
  bool _isYearPickerScrolling = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = _clampDate(widget.initialDateTime);
    _setSelectedComponents(_selectedDate);
    _createControllers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _landscapeColumnWidths = null;
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    if (_isLandscape != isLandscape) {
      if (_isLandscape != null) {
        _setSelectedComponents(_selectedDate);
        _isMonthPickerScrolling = false;
        _isDayPickerScrolling = false;
        _isYearPickerScrolling = false;
        _disposeControllers();
        _createControllers();
      }
      _isLandscape = isLandscape;
    }
  }

  @override
  void didUpdateWidget(
    covariant CupertinoDatePickerWithFullWidthSelection oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    final dateChanged = !_sameDate(
      oldWidget.initialDateTime,
      widget.initialDateTime,
    );
    final boundsChanged =
        oldWidget.minimumDate != widget.minimumDate ||
        oldWidget.maximumDate != widget.maximumDate;
    if (!dateChanged && !boundsChanged) return;

    final nextDate = _clampDate(widget.initialDateTime);
    final componentsChanged =
        _selectedYear != nextDate.year ||
        _selectedMonth != nextDate.month ||
        _selectedDay != nextDate.day;
    if (!_sameDate(nextDate, _selectedDate) || componentsChanged) {
      _selectedDate = nextDate;
      _setSelectedComponents(nextDate);
      _scheduleControllerSync();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _createControllers() {
    _monthController = FixedExtentScrollController(
      initialItem: _selectedMonth - 1,
    );
    _dayController = FixedExtentScrollController(
      initialItem: _selectedDay - 1,
    );
    _yearController = FixedExtentScrollController(
      initialItem: _selectedYear - _minimumYear,
    );
  }

  void _disposeControllers() {
    _monthController.dispose();
    _dayController.dispose();
    _yearController.dispose();
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _sameDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  static int _positiveModulo(int value, int divisor) =>
      ((value % divisor) + divisor) % divisor;

  void _setSelectedComponents(DateTime date) {
    _selectedYear = date.year;
    _selectedMonth = date.month;
    _selectedDay = date.day;
  }

  DateTime _clampDate(DateTime value) {
    final year = value.year.clamp(_minimumYear, _maximumYear).toInt();
    final month = value.month.clamp(1, _monthsPerYear).toInt();
    final day = value.day.clamp(1, _daysInMonth(year, month)).toInt();
    var date = DateTime(year, month, day);

    final minimumDate = widget.minimumDate;
    if (minimumDate != null && date.isBefore(_dateOnly(minimumDate))) {
      date = _dateOnly(minimumDate);
    }

    final maximumDate = widget.maximumDate;
    if (maximumDate != null && date.isAfter(_dateOnly(maximumDate))) {
      date = _dateOnly(maximumDate);
    }
    return date;
  }

  void _selectDate(DateTime requestedDate, {bool forceControllerSync = false}) {
    final nextDate = _clampDate(requestedDate);
    final wasClamped =
        forceControllerSync || !_sameDate(nextDate, requestedDate);
    final dateChanged = !_sameDate(nextDate, _selectedDate);
    final componentsChanged =
        _selectedYear != nextDate.year ||
        _selectedMonth != nextDate.month ||
        _selectedDay != nextDate.day;
    if (dateChanged || componentsChanged) {
      setState(() {
        _selectedDate = nextDate;
        _setSelectedComponents(nextDate);
      });
    }
    if (dateChanged) {
      widget.onDateTimeChanged(nextDate);
    }
    if (wasClamped) _scheduleControllerSync();
  }

  void _selectDateComponents(int year, int month, int day) {
    final nextDate = _validDateForComponents(year, month, day);
    setState(() {
      _selectedYear = year;
      _selectedMonth = month;
      _selectedDay = day;
      if (nextDate != null) _selectedDate = nextDate;
    });
    if (nextDate != null) widget.onDateTimeChanged(nextDate);
  }

  int _nearestLoopIndex(
    FixedExtentScrollController controller,
    int desiredIndex,
    int itemCount,
  ) {
    if (!controller.hasClients) return desiredIndex;
    final currentIndex = controller.selectedItem;
    final currentModulo = _positiveModulo(currentIndex, itemCount);
    final forward = _positiveModulo(desiredIndex - currentModulo, itemCount);
    final backward = forward - itemCount;
    return currentIndex +
        (forward.abs() <= backward.abs() ? forward : backward);
  }

  void _scheduleControllerSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isLandscape != true) return;
      final monthIndex = _nearestLoopIndex(
        _monthController,
        _selectedMonth - 1,
        _monthsPerYear,
      );
      final dayIndex = _nearestLoopIndex(
        _dayController,
        _selectedDay - 1,
        _daysPerMonthPicker,
      );
      final yearIndex = _selectedYear - _minimumYear;

      if (_monthController.hasClients &&
          _monthController.selectedItem != monthIndex) {
        _monthController.jumpToItem(monthIndex);
      }
      if (_dayController.hasClients &&
          _dayController.selectedItem != dayIndex) {
        _dayController.jumpToItem(dayIndex);
      }
      if (_yearController.hasClients &&
          _yearController.selectedItem != yearIndex) {
        _yearController.jumpToItem(yearIndex);
      }
    });
  }

  bool _handlePickerScrollNotification(
    _DateWheelColumn column,
    ScrollNotification notification,
  ) {
    if (notification is ScrollStartNotification) {
      _setPickerScrolling(column, true);
    } else if (notification is ScrollEndNotification) {
      _setPickerScrolling(column, false);
      _pickerDidStopScrolling();
    }
    return false;
  }

  void _setPickerScrolling(_DateWheelColumn column, bool isScrolling) {
    switch (column) {
      case _DateWheelColumn.month:
        _isMonthPickerScrolling = isScrolling;
      case _DateWheelColumn.day:
        _isDayPickerScrolling = isScrolling;
      case _DateWheelColumn.year:
        _isYearPickerScrolling = isScrolling;
    }
  }

  bool get _isAnyPickerScrolling =>
      _isMonthPickerScrolling ||
      _isDayPickerScrolling ||
      _isYearPickerScrolling;

  void _pickerDidStopScrolling() {
    setState(() {});
    if (_isAnyPickerScrolling) return;

    final selectedDate = DateTime(_selectedYear, _selectedMonth, _selectedDay);
    final dayAfterSelectedDate = DateTime(
      _selectedYear,
      _selectedMonth,
      _selectedDay + 1,
    );
    final minimumDate =
        widget.minimumDate == null ? null : _dateOnly(widget.minimumDate!);
    final maximumDate =
        widget.maximumDate == null ? null : _dateOnly(widget.maximumDate!);
    final minimumCheck = minimumDate?.isBefore(dayAfterSelectedDate) ?? true;
    final maximumCheck = maximumDate?.isBefore(selectedDate) ?? false;

    if (!minimumCheck || maximumCheck) {
      final targetDate = minimumCheck ? maximumDate! : minimumDate!;
      _scrollToDate(targetDate);
      return;
    }

    if (selectedDate.day != _selectedDay) {
      _scrollToDate(
        DateTime(
          _selectedYear,
          _selectedMonth,
          _daysInMonth(_selectedYear, _selectedMonth),
        ),
      );
    }
  }

  void _scrollToDate(DateTime targetDate) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selectedYear != targetDate.year) {
        _animateControllerToItem(
          _yearController,
          targetDate.year - _minimumYear,
        );
      }
      if (_selectedMonth != targetDate.month) {
        _animateControllerToItem(
          _monthController,
          _nearestLoopIndex(
            _monthController,
            targetDate.month - 1,
            _monthsPerYear,
          ),
        );
      }
      if (_selectedDay != targetDate.day) {
        _animateControllerToItem(
          _dayController,
          _nearestLoopIndex(
            _dayController,
            targetDate.day - 1,
            _daysPerMonthPicker,
          ),
        );
      }
    });
  }

  void _animateControllerToItem(
    FixedExtentScrollController controller,
    int targetItem,
  ) {
    if (!controller.hasClients || controller.selectedItem == targetItem) return;
    controller.animateToItem(
      targetItem,
      curve: Curves.easeInOut,
      duration: const Duration(milliseconds: 200),
    );
  }

  TextStyle _pickerTextStyle({required bool isValid}) {
    final style = CupertinoTheme.of(context).textTheme.dateTimePickerTextStyle;
    final color = isValid
        ? CupertinoDynamicColor.maybeResolve(style.color, context)
        : CupertinoDynamicColor.resolve(CupertinoColors.inactiveGray, context);
    return style.copyWith(color: color);
  }

  Widget _wheelItem(
    String label, {
    required int columnIndex,
    required bool isValid,
  }) {
    // Match the stock portrait picker: the first logical date column is
    // leading-aligned, and the remaining columns are trailing-aligned.
    final isFirstColumn = columnIndex == 0;
    final alignment = isFirstColumn
        ? AlignmentDirectional.centerStart
        : AlignmentDirectional.centerEnd;
    return Padding(
      padding: isFirstColumn
          ? const EdgeInsetsDirectional.only(start: _wheelItemHorizontalInset)
          : const EdgeInsetsDirectional.only(end: _wheelItemHorizontalInset),
      child: WheelOptionText(
        text: label,
        style: _pickerTextStyle(isValid: isValid),
        magnification: _magnification,
        alignment: alignment,
      ),
    );
  }

  double _offAxisFraction(int columnIndex) {
    final direction = Directionality.of(context) == TextDirection.rtl
        ? -1.0
        : 1.0;
    return (columnIndex - 1) * 0.3 * direction;
  }

  bool _isDateWithinBounds(DateTime date) {
    final minimumDate = widget.minimumDate;
    if (minimumDate != null && date.isBefore(_dateOnly(minimumDate))) {
      return false;
    }
    final maximumDate = widget.maximumDate;
    if (maximumDate != null && date.isAfter(_dateOnly(maximumDate))) {
      return false;
    }
    return true;
  }

  bool _isMonthValid(int month) {
    final minimumDate = widget.minimumDate;
    if (minimumDate != null) {
      if (_selectedYear < minimumDate.year ||
          (_selectedYear == minimumDate.year &&
              month < minimumDate.month)) {
        return false;
      }
    }
    final maximumDate = widget.maximumDate;
    if (maximumDate != null) {
      if (_selectedYear > maximumDate.year ||
          (_selectedYear == maximumDate.year &&
              month > maximumDate.month)) {
        return false;
      }
    }
    return true;
  }

  bool _isDayValid(int day) {
    if (day > _daysInMonth(_selectedYear, _selectedMonth)) {
      return false;
    }
    return _isDateWithinBounds(
      DateTime(_selectedYear, _selectedMonth, day),
    );
  }

  DateTime? _validDateForComponents(int year, int month, int day) {
    if (day > _daysInMonth(year, month)) return null;
    final candidate = DateTime(year, month, day);
    return _isDateWithinBounds(candidate) ? candidate : null;
  }

  double _columnWidth(
    _DateWheelColumn column,
    CupertinoLocalizations localizations,
  ) {
    final labels = switch (column) {
      _DateWheelColumn.month => List<String>.generate(
        _monthsPerYear,
        (index) => localizations.datePickerMonth(index + 1),
      ),
      _DateWheelColumn.day => List<String>.generate(
        _daysPerMonthPicker,
        (index) => localizations.datePickerDayOfMonth(index + 1),
      ),
      _DateWheelColumn.year => [
        localizations.datePickerYear(_minimumYear),
        localizations.datePickerYear(_maximumYear),
      ],
    };
    final style = _pickerTextStyle(isValid: true);
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    var widestLabel = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      widestLabel = math.max(widestLabel, painter.width);
      painter.dispose();
    }
    return widestLabel + _wheelItemHorizontalInset * 2;
  }

  Widget _buildMonthPicker(
    int columnIndex,
    CupertinoLocalizations localizations,
  ) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) =>
          _handlePickerScrollNotification(_DateWheelColumn.month, notification),
      child: CupertinoPicker(
        key: const ValueKey('wide-date-month-column'),
        scrollController: _monthController,
        itemExtent: widget.itemExtent,
        useMagnifier: true,
        magnification: _magnification,
        squeeze: _squeeze,
        offAxisFraction: _offAxisFraction(columnIndex),
        backgroundColor: CupertinoColors.transparent,
        selectionOverlay: const SizedBox.shrink(),
        looping: true,
        onSelectedItemChanged: (index) {
          final month = _positiveModulo(index, _monthsPerYear) + 1;
          _selectDateComponents(_selectedYear, month, _selectedDay);
        },
        children: List<Widget>.generate(_monthsPerYear, (index) {
          final month = index + 1;
          return _wheelItem(
            localizations.datePickerMonth(month),
            columnIndex: columnIndex,
            isValid: _isMonthValid(month),
          );
        }),
      ),
    );
  }

  Widget _buildDayPicker(
    int columnIndex,
    CupertinoLocalizations localizations,
  ) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) =>
          _handlePickerScrollNotification(_DateWheelColumn.day, notification),
      child: CupertinoPicker(
        key: const ValueKey('wide-date-day-column'),
        scrollController: _dayController,
        itemExtent: widget.itemExtent,
        useMagnifier: true,
        magnification: _magnification,
        squeeze: _squeeze,
        offAxisFraction: _offAxisFraction(columnIndex),
        backgroundColor: CupertinoColors.transparent,
        selectionOverlay: const SizedBox.shrink(),
        looping: true,
        onSelectedItemChanged: (index) {
          final day = _positiveModulo(index, _daysPerMonthPicker) + 1;
          _selectDateComponents(_selectedYear, _selectedMonth, day);
        },
        children: List<Widget>.generate(_daysPerMonthPicker, (index) {
          final day = index + 1;
          return _wheelItem(
            localizations.datePickerDayOfMonth(day),
            columnIndex: columnIndex,
            isValid: _isDayValid(day),
          );
        }),
      ),
    );
  }

  Widget _buildYearPicker(
    int columnIndex,
    CupertinoLocalizations localizations,
  ) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) =>
          _handlePickerScrollNotification(_DateWheelColumn.year, notification),
      child: CupertinoPicker.builder(
        key: const ValueKey('wide-date-year-column'),
        scrollController: _yearController,
        itemExtent: widget.itemExtent,
        useMagnifier: true,
        magnification: _magnification,
        squeeze: _squeeze,
        offAxisFraction: _offAxisFraction(columnIndex),
        backgroundColor: CupertinoColors.transparent,
        selectionOverlay: const SizedBox.shrink(),
        childCount: _maximumYear - _minimumYear + 1,
        onSelectedItemChanged: (index) {
          final year = index + _minimumYear;
          _selectDateComponents(year, _selectedMonth, _selectedDay);
        },
        itemBuilder: (context, index) {
          final year = index + _minimumYear;
          final minimumDate = widget.minimumDate;
          final maximumDate = widget.maximumDate;
          final isValid =
              (minimumDate == null || minimumDate.year <= year) &&
              (maximumDate == null || maximumDate.year >= year);
          return _wheelItem(
            localizations.datePickerYear(year),
            columnIndex: columnIndex,
            isValid: isValid,
          );
        },
      ),
    );
  }

  Widget _buildLandscapePickers() {
    final localizations = CupertinoLocalizations.of(context);
    final order = localizations.datePickerDateOrder;
    final columns = switch (order) {
      DatePickerDateOrder.mdy => const [
        _DateWheelColumn.month,
        _DateWheelColumn.day,
        _DateWheelColumn.year,
      ],
      DatePickerDateOrder.dmy => const [
        _DateWheelColumn.day,
        _DateWheelColumn.month,
        _DateWheelColumn.year,
      ],
      DatePickerDateOrder.ymd => const [
        _DateWheelColumn.year,
        _DateWheelColumn.month,
        _DateWheelColumn.day,
      ],
      DatePickerDateOrder.ydm => const [
        _DateWheelColumn.year,
        _DateWheelColumn.day,
        _DateWheelColumn.month,
      ],
    };

    final columnWidths = _landscapeColumnWidths ??= columns
        .map((column) => _columnWidth(column, localizations))
        .toList();
    final intrinsicGroupWidth = columnWidths.fold<double>(
      0,
      (total, width) => total + width,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final groupWidth = math.min(intrinsicGroupWidth, constraints.maxWidth);
        final hasRoomForNaturalWidths =
            intrinsicGroupWidth <= constraints.maxWidth;
        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            key: const ValueKey('wide-date-picker-column-group'),
            width: groupWidth,
            child: Row(
              textDirection: Directionality.of(context),
              children: List<Widget>.generate(columns.length, (index) {
                final wheel = switch (columns[index]) {
                  _DateWheelColumn.month => _buildMonthPicker(
                    index,
                    localizations,
                  ),
                  _DateWheelColumn.day => _buildDayPicker(index, localizations),
                  _DateWheelColumn.year => _buildYearPicker(
                    index,
                    localizations,
                  ),
                };
                return hasRoomForNaturalWidths
                    ? SizedBox(width: columnWidths[index], child: wheel)
                    : Expanded(child: wheel);
              }),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;

    return SizedBox(
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isLandscape)
            _buildLandscapePickers()
          else
            CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              itemExtent: widget.itemExtent,
              initialDateTime: _selectedDate,
              minimumDate: widget.minimumDate,
              maximumDate: widget.maximumDate,
              selectionOverlayBuilder: _hideColumnSelection,
              onDateTimeChanged: _selectDate,
            ),
          IgnorePointer(
            child: Center(
              child: SizedBox(
                width: double.infinity,
                height: widget.itemExtent,
                child: const CupertinoPickerDefaultSelectionOverlay(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget? _hideColumnSelection(
    BuildContext context, {
    required int columnCount,
    required int selectedIndex,
  }) => null;
}

enum _DateWheelColumn { month, day, year }
