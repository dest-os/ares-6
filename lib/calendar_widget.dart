import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarWidget extends StatefulWidget {
  const CalendarWidget({super.key});

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  late DateTime _focusedMonth;
  final DateTime _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(_today.year, _today.month);
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy', 'tr_TR').format(_focusedMonth);
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday; // 1=Pzt

    final weekDays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cts', 'Paz'];

    List<Widget> dayWidgets = [];

    // Boş günler
    for (int i = 1; i < firstWeekday; i++) {
      dayWidgets.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final isToday = day == _today.day &&
          _focusedMonth.month == _today.month &&
          _focusedMonth.year == _today.year;

      dayWidgets.add(
        Container(
          alignment: Alignment.center,
          decoration: isToday
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00BFFF).withOpacity(0.3),
                  border: Border.all(color: const Color(0xFF00BFFF), width: 1.5),
                )
              : null,
          child: Text(
            '$day',
            style: TextStyle(
              color: isToday ? const Color(0xFF00BFFF) : Colors.white.withOpacity(0.85),
              fontSize: 13,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    // NeonContainer KALDIRILDI - sadece içerik
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ay başlığı
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: _prevMonth,
              child: const Icon(Icons.chevron_left, color: Color(0xFF00BFFF), size: 22),
            ),
            Text(
              monthName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              onTap: _nextMonth,
              child: const Icon(Icons.chevron_right, color: Color(0xFF00BFFF), size: 22),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Gün isimleri
        Row(
          children: weekDays
              .map((d) => Expanded(
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF00BFFF).withOpacity(0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),
        // Günler
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.15,
          children: dayWidgets,
        ),
      ],
    );
  }
}
