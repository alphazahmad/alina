import 'package:adhan/adhan.dart';

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
    CityConfig(name: 'Karachi', latitude: 24.8607, longitude: 67.0011, method: CalculationMethod.karachi),
    CityConfig(name: 'Islamabad', latitude: 33.6844, longitude: 73.0479, method: CalculationMethod.karachi),
    CityConfig(name: 'Lahore', latitude: 31.5204, longitude: 74.3587, method: CalculationMethod.karachi),
    CityConfig(name: 'Dhaka', latitude: 23.8103, longitude: 90.4125, method: CalculationMethod.karachi),
    CityConfig(name: 'Dubai', latitude: 25.2048, longitude: 55.2708, method: CalculationMethod.dubai),
    CityConfig(name: 'London', latitude: 51.5074, longitude: -0.1278, method: CalculationMethod.muslim_world_league),
    CityConfig(name: 'New York', latitude: 40.7128, longitude: -74.0060, method: CalculationMethod.north_america),
  ];

  CityConfig _currentCity = cities[1]; // Default to Islamabad

  CityConfig get currentCity => _currentCity;

  void setCity(String cityName) {
    _currentCity = cities.firstWhere(
      (c) => c.name.toLowerCase() == cityName.toLowerCase(),
      orElse: () => cities[1],
    );
  }

  /// Calculates prayer times for a specific date and the currently configured city.
  Map<String, DateTime> getPrayerTimesForDate(DateTime date) {
    final coordinates = Coordinates(_currentCity.latitude, _currentCity.longitude);
    final dateComponents = DateComponents.from(date);
    final params = _currentCity.method.getParameters();
    
    // Set Madhab to Hanafi since it's most common in Pakistan (affects Asr calculation)
    params.madhab = Madhab.hanafi;

    final prayerTimes = PrayerTimes(coordinates, dateComponents, params);

    return {
      'fajr': prayerTimes.fajr.toLocal(),
      'dhuhr': prayerTimes.dhuhr.toLocal(),
      'asr': prayerTimes.asr.toLocal(),
      'maghrib': prayerTimes.maghrib.toLocal(),
      'isha': prayerTimes.isha.toLocal(),
    };
  }

  /// Helper to check if a prayer time has passed for today
  bool hasPrayerPassed(String prayerKey, DateTime date) {
    final now = DateTime.now();

    // If it's a past date, the time has definitely passed
    if (date.isBefore(DateTime(now.year, now.month, now.day))) {
      return true;
    }
    // If it's a future date, the time has definitely NOT passed
    if (date.isAfter(DateTime(now.year, now.month, now.day))) {
      return false;
    }

    // If it's today, check the calculated times
    final times = getPrayerTimesForDate(now);
    final prayerTime = times[prayerKey.toLowerCase()];
    if (prayerTime != null) {
      return now.isAfter(prayerTime);
    }
    return false;
  }
}
