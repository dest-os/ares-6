import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:android_intent_plus/android_intent.dart';

class ClockWidget extends StatefulWidget {
  const ClockWidget({super.key});

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  late Timer _timer;
  DateTime _now = DateTime.now();
  bool _localeReady = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null).then((_) {
      if (mounted) setState(() => _localeReady = true);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _openClock() async {
    try {
      const intent = AndroidIntent(action: 'android.intent.action.SHOW_ALARMS');
      await intent.launch();
    } catch (e) {
      try {
        const intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          category: 'android.intent.category.APP_CALENDAR',
        );
        await intent.launch();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(_now);
    final date = DateFormat('dd.MM.yyyy').format(_now);
    final day = _localeReady
        ? DateFormat('EEEE', 'tr_TR').format(_now)
        : DateFormat('EEEE').format(_now);

    // Kutuyu dolduracak büyük saat
    return GestureDetector(
      onTap: _openClock,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
          const Icon(Icons.access_time, color: Color(0xFF00BFFF), size: 22),
          const SizedBox(width: 10),
          Text(
            time,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            width: 1.5,
            height: 18,
            color: const Color(0xFF00BFFF).withOpacity(0.55),
          ),
          Text(
            date,
            style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 16),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            width: 1.5,
            height: 18,
            color: const Color(0xFF00BFFF).withOpacity(0.55),
          ),
          Text(
            day,
            style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 16),
          ),
          ],
        ),
      ),
    );
  }
}
