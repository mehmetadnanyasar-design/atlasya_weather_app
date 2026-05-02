import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const AtlasyaWeatherApp());
}

class AtlasyaWeatherApp extends StatelessWidget {
  const AtlasyaWeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Atlasya Weather',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF07111F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5BB8FF),
          brightness: Brightness.dark,
        ),
      ),
      home: const WeatherHomePage(),
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  final TextEditingController _cityController = TextEditingController(text: 'Mersin');
  bool _loading = true;
  String? _error;
  WeatherData? _weather;
  List<String> _favorites = ['Mersin', 'İstanbul', 'Adana'];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _searchCity('Mersin');
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('favorites');
    if (saved != null && saved.isNotEmpty) setState(() => _favorites = saved);
  }

  Future<void> _saveFavorite(String city) async {
    final clean = city.trim();
    if (clean.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favorites.removeWhere((e) => e.toLowerCase() == clean.toLowerCase());
      _favorites.insert(0, clean);
      _favorites = _favorites.take(8).toList();
    });
    await prefs.setStringList('favorites', _favorites);
  }

  Future<void> _searchCity(String city) async {
    final query = city.trim();
    if (query.length < 2) return;
    setState(() { _loading = true; _error = null; });
    try {
      final location = await WeatherApi.searchLocation(query);
      if (location == null) throw Exception('Şehir bulunamadı.');
      final weather = await WeatherApi.fetchWeather(location);
      await _saveFavorite(location.name);
      _cityController.text = location.name;
      setState(() => _weather = weather);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() { _loading = true; _error = null; });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Konum izni verilmedi.');
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      final location = Location(
        name: 'Konumum', admin1: null, country: '',
        latitude: pos.latitude, longitude: pos.longitude,
      );
      final weather = await WeatherApi.fetchWeather(location);
      setState(() => _weather = weather);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF102C55), Color(0xFF07111F), Color(0xFF170B2F)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _SearchBar(controller: _cityController, onSubmitted: _searchCity)),
                    const SizedBox(width: 10),
                    _GlassButton(icon: Icons.my_location_rounded, onTap: _useCurrentLocation),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _favorites.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => ActionChip(
                      label: Text(_favorites[i]),
                      onPressed: () => _searchCity(_favorites[i]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? _ErrorView(message: _error!, onRetry: () => _searchCity(_cityController.text))
                          : _WeatherView(weather: _weather!),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 54, height: 54,
        decoration: BoxDecoration(color: Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(18)),
        child: Icon(icon),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  const _SearchBar({required this.controller, required this.onSubmitted});
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: 'Şehir ara...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward_rounded), onPressed: () => onSubmitted(controller.text)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
      ),
    );
  }
}

class _WeatherView extends StatelessWidget {
  final WeatherData weather;
  const _WeatherView({required this.weather});

  @override
  Widget build(BuildContext context) {
    final now = weather.current;
    return ListView(
      children: [
        const SizedBox(height: 10),
        Text(weather.location.displayName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Son güncelleme: ${DateFormat('HH:mm').format(DateTime.now())}', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(.65))),
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white.withOpacity(.11), borderRadius: BorderRadius.circular(34), border: Border.all(color: Colors.white.withOpacity(.14))),
              child: Column(
                children: [
                  Icon(weatherIcon(now.weatherCode), size: 92),
                  Text('${now.temperature.round()}°', style: const TextStyle(fontSize: 82, fontWeight: FontWeight.w900, height: 1)),
                  Text(weatherDescription(now.weatherCode), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 22),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _Metric(icon: Icons.air, label: 'Rüzgar', value: '${now.windSpeed.round()} km/s'),
                    _Metric(icon: Icons.water_drop_outlined, label: 'Nem', value: '${now.humidity.round()}%'),
                    _Metric(icon: Icons.thermostat, label: 'Hissedilen', value: '${now.apparentTemperature.round()}°'),
                  ]),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Saatlik Tahmin', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: weather.hourly.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _HourlyCard(hour: weather.hourly[i]),
          ),
        ),
        const SizedBox(height: 24),
        const Text('7 Günlük Tahmin', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        ...weather.daily.map((day) => _ForecastTile(day: day)),
      ],
    );
  }
}

class _HourlyCard extends StatelessWidget {
  final HourlyWeather hour;
  const _HourlyCard({required this.hour});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.08), borderRadius: BorderRadius.circular(22)),
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(DateFormat('HH:mm').format(hour.time), style: TextStyle(color: Colors.white.withOpacity(.65))),
        Icon(weatherIcon(hour.weatherCode), size: 30),
        Text('${hour.temperature.round()}°', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon; final String label; final String value;
  const _Metric({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, size: 25, color: Colors.white.withOpacity(.85)),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(.58))),
    ]);
  }
}

class _ForecastTile extends StatelessWidget {
  final DailyWeather day;
  const _ForecastTile({required this.day});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.075), borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Icon(weatherIcon(day.weatherCode), size: 30),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(DateFormat('EEEE, d MMM', 'tr_TR').format(day.date), style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(weatherDescription(day.weatherCode), style: TextStyle(color: Colors.white.withOpacity(.62))),
        ])),
        Text('${day.minTemp.round()}° / ${day.maxTemp.round()}°', style: const TextStyle(fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_off, size: 64), const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center), const SizedBox(height: 16),
      FilledButton(onPressed: onRetry, child: const Text('Tekrar dene')),
    ]));
  }
}

class WeatherApi {
  static Future<Location?> searchLocation(String city) async {
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {'name': city, 'count': '1', 'language': 'tr', 'format': 'json'});
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('Konum servisine ulaşılamadı.');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;
    return Location.fromJson(results.first as Map<String, dynamic>);
  }

  static Future<WeatherData> fetchWeather(Location location) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m',
      'hourly': 'temperature_2m,weather_code',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
      'timezone': 'auto',
      'forecast_days': '7',
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('Hava durumu alınamadı.');
    return WeatherData.fromJson(location, jsonDecode(response.body) as Map<String, dynamic>);
  }
}

class Location {
  final String name; final String? admin1; final String country; final double latitude; final double longitude;
  Location({required this.name, required this.admin1, required this.country, required this.latitude, required this.longitude});
  String get displayName => [name, admin1, country].where((e) => e != null && e.toString().isNotEmpty).join(', ');
  factory Location.fromJson(Map<String, dynamic> json) => Location(name: json['name'] ?? '', admin1: json['admin1'], country: json['country'] ?? '', latitude: (json['latitude'] as num).toDouble(), longitude: (json['longitude'] as num).toDouble());
}

class WeatherData {
  final Location location; final CurrentWeather current; final List<HourlyWeather> hourly; final List<DailyWeather> daily;
  WeatherData({required this.location, required this.current, required this.hourly, required this.daily});
  factory WeatherData.fromJson(Location location, Map<String, dynamic> json) => WeatherData(
    location: location,
    current: CurrentWeather.fromJson(json['current'] as Map<String, dynamic>),
    hourly: HourlyWeather.listFromJson(json['hourly'] as Map<String, dynamic>).take(24).toList(),
    daily: DailyWeather.listFromJson(json['daily'] as Map<String, dynamic>),
  );
}

class CurrentWeather {
  final double temperature; final double humidity; final double apparentTemperature; final int weatherCode; final double windSpeed;
  CurrentWeather({required this.temperature, required this.humidity, required this.apparentTemperature, required this.weatherCode, required this.windSpeed});
  factory CurrentWeather.fromJson(Map<String, dynamic> json) => CurrentWeather(
    temperature: (json['temperature_2m'] as num).toDouble(), humidity: (json['relative_humidity_2m'] as num).toDouble(),
    apparentTemperature: (json['apparent_temperature'] as num).toDouble(), weatherCode: json['weather_code'] as int, windSpeed: (json['wind_speed_10m'] as num).toDouble());
}

class HourlyWeather {
  final DateTime time; final int weatherCode; final double temperature;
  HourlyWeather({required this.time, required this.weatherCode, required this.temperature});
  static List<HourlyWeather> listFromJson(Map<String, dynamic> json) {
    final times = List<String>.from(json['time']); final codes = List<num>.from(json['weather_code']); final temps = List<num>.from(json['temperature_2m']);
    return List.generate(times.length, (i) => HourlyWeather(time: DateTime.parse(times[i]), weatherCode: codes[i].toInt(), temperature: temps[i].toDouble()));
  }
}

class DailyWeather {
  final DateTime date; final int weatherCode; final double maxTemp; final double minTemp;
  DailyWeather({required this.date, required this.weatherCode, required this.maxTemp, required this.minTemp});
  static List<DailyWeather> listFromJson(Map<String, dynamic> json) {
    final times = List<String>.from(json['time']); final codes = List<num>.from(json['weather_code']); final maxTemps = List<num>.from(json['temperature_2m_max']); final minTemps = List<num>.from(json['temperature_2m_min']);
    return List.generate(times.length, (i) => DailyWeather(date: DateTime.parse(times[i]), weatherCode: codes[i].toInt(), maxTemp: maxTemps[i].toDouble(), minTemp: minTemps[i].toDouble()));
  }
}

IconData weatherIcon(int code) {
  if (code == 0) return Icons.wb_sunny_rounded;
  if ([1, 2, 3].contains(code)) return Icons.cloud_queue_rounded;
  if ([45, 48].contains(code)) return Icons.foggy;
  if ([51, 53, 55, 61, 63, 65, 80, 81, 82].contains(code)) return Icons.water_drop_rounded;
  if ([71, 73, 75, 77, 85, 86].contains(code)) return Icons.ac_unit_rounded;
  if ([95, 96, 99].contains(code)) return Icons.thunderstorm_rounded;
  return Icons.cloud_rounded;
}

String weatherDescription(int code) {
  switch (code) {
    case 0: return 'Açık';
    case 1: return 'Az bulutlu';
    case 2: return 'Parçalı bulutlu';
    case 3: return 'Kapalı';
    case 45: case 48: return 'Sisli';
    case 51: case 53: case 55: return 'Çisenti';
    case 61: case 63: case 65: return 'Yağmurlu';
    case 71: case 73: case 75: return 'Karlı';
    case 80: case 81: case 82: return 'Sağanak';
    case 95: case 96: case 99: return 'Gök gürültülü';
    default: return 'Bulutlu';
  }
}
