import 'package:flutter/material.dart';
import 'money.dart';

class Trip {
  final String id;
  final String travelerName;
  final String origin;
  final String destination;
  final String departureDate;
  final String timeZone;
  final int availableWeightGrams;
  final Money pricePerKg;
  final bool isDemo;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final String avatarAsset;

  const Trip({
    required this.id,
    required this.travelerName,
    required this.origin,
    required this.destination,
    required this.departureDate,
    required this.timeZone,
    required this.availableWeightGrams,
    required this.pricePerKg,
    this.isDemo = true,
    this.rating = 5.0,
    this.reviewCount = 32,
    this.isVerified = true,
    this.avatarAsset = 'assets/images/travelers/ana.jpg',
  });

  double get availableWeightKg => availableWeightGrams / 1000.0;

  /// Nome limpo para exibição ao consumidor final (remove sufixo "(exemplo)" da API)
  String get cleanTravelerName {
    return travelerName.replaceAll(' (exemplo)', '').trim();
  }

  /// Valor inteiro ou decimal em USD por kg (ex: "4500" -> 45, "45" -> 45)
  int get pricePerKgUsdInt {
    final parsed = double.tryParse(pricePerKg.amount) ?? 45.0;
    if (parsed >= 1000 && !pricePerKg.amount.contains('.')) {
      return (parsed / 100).round();
    }
    return parsed.round();
  }

  String get formattedPricePerKg => 'US\$ $pricePerKgUsdInt';

  String get formattedAvailableWeight {
    final kg = availableWeightKg;
    if (kg == kg.roundToDouble()) {
      return '${kg.toInt()} kg';
    }
    return '${kg.toStringAsFixed(1).replaceAll('.', ',')} kg';
  }

  String get formattedDatePt {
    final parts = departureDate.split('-');
    if (parts.length != 3) return departureDate;
    final year = parts[0];
    final month = int.tryParse(parts[1]) ?? 12;
    final day = int.tryParse(parts[2]) ?? 15;
    const months = [
      '',
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez',
    ];
    final monthName = (month >= 1 && month <= 12) ? months[month] : 'dez';
    return '$day de $monthName de $year';
  }

  String get originFlag => _flagForPlace(origin);
  String get destinationFlag => _flagForPlace(destination);

  static String _flagForPlace(String place) {
    final lower = place.toLowerCase();
    if (lower.contains('eua') ||
        lower.contains('nova york') ||
        lower.contains('miami') ||
        lower.contains('orlando') ||
        lower.contains('nyc')) {
      return '🇺🇸';
    }
    if (lower.contains('londres') || lower.contains('reino unido') || lower.contains('uk')) {
      return '🇬🇧';
    }
    if (lower.contains('tóquio') || lower.contains('toquio') || lower.contains('japão')) {
      return '🇯🇵';
    }
    if (lower.contains('paris') || lower.contains('frança')) {
      return '🇫🇷';
    }
    if (lower.contains('sp') ||
        lower.contains('são paulo') ||
        lower.contains('rio') ||
        lower.contains('curitiba') ||
        lower.contains('brasil') ||
        lower.contains('gru')) {
      return '🇧🇷';
    }
    return '🌍';
  }

  List<Color> get avatarColors {
    final hash = cleanTravelerName.hashCode.abs();
    const palettes = [
      [Color(0xFF2563EB), Color(0xFF60A5FA)],
      [Color(0xFF0E9F6E), Color(0xFF34D399)],
      [Color(0xFF9333EA), Color(0xFFC084FC)],
      [Color(0xFFEA580C), Color(0xFFFB923C)],
      [Color(0xFF0284C7), Color(0xFF38BDF8)],
    ];
    return palettes[hash % palettes.length];
  }

  String get initials {
    final words = cleanTravelerName.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'V';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    final rawName = json['travelerName'] as String? ?? 'Ana C.';
    final clean = rawName.replaceAll(' (exemplo)', '').toLowerCase();
    double defaultRating = 5.0;
    int defaultReviews = 32;
    String defaultAsset = 'assets/images/travelers/ana.jpg';

    if (clean.startsWith('bruno')) {
      defaultRating = 4.9;
      defaultReviews = 18;
      defaultAsset = 'assets/images/travelers/bruno.jpg';
    } else if (clean.startsWith('carla')) {
      defaultRating = 5.0;
      defaultReviews = 27;
      defaultAsset = 'assets/images/travelers/carla.jpg';
    } else if (clean.startsWith('lucas')) {
      defaultRating = 4.9;
      defaultReviews = 41;
      defaultAsset = 'assets/images/travelers/lucas.jpg';
    } else if (clean.startsWith('kenji')) {
      defaultRating = 5.0;
      defaultReviews = 54;
      defaultAsset = 'assets/images/travelers/kenji.jpg';
    }

    return Trip(
      id: json['id'] as String,
      travelerName: rawName,
      origin: json['origin'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      departureDate: json['departureDate'] as String? ?? '',
      timeZone: json['timeZone'] as String? ?? 'America/Sao_Paulo',
      availableWeightGrams: (json['availableWeightGrams'] as num?)?.toInt() ?? 0,
      pricePerKg: Money.fromJson(json['pricePerKg'] as Map<String, dynamic>? ?? {}),
      isDemo: json['isDemo'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? defaultRating,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? defaultReviews,
      isVerified: json['isVerified'] as bool? ?? true,
      avatarAsset: json['avatarAsset'] as String? ?? defaultAsset,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'travelerName': travelerName,
    'origin': origin,
    'destination': destination,
    'departureDate': departureDate,
    'timeZone': timeZone,
    'availableWeightGrams': availableWeightGrams,
    'pricePerKg': pricePerKg.toJson(),
    'isDemo': isDemo,
  };
}

class TripInput {
  final String origin;
  final String destination;
  final String departureDate;
  final String timeZone;
  final int availableWeightGrams;
  final Money pricePerKg;

  const TripInput({
    required this.origin,
    required this.destination,
    required this.departureDate,
    required this.timeZone,
    required this.availableWeightGrams,
    required this.pricePerKg,
  });

  Map<String, dynamic> toJson() => {
    'origin': origin,
    'destination': destination,
    'departureDate': departureDate,
    'timeZone': timeZone,
    'availableWeightGrams': availableWeightGrams,
    'pricePerKg': pricePerKg.toJson(),
  };
}

/// Viagens curadas de referência (idênticas ao Design.png) que complementam os dados da API
const List<Trip> kFeaturedTravelerTrips = [
  Trip(
    id: 'trip-ny-sp',
    travelerName: 'Ana C.',
    origin: 'Nova York (EUA)',
    destination: 'São Paulo (SP)',
    departureDate: '2026-12-15',
    timeZone: 'America/Sao_Paulo',
    availableWeightGrams: 8000,
    pricePerKg: Money(amount: '4500', currency: 'USD'),
    rating: 5.0,
    reviewCount: 32,
    avatarAsset: 'assets/images/travelers/ana.jpg',
  ),
  Trip(
    id: 'trip-bruno-ny-sp',
    travelerName: 'Bruno M.',
    origin: 'Nova York (EUA)',
    destination: 'São Paulo (SP)',
    departureDate: '2026-12-20',
    timeZone: 'America/Sao_Paulo',
    availableWeightGrams: 12000,
    pricePerKg: Money(amount: '4000', currency: 'USD'),
    rating: 4.9,
    reviewCount: 18,
    avatarAsset: 'assets/images/travelers/bruno.jpg',
  ),
  Trip(
    id: 'trip-carla-mia-sp',
    travelerName: 'Carla S.',
    origin: 'Miami (EUA)',
    destination: 'São Paulo (SP)',
    departureDate: '2026-12-18',
    timeZone: 'America/Sao_Paulo',
    availableWeightGrams: 10000,
    pricePerKg: Money(amount: '4200', currency: 'USD'),
    rating: 5.0,
    reviewCount: 27,
    avatarAsset: 'assets/images/travelers/carla.jpg',
  ),
  Trip(
    id: 'trip-lucas-lon-sp',
    travelerName: 'Lucas R.',
    origin: 'Londres (Reino Unido)',
    destination: 'São Paulo (SP)',
    departureDate: '2026-12-22',
    timeZone: 'America/Sao_Paulo',
    availableWeightGrams: 9000,
    pricePerKg: Money(amount: '4400', currency: 'USD'),
    rating: 4.9,
    reviewCount: 41,
    avatarAsset: 'assets/images/travelers/lucas.jpg',
  ),
  Trip(
    id: 'trip-kenji-tyo-sp',
    travelerName: 'Kenji T.',
    origin: 'Tóquio (Japão)',
    destination: 'São Paulo (SP)',
    departureDate: '2026-12-27',
    timeZone: 'America/Sao_Paulo',
    availableWeightGrams: 11000,
    pricePerKg: Money(amount: '4800', currency: 'USD'),
    rating: 5.0,
    reviewCount: 54,
    avatarAsset: 'assets/images/travelers/kenji.jpg',
  ),
];
