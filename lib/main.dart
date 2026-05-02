

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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
  final TextEditingController _cityController =
      TextEditingController(text: 'Mersin');

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
    if (saved != null) _favorites = saved;
  }

  Future<void> _searchCity(String city) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final location = await WeatherApi.searchLocation(city);
      final weather = await WeatherApi.fetchWeather(location!);
      setState(() => _weather = weather);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _cityController,
                onSubmitted: _searchCity,
                decoration: InputDecoration(
                  hintText: 'Şehir ara...',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _searchCity(_cityController.text),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!))
                        : _WeatherView(weather: _weather!),
              ),
            ],
          ),
        ),
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

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(weather.location.name, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 10),
        Text('${now.temperature.round()}°',
            style: const TextStyle(fontSize: 60)),
        Text(weatherDescription(now.weatherCode)),
      ],
    );
  }
}

// 🔥 API

class WeatherApi {
  static Future<Location?> searchLocation(String city) async {
    final uri = Uri.https(
        'geocoding-api.open-meteo.com', '/v1/search', {'name': city});

    final res = await http.get(uri);
    final json = jsonDecode(res.body);

    if (json['results'] == null) return null;

    return Location.fromJson(json['results'][0]);
  }

  static Future<WeatherData> fetchWeather(Location location) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'current': 'temperature_2m,weather_code'
    });

    final res = await http.get(uri);
    return WeatherData.fromJson(location, jsonDecode(res.body));
  }
}

class Location {
  final String name;
  final double latitude;
  final double longitude;

  Location(
      {required this.name,
      required this.latitude,
      required this.longitude});

  factory Location.fromJson(Map<String, dynamic> json) => Location(
        name: json['name'],
        latitude: json['latitude'],
        longitude: json['longitude'],
      );
}

class WeatherData {
  final Location location;
  final CurrentWeather current;

  WeatherData({required this.location, required this.current});

  factory WeatherData.fromJson(Location loc, Map<String, dynamic> json) =>
      WeatherData(
        location: loc,
        current: CurrentWeather.fromJson(json['current']),
      );
}

class CurrentWeather {
  final double temperature;
  final int weatherCode;

  CurrentWeather({required this.temperature, required this.weatherCode});

  factory CurrentWeather.fromJson(Map<String, dynamic> json) =>
      CurrentWeather(
        temperature: (json['temperature_2m'] as num).toDouble(),
        weatherCode: json['weather_code'],
      );
}

// 🔥 açıklamalar

String weatherDescription(int code) {
  switch (code) {
    case 0:
      return 'Açık';
    case 1:
    case 2:
    case 3:
      return 'Bulutlu';
    default:
      return 'Bilinmiyor';
  }
}
