import 'package:flutter/material.dart';
import '../services/ares_service.dart';

/// ARES aktifken (dinliyor / işliyor / konuşuyor) ekranın ortasındaki
/// göz/hexagon grafiğinin üzerinde, ortadan dışa doğru genişleyen
/// nabız gibi halkalar gösterir. Pasifken hiçbir şey çizmez, arka
/// plandaki statik göz görseline dokunmaz.
///
/// Durum değiştikçe halkaların rengi ve hızı değişir:
/// - dinliyor: sakin, mavi, orta hız (ARES'in "kulak kabarttığını" hisssettirir)
/// - isliyorum: yavaş, soluk (düşünüyor hissi)
/// - konusuyor: hızlı, parlak camgöbeği (konuşurken "canlı" hissi)
class AresEyePulse extends StatefulWidget {
  final AresDurum durum;
  final double boyut;

  const AresEyePulse({super.key, required this.durum, required this.boyut});

  @override
  State<AresEyePulse> createState() => _AresEyePulseState();
}

class _AresEyePulseState extends State<AresEyePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _hiz(widget.durum),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant AresEyePulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.durum != widget.durum) {
      _controller.duration = _hiz(widget.durum);
      if (widget.durum != AresDurum.pasif && !_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  Duration _hiz(AresDurum durum) {
    switch (durum) {
      case AresDurum.konusuyor:
        return const Duration(milliseconds: 750);
      case AresDurum.dinliyor:
        return const Duration(milliseconds: 1500);
      case AresDurum.isliyorum:
        return const Duration(milliseconds: 1100);
      case AresDurum.pasif:
        return const Duration(seconds: 2);
    }
  }

  Color _renk(AresDurum durum) {
    switch (durum) {
      case AresDurum.konusuyor:
        return const Color(0xFF4DFFFF); // parlak camgöbeği
      case AresDurum.dinliyor:
        return const Color(0xFF00BFFF); // sakin mavi
      case AresDurum.isliyorum:
        return const Color(0xFF6FA8DC); // soluk mavi
      case AresDurum.pasif:
        return Colors.transparent;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.durum == AresDurum.pasif) return const SizedBox.shrink();

    final renk = _renk(widget.durum);

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return SizedBox(
            width: widget.boyut,
            height: widget.boyut,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _halka(_controller.value, renk),
                _halka((_controller.value + 0.34) % 1.0, renk),
                _halka((_controller.value + 0.67) % 1.0, renk),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _halka(double t, Color renk) {
    // t: 0 -> 1 arası ilerledikçe halka büyür ve solar (nabız/sonar efekti)
    final olcek = 0.35 + t * 0.85;
    final opaklik = (1 - t) * 0.6;
    return Opacity(
      opacity: opaklik.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: olcek,
        child: Container(
          width: widget.boyut,
          height: widget.boyut,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: renk, width: 3),
            boxShadow: [
              BoxShadow(color: renk.withOpacity(0.5), blurRadius: 18, spreadRadius: 2),
            ],
          ),
        ),
      ),
    );
  }
}
