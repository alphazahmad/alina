import 'dart:convert';
import 'dart:io';
import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CityConfig {
  final String name;
  final double latitude;
  final double longitude;
  final CalculationMethod method;

  const CityConfig({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.method,
  });
}

class PrayerTimeService {
  static final PrayerTimeService _instance = PrayerTimeService._internal();
  factory PrayerTimeService() => _instance;
  PrayerTimeService._internal();

  static const List<CityConfig> cities = [
    CityConfig(name: 'Nagpur', latitude: 21.1458, longitude: 79.0882, method: CalculationMethod.karachi),
    CityConfig(name: 'Karachi', latitude: 24.8607, longitude: 67.0011, method: CalculationMethod.karachi),
    CityConfig(name: 'Islamabad', latitude: 33.6844, longitude: 73.0479, method: CalculationMethod.karachi),
    CityConfig(name: 'Lahore', latitude: 31.5204, longitude: 74.3587, method: CalculationMethod.karachi),
    CityConfig(name: 'Dhaka', latitude: 23.8103, longitude: 90.4125, method: CalculationMethod.karachi),
    CityConfig(name: 'Dubai', latitude: 25.2048, longitude: 55.2708, method: CalculationMethod.dubai),
    CityConfig(name: 'London', latitude: 51.5074, longitude: -0.1278, method: CalculationMethod.muslim_world_league),
    CityConfig(name: 'New York', latitude: 40.7128, longitude: -74.0060, method: CalculationMethod.north_america),
  ];

  CityConfig _currentCity = cities[0]; // Default to Nagpur

  CityConfig get currentCity => _currentCity;

  void setCity(String cityName) {
    _currentCity = cities[0]; // Locked to Nagpur
  }

  /// Helper to get local cache file for a specific date and city.
  Future<File> _getCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/alina_prayer_times_cache.json');
  }

  /// Calculates prayer times for a specific date (using API if online, offline adhan as fallback).
  Future<Map<String, DateTime>> getPrayerTimesForDate(DateTime date) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final cacheKey = '${_currentCity.name}_$dateStr';

    // 1. Try reading from local JSON Cache
    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        final Map<String, dynamic> cache = jsonDecode(await file.readAsString());
        if (cache.containsKey(cacheKey)) {
          final Map<String, dynamic> timings = cache[cacheKey];
          return {
            'fajr': DateTime.parse(timings['fajr']),
            'dhuhr': DateTime.parse(timings['dhuhr']),
            'asr': DateTime.parse(timings['asr']),
            'maghrib': DateTime.parse(timings['maghrib']),
            'isha': DateTime.parse(timings['isha']),
          };
        }
      }
    } catch (e) {
      debugPrint('Error reading prayer times cache: $e');
    }

    // 2. Try fetching from Aladhan API if online
    Map<String, DateTime>? apiTimes;
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    try {
      // Determine method: Nagpur/Karachi calculation uses method=2 (Karachi)
      int apiMethod = 2; // default Karachi
      if (_currentCity.method == CalculationMethod.dubai) {
        apiMethod = 8; // Gulf
      }
      if (_currentCity.method == CalculationMethod.muslim_world_league) {
        apiMethod = 3;
      }
      if (_currentCity.method == CalculationMethod.north_america) {
        apiMethod = 2; // fallback
      }

      // Country parameter
      String country = 'Pakistan';
      if (_currentCity.name == 'Nagpur') {
        country = 'India';
      } else if (_currentCity.name == 'Dhaka') {
        country = 'Bangladesh';
      } else if (_currentCity.name == 'Dubai') {
        country = 'UAE';
      } else if (_currentCity.name == 'London') {
        country = 'UK';
      } else if (_currentCity.name == 'New York') {
        country = 'US';
      }

      final url = 'https://api.aladhan.com/v1/timingsByCity/$dateStr'
          '?city=${Uri.encodeComponent(_currentCity.name)}'
          '&country=${Uri.encodeComponent(country)}'
          '&method=$apiMethod'
          '&school=1'; // 1 = Hanafi for Nagpur/Sunni majority

      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body);
        final timings = json['data']['timings'];

        final parsedTimes = {
          'fajr': _parseApiTime(timings['Fajr'], date),
          'dhuhr': _parseApiTime(timings['Dhuhr'], date),
          'asr': _parseApiTime(timings['Asr'], date),
          'maghrib': _parseApiTime(timings['Maghrib'], date),
          'isha': _parseApiTime(timings['Isha'], date),
        };

        // Cache the timings locally
        await _saveToCache(cacheKey, parsedTimes);
        apiTimes = parsedTimes;
      }
    } catch (e) {
      debugPrint('Error fetching prayer times from Aladhan API: $e');
    } finally {
      client.close();
    }

    if (apiTimes != null) {
      return apiTimes;
    }

    // 3. Fallback to offline Adhan Library
    final coordinates = Coordinates(_currentCity.latitude, _currentCity.longitude);
    final dateComponents = DateComponents.from(date);
    final params = _currentCity.method.getParameters();
    params.madhab = Madhab.hanafi; // Hanafi Sunni school

    final prayerTimes = PrayerTimes(coordinates, dateComponents, params);
    final fallbackTimes = {
      'fajr': prayerTimes.fajr.toLocal(),
      'dhuhr': prayerTimes.dhuhr.toLocal(),
      'asr': prayerTimes.asr.toLocal(),
      'maghrib': prayerTimes.maghrib.toLocal(),
      'isha': prayerTimes.isha.toLocal(),
    };

    // Cache the fallback times as well
    await _saveToCache(cacheKey, fallbackTimes);
    return fallbackTimes;
  }

  DateTime _parseApiTime(String timeStr, DateTime date) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1].split(' ')[0]);
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  Future<void> _saveToCache(String cacheKey, Map<String, DateTime> timings) async {
    try {
      final file = await _getCacheFile();
      Map<String, dynamic> cache = {};
      if (await file.exists()) {
        try {
          cache = jsonDecode(await file.readAsString());
        } catch (_) {}
      }

      cache[cacheKey] = {
        'fajr': timings['fajr']!.toIso8601String(),
        'dhuhr': timings['dhuhr']!.toIso8601String(),
        'asr': timings['asr']!.toIso8601String(),
        'maghrib': timings['maghrib']!.toIso8601String(),
        'isha': timings['isha']!.toIso8601String(),
      };

      await file.writeAsString(jsonEncode(cache));
    } catch (e) {
      debugPrint('Error saving prayer times to cache: $e');
    }
  }

  /// Helper to check if a prayer time has passed for today
  Future<bool> hasPrayerPassed(String prayerKey, DateTime date) async {
    final now = DateTime.now();

    if (date.isBefore(DateTime(now.year, now.month, now.day))) {
      return true;
    }
    if (date.isAfter(DateTime(now.year, now.month, now.day))) {
      return false;
    }

    final times = await getPrayerTimesForDate(now);
    final prayerTime = times[prayerKey.toLowerCase()];
    if (prayerTime != null) {
      return now.isAfter(prayerTime);
    }
    return false;
  }
}
