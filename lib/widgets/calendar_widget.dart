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
    final firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday;
    const weekDays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cts', 'Paz'];

    final List<Widget> dayWidgets = [];

    for (int i = 1; i < firstWeekday; i++) {
      dayWidgets.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final isToday = day == _today.day &&
          _focusedMonth.month == _today.month &&
          _focusedMonth.year == _today.year;

      dayWidgets.add(
        Center(
          child: Container(
            width: 27,
            height: 27,
            alignment: Alignment.center,
            decoration: isToday
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00BFFF).withOpacity(0.28),
                    border: Border.all(color: const Color(0xFF00BFFF), width: 1.4),
                  )
                : null,
            child: Text(
              '$day',
              style: TextStyle(
                color: isToday ? const Color(0xFF00BFFF) : Colors.white.withOpacity(0.9),
                fontSize: 13,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    // Kutunun boyutu ne olursa olsun içerik orantılı olarak küçültülüp
    // her taraftan eşit boşluk kalacak şekilde tam ortasına yerleştirilir.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _prevMonth,
                      child: const Icon(Icons.chevron_left, color: Color(0xFF00BFFF), size: 20),
                    ),
                    Text(
                      monthName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: _nextMonth,
                      child: const Icon(Icons.chevron_right, color: Color(0xFF00BFFF), size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: weekDays
                      .map(
                        (d) => Expanded(
                          child: Text(
                            d,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFF00BFFF).withOpacity(0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 3),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.55,
                  padding: EdgeInsets.zero,
                  children: dayWidgets,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
