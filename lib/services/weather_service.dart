import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherData {
  final double temp;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final String description;
  final String city;
  final DateTime updatedAt;
  final bool usedRealLocation;

  WeatherData({
    required this.temp,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.description,
    required this.city,
    required this.updatedAt,
    required this.usedRealLocation,
  });
}

class WeatherService {
  // İstanbul konumu: sadece cihaz konumu alınamazsa (izin verilmedi /
  // GPS kapalı) yedek olarak kullanılır.
  static const double _fallbackLat = 41.0082;
  static const double _fallbackLon = 28.9784;

  /// Cihazın gerçek GPS konumunu Android sisteminden ister.
  /// İzin verilmemişse veya konum servisleri kapalıysa null döner.
  Future<Position?> _getDeviceLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
    } catch (e) {
      print('Konum alınamadı: $e');
      return null;
    }
  }

  /// Koordinatı şehir/ilçe adına çevirir. API anahtarı gerektirmez.
  Future<String> _reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client'
        '?latitude=$lat&longitude=$lon&localityLanguage=tr',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final city = data['city'] ??
            data['locality'] ??
            data['principalSubdivision'] ??
            data['countryName'];
        if (city != null && city.toString().trim().isNotEmpty) {
          return city.toString();
        }
      }
    } catch (e) {
      print('Konum adı alınamadı: $e');
    }
    return 'Konumum';
  }

  /// WMO hava kodunu Türkçe açıklamaya çevirir.
  String _describeWeatherCode(int code) {
    if (code == 0) return 'Açık';
    if (code == 1) return 'Az Bulutlu';
    if (code == 2) return 'Parçalı Bulutlu';
    if (code == 3) return 'Kapalı';
    if (code == 45 || code == 48) return 'Sisli';
    if (code >= 51 && code <= 57) return 'Çiseleme';
    if (code >= 61 && code <= 67) return 'Yağmurlu';
    if (code >= 71 && code <= 77) return 'Karlı';
    if (code >= 80 && code <= 82) return 'Sağanak Yağışlı';
    if (code == 85 || code == 86) return 'Kar Sağanağı';
    if (code >= 95) return 'Fırtınalı';
    return 'Değişken';
  }

  Future<WeatherData?> getWeather() async {
    final position = await _getDeviceLocation();
    final bool usedRealLocation = position != null;

    final double lat = position?.latitude ?? _fallbackLat;
    final double lon = position?.longitude ?? _fallbackLon;

    try {
      final weatherUrl = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,wind_speed_10m,weather_code'
        '&timezone=auto',
      );

      final results = await Future.wait([
        http.get(weatherUrl),
        _reverseGeocode(lat, lon),
      ]);

      final weatherResponse = results[0] as http.Response;
      final cityName = results[1] as String;

      if (weatherResponse.statusCode == 200) {
        final data = jsonDecode(weatherResponse.body);
        final current = data['current'];
        final code = (current['weather_code'] as num).toInt();

        return WeatherData(
          temp: (current['temperature_2m'] as num).toDouble(),
          feelsLike: (current['apparent_temperature'] as num).toDouble(),
          humidity: (current['relative_humidity_2m'] as num).toInt(),
          windSpeed: (current['wind_speed_10m'] as num).toDouble(),
          description: _describeWeatherCode(code),
          city: cityName,
          updatedAt: DateTime.now(),
          usedRealLocation: usedRealLocation,
        );
      }
    } catch (e) {
      print('Hava durumu hatası: $e');
    }
    return null;
  }
}
