import 'dart:async';
import 'package:flutter/material.dart';
import '../services/weather_service.dart';

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  WeatherData? _weather;
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadWeather();
    // Konum değişebileceği ve hava durumu zamanla değişeceği için
    // periyodik olarak tazele.
    _refreshTimer = Timer.periodic(const Duration(minutes: 15), (_) => _loadWeather());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    final data = await WeatherService().getWeather();
    if (mounted) {
      setState(() {
        _weather = data;
        _loading = false;
      });
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00BFFF), strokeWidth: 2),
      );
    }

    if (_weather == null) {
      return Center(
        child: GestureDetector(
          onTap: () {
            setState(() => _loading = true);
            _loadWeather();
          },
          child: const Text(
            'Hava alınamadı\n(tekrar denemek için dokun)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
      );
    }

    // Kutu yatay/geniş bir dikdörtgen olduğu için içerik de buna uygun
    // yatay (iki sütunlu) bir düzende kuruldu: böylece FittedBox içeriği
    // kutunun hem genişliğini hem yüksekliğini çok daha iyi dolduracak
    // şekilde büyütüyor, üstelik her taraftan eşit boşlukla ortalanıyor.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: FittedBox(
          fit: BoxFit.contain,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // SOL: konum + sıcaklık + açıklama
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF00BFFF), size: 16),
                      const SizedBox(width: 5),
                      Text(
                        _weather!.city,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wb_sunny_outlined, color: Color(0xFFFFD700), size: 38),
                      const SizedBox(width: 8),
                      Text(
                        '${_weather!.temp.round()}°C',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _capitalize(_weather!.description),
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(width: 30),
              Container(width: 1.5, height: 120, color: Colors.white.withOpacity(0.2)),
              const SizedBox(width: 30),
              // SAĞ: detaylar
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _compactInfoRow(Icons.thermostat, 'Hissedilen', '${_weather!.feelsLike.round()}°C'),
                  const SizedBox(height: 8),
                  _compactInfoRow(Icons.air, 'Rüzgar', '${_weather!.windSpeed.round()} km/sa'),
                  const SizedBox(height: 8),
                  _compactInfoRow(Icons.water_drop, 'Nem', '%${_weather!.humidity}'),
                  const SizedBox(height: 12),
                  Text(
                    'Güncellendi ${_weather!.updatedAt.hour.toString().padLeft(2, '0')}:${_weather!.updatedAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12),
                  ),
                  if (!_weather!.usedRealLocation) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Konum izni verilmedi',
                      style: TextStyle(color: Colors.orangeAccent.withOpacity(0.85), fontSize: 12),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactInfoRow(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF00BFFF).withOpacity(0.85), size: 15),
        const SizedBox(width: 5),
        Text(
          '$label ',
          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
