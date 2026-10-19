import 'dart:async';
import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:battery_plus/battery_plus.dart';

class StatusBarWidget extends StatefulWidget {
  const StatusBarWidget({super.key});

  @override
  State<StatusBarWidget> createState() => _StatusBarWidgetState();
}

class _StatusBarWidgetState extends State<StatusBarWidget> {
  final Battery _battery = Battery();
  int _batteryPercent = 100;
  StreamSubscription<BatteryState>? _batteryStateSub;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _readBattery();
    _batteryStateSub =
        _battery.onBatteryStateChanged.listen((_) => _readBattery());
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _readBattery());
  }

  Future<void> _readBattery() async {
    try {
      final level = await _battery.batteryLevel;
      if (mounted) setState(() => _batteryPercent = level);
    } catch (_) {}
  }

  @override
  void dispose() {
    _batteryStateSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _openSettings(String action) async {
    try {
      await AndroidIntent(action: action).launch();
    } catch (_) {}
  }

  Widget _batteryIcon(int percent, double h) {
    final p = percent.clamp(0, 100);
    final fill = p <= 20
        ? Colors.redAccent
        : p <= 40
            ? Colors.amberAccent
            : Colors.white;
    final bodyW = h * 1.8;
    final bodyH = h * 0.85;
    final capW = h * 0.18;
    final capH = h * 0.45;

    return SizedBox(
      width: bodyW + capW + 2,
      height: bodyH,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: bodyW,
            height: bodyH,
            padding: EdgeInsets.all(h * 0.08),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: h * 0.08),
              borderRadius: BorderRadius.circular(h * 0.15),
            ),
            child: LayoutBuilder(
              builder: (context, c) => Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: c.maxWidth * (p / 100),
                  height: c.maxHeight,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: h * 0.06),
          Container(
            width: capW,
            height: capH,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight.clamp(20.0, 80.0);
        final iconSize = h * 0.55;
        final fontSize = h * 0.42;
        final gap = h * 0.35;

        return FittedBox(
          fit: BoxFit.contain,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () =>
                    _openSettings('android.settings.WIFI_SETTINGS'),
                child: Icon(Icons.wifi, color: Colors.white, size: iconSize),
              ),
              SizedBox(width: gap),
              GestureDetector(
                onTap: () =>
                    _openSettings('android.settings.BLUETOOTH_SETTINGS'),
                child:
                    Icon(Icons.bluetooth, color: Colors.white, size: iconSize),
              ),
              SizedBox(width: gap),
              GestureDetector(
                onTap: () =>
                    _openSettings('android.settings.WIRELESS_SETTINGS'),
                child: Icon(Icons.signal_cellular_alt,
                    color: Colors.white, size: iconSize),
              ),
              SizedBox(width: gap),
              GestureDetector(
                onTap: () =>
                    _openSettings('android.settings.BATTERY_SAVER_SETTINGS'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _batteryIcon(_batteryPercent, iconSize),
                    SizedBox(width: gap * 0.4),
                    Text(
                      '$_batteryPercent%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
