import 'package:flutter/material.dart';

class CycleUtils {
  /// Resolves the billing cycle range for a given reference date and configured start day (1..31).
  /// [offsetMonths]: 0 for current cycle, -1 for previous cycle, etc.
  static DateTimeRange getBillingCycleRange(DateTime referenceDate, int startDay, [int offsetMonths = 0]) {
    DateTime ref = referenceDate;
    if (offsetMonths != 0) {
      ref = DateTime(ref.year, ref.month + offsetMonths, ref.day.clamp(1, 28));
    }

    if (startDay <= 1) {
      final start = DateTime(ref.year, ref.month, 1);
      final end = DateTime(ref.year, ref.month + 1, 1);
      return DateTimeRange(start: start, end: end);
    }

    int clampedDay(int year, int month, int targetDay) {
      final daysInMonth = DateTime(year, month + 1, 0).day;
      return targetDay.clamp(1, daysInMonth);
    }

    DateTime cycleStart;
    DateTime cycleEnd;

    final currentMonthStart = clampedDay(ref.year, ref.month, startDay);

    if (ref.day >= currentMonthStart) {
      cycleStart = DateTime(ref.year, ref.month, currentMonthStart);

      final nextYear = ref.month == 12 ? ref.year + 1 : ref.year;
      final nextMonth = ref.month == 12 ? 1 : ref.month + 1;
      final nextMonthEnd = clampedDay(nextYear, nextMonth, startDay);
      cycleEnd = DateTime(nextYear, nextMonth, nextMonthEnd);
    } else {
      final prevYear = ref.month == 1 ? ref.year - 1 : ref.year;
      final prevMonth = ref.month == 1 ? 12 : ref.month - 1;
      final prevMonthStart = clampedDay(prevYear, prevMonth, startDay);
      cycleStart = DateTime(prevYear, prevMonth, prevMonthStart);

      cycleEnd = DateTime(ref.year, ref.month, currentMonthStart);
    }

    return DateTimeRange(start: cycleStart, end: cycleEnd);
  }

  /// Returns true if [date] falls within [range] (inclusive of start, exclusive of end)
  static bool isInRange(DateTime date, DateTimeRange range) {
    return !date.isBefore(range.start) && date.isBefore(range.end);
  }
}
