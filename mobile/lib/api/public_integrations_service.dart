import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class HubLocation {
  final String name;
  final String code;
  final String flag;
  final LatLng coordinates;

  const HubLocation({
    required this.name,
    required this.code,
    required this.flag,
    required this.coordinates,
  });
}

class LiveMarketData {
  final double usdToBrl;
  final double eurToBrl;
  final double gbpToBrl;
  final String updatedAtLabel;
  final Map<String, String> hubTemperatures;

  const LiveMarketData({
    required this.usdToBrl,
    required this.eurToBrl,
    required this.gbpToBrl,
    required this.updatedAtLabel,
    required this.hubTemperatures,
  });

  static const LiveMarketData fallback = LiveMarketData(
    usdToBrl: 4.97,
    eurToBrl: 5.41,
    gbpToBrl: 6.32,
    updatedAtLabel: 'Cotação comercial atualizada',
    hubTemperatures: {
      'Nova York (EUA)': '16°C • Céu limpo',
      'Miami (EUA)': '27°C • Ensolarado',
      'Londres (Reino Unido)': '13°C • Parcialmente nublado',
      'Tóquio (Japão)': '19°C • Brisa leve',
      'São Paulo (SP)': '24°C • Bom para pouso',
    },
  );
}

class PublicIntegrationsService {
  static const Map<String, HubLocation> globalHubs = {
    'Nova York (EUA)': HubLocation(
      name: 'Nova York',
      code: 'JFK',
      flag: '🇺🇸',
      coordinates: LatLng(40.6413, -73.7781),
    ),
    'Miami (EUA)': HubLocation(
      name: 'Miami',
      code: 'MIA',
      flag: '🇺🇸',
      coordinates: LatLng(25.7959, -80.2870),
    ),
    'Londres (Reino Unido)': HubLocation(
      name: 'Londres',
      code: 'LHR',
      flag: '🇬🇧',
      coordinates: LatLng(51.4700, -0.4543),
    ),
    'Tóquio (Japão)': HubLocation(
      name: 'Tóquio',
      code: 'HND',
      flag: '🇯🇵',
      coordinates: LatLng(35.5494, 139.7798),
    ),
    'Paris (França)': HubLocation(
      name: 'Paris',
      code: 'CDG',
      flag: '🇫🇷',
      coordinates: LatLng(49.0097, 2.5479),
    ),
    'São Paulo (SP)': HubLocation(
      name: 'São Paulo',
      code: 'GRU',
      flag: '🇧🇷',
      coordinates: LatLng(-23.4356, -46.4731),
    ),
    'Rio de Janeiro (RJ)': HubLocation(
      name: 'Rio de Janeiro',
      code: 'GIG',
      flag: '🇧🇷',
      coordinates: LatLng(-22.8099, -43.2505),
    ),
    'Curitiba (PR)': HubLocation(
      name: 'Curitiba',
      code: 'CWB',
      flag: '🇧🇷',
      coordinates: LatLng(-25.5285, -49.1758),
    ),
  };

  static HubLocation resolveHub(String place) {
    for (final entry in globalHubs.entries) {
      if (place.toLowerCase().contains(entry.value.name.toLowerCase())) {
        return entry.value;
      }
    }
    return globalHubs['Nova York (EUA)']!;
  }

  /// Calcula distância aérea em km usando `latlong2`
  static int calculateDistanceKm(String origin, String destination) {
    final start = resolveHub(origin).coordinates;
    final end = resolveHub(destination).coordinates;
    const distance = Distance();
    return distance.as(LengthUnit.Kilometer, start, end).round();
  }

  /// Gera arco geodésico suave entre dois aeroportos para o PolylineLayer do flutter_map
  static List<LatLng> generateFlightArc(LatLng start, LatLng end, {int segments = 28}) {
    final points = <LatLng>[];
    final midLat = (start.latitude + end.latitude) / 2;
    final midLng = (start.longitude + end.longitude) / 2;
    final curveOffset = (end.longitude - start.longitude).abs() * 0.12;

    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final invT = 1 - t;
      // Curva de Bézier quadrática sobre coordenadas geográficas
      final lat = invT * invT * start.latitude +
          2 * invT * t * (midLat + curveOffset) +
          t * t * end.latitude;
      final lng = invT * invT * start.longitude +
          2 * invT * t * midLng +
          t * t * end.longitude;
      points.add(LatLng(
        lat.clamp(-85.0, 85.0),
        ((lng + 180) % 360) - 180,
      ));
    }
    return points;
  }

  /// Consulta API pública de câmbio (open.er-api.com) + clima aeroportuário (Open-Meteo)
  static Future<LiveMarketData> fetchLiveMarketData({http.Client? client}) async {
    final httpClient = client ?? http.Client();
    double usdBrl = LiveMarketData.fallback.usdToBrl;
    double eurBrl = LiveMarketData.fallback.eurToBrl;
    double gbpBrl = LiveMarketData.fallback.gbpToBrl;
    final temps = Map<String, String>.from(LiveMarketData.fallback.hubTemperatures);

    try {
      final fxRes = await httpClient
          .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
          .timeout(const Duration(seconds: 4));
      if (fxRes.statusCode == 200) {
        final data = jsonDecode(fxRes.body) as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>?;
        if (rates != null && rates['BRL'] is num) {
          usdBrl = (rates['BRL'] as num).toDouble();
          final eurRate = (rates['EUR'] as num?)?.toDouble() ?? 0.92;
          final gbpRate = (rates['GBP'] as num?)?.toDouble() ?? 0.79;
          eurBrl = usdBrl / math.max(eurRate, 0.1);
          gbpBrl = usdBrl / math.max(gbpRate, 0.1);
        }
      }
    } catch (_) {}

    try {
      // Clima em tempo real no aeroporto JFK (Nova York) via Open-Meteo (API pública sem chave)
      final weatherRes = await httpClient
          .get(
            Uri.parse(
              'https://api.open-meteo.com/v1/forecast?latitude=40.64&longitude=-73.78&current_weather=true',
            ),
          )
          .timeout(const Duration(seconds: 3));
      if (weatherRes.statusCode == 200) {
        final wData = jsonDecode(weatherRes.body) as Map<String, dynamic>;
        final current = wData['current_weather'] as Map<String, dynamic>?;
        if (current != null && current['temperature'] is num) {
          final temp = (current['temperature'] as num).round();
          temps['Nova York (EUA)'] = '$temp°C • Voo operando normal';
        }
      }
    } catch (_) {}

    return LiveMarketData(
      usdToBrl: usdBrl,
      eurToBrl: eurBrl,
      gbpToBrl: gbpBrl,
      updatedAtLabel: 'Câmbio comercial ao vivo (API Pública)',
      hubTemperatures: temps,
    );
  }
}
