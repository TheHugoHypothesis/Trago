import 'dart:math';
import 'package:flutter/foundation.dart';
import '../api/public_integrations_service.dart';
import '../api/trago_api_client.dart';
import '../models/account.dart';
import '../models/catalog_product.dart';
import '../models/money.dart';
import '../models/purchase_request.dart';
import '../models/trip.dart';

class AppState extends ChangeNotifier {
  static const String _defaultBackendUrl = 'http://localhost:3001';

  List<Account> _accounts = const [
    Account(
      id: 'personal-buyer',
      type: 'PERSONAL',
      displayName: 'Minha Conta Pessoal',
    ),
    Account(
      id: 'company-demo',
      type: 'ORGANIZATION',
      displayName: 'Trago Tech Importadora LTDA',
      taxId: '12.345.678/0001-95',
    ),
  ];

  late Account _selectedAccount;
  List<Trip> _trips = List<Trip>.from(kFeaturedTravelerTrips);
  late Trip _selectedTrip;
  CatalogProduct _selectedCatalogProduct = kCuratedCatalog.first;
  LiveMarketData _marketData = LiveMarketData.fallback;

  List<PurchaseRequest> _orders = [
    const PurchaseRequest(
      id: 'ord-xm5-demo',
      accountId: 'personal-buyer',
      tripId: 'trip-ny-sp',
      product: Product(
        description: 'Fone de ouvido sem fio WH-1000XM5',
        url: 'https://www.amazon.com/dp/B09XS7JWHH',
        price: Money(amount: '300', currency: 'USD'),
        estimatedWeightGrams: 800,
      ),
      status: 'IN_TRANSIT',
      createdAt: '2026-10-22T14:30:00Z',
    ),
  ];

  bool _isSyncing = false;

  AppState() {
    _selectedAccount = _accounts.first;
    _selectedTrip = _trips.first;
    syncWithBackend();
  }

  List<Account> get accounts => _accounts;
  Account get selectedAccount => _selectedAccount;
  List<Trip> get trips => _trips;
  Trip get selectedTrip => _selectedTrip;
  CatalogProduct get selectedCatalogProduct => _selectedCatalogProduct;
  LiveMarketData get marketData => _marketData;
  bool get isSyncing => _isSyncing;

  List<PurchaseRequest> get ordersForCurrentAccount {
    return _orders.where((o) => o.accountId == _selectedAccount.id).toList();
  }

  List<PurchaseRequest> get allOrders => _orders;

  TragoApiClient _clientForActor(String actor) {
    return TragoApiClient(baseUrl: _defaultBackendUrl, token: 'dev:$actor');
  }

  Future<void> syncWithBackend() async {
    _isSyncing = true;
    notifyListeners();

    try {
      // Atualiza dados de APIs públicas (Câmbio USD/BRL + Clima de aeroportos)
      _marketData = await PublicIntegrationsService.fetchLiveMarketData();
    } catch (_) {}

    try {
      final buyerClient = _clientForActor('buyer');
      final remoteAccounts = await buyerClient.getAccounts();
      if (remoteAccounts.isNotEmpty) {
        _accounts = remoteAccounts;
        if (!_accounts.any((a) => a.id == _selectedAccount.id)) {
          _selectedAccount = _accounts.first;
        }
      }

      final remoteTrips = await buyerClient.searchTrips();
      if (remoteTrips.items.isNotEmpty) {
        final merged = <String, Trip>{};
        for (final t in remoteTrips.items) {
          merged[t.id] = t;
        }
        for (final t in kFeaturedTravelerTrips) {
          merged.putIfAbsent(t.id, () => t);
        }
        _trips = merged.values.toList();
        _selectedTrip = _trips.first;
      }

      final remoteOrders = await buyerClient.getPurchaseRequests(_selectedAccount.id);
      if (remoteOrders.items.isNotEmpty) {
        final mergedOrders = <String, PurchaseRequest>{};
        for (final o in remoteOrders.items) {
          mergedOrders[o.id] = o;
        }
        for (final o in _orders) {
          mergedOrders.putIfAbsent(o.id, () => o);
        }
        _orders = mergedOrders.values.toList();
      }
    } catch (_) {
      // Mantém dados locais silenciosamente caso offline ou em ambiente de teste
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void selectAccount(String accountId) {
    final found = _accounts.where((a) => a.id == accountId).firstOrNull;
    if (found != null) {
      _selectedAccount = found;
      notifyListeners();
      syncWithBackend();
    }
  }

  void selectTrip(Trip trip) {
    _selectedTrip = trip;
    notifyListeners();
  }

  void selectCatalogProduct(CatalogProduct product) {
    _selectedCatalogProduct = product;
    final matchingTrip = _trips
        .where((t) => t.origin.toLowerCase().contains(product.originCity.split(' ').first.toLowerCase()))
        .firstOrNull;
    if (matchingTrip != null) {
      _selectedTrip = matchingTrip;
    }
    notifyListeners();
  }

  Future<PurchaseRequest> createOrder({
    required String description,
    String? url,
    required int priceUsd,
    required int weightGrams,
    Trip? tripOverride,
  }) async {
    final targetTrip = tripOverride ?? _selectedTrip;
    final product = Product(
      description: description.trim(),
      url: (url != null && url.trim().isNotEmpty) ? url.trim() : null,
      price: Money(amount: priceUsd.toString(), currency: 'USD'),
      estimatedWeightGrams: weightGrams,
    );

    final input = RequestInput(
      accountId: _selectedAccount.id,
      tripId: targetTrip.id,
      product: product,
    );

    final idempotencyKey =
        'ord-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}';

    try {
      final created = await _clientForActor('buyer').createPurchaseRequest(
        input,
        idempotencyKey,
      );
      _orders = [created, ..._orders];
      notifyListeners();
      return created;
    } catch (_) {
      final fallback = PurchaseRequest(
        id: 'ord-${DateTime.now().millisecondsSinceEpoch}',
        accountId: _selectedAccount.id,
        tripId: targetTrip.id,
        product: product,
        status: 'ESCROW_PROTECTED',
        createdAt: DateTime.now().toIso8601String(),
      );
      _orders = [fallback, ..._orders];
      notifyListeners();
      return fallback;
    }
  }

  Future<Trip> publishTrip({
    required String travelerName,
    required String origin,
    required String destination,
    required String departureDate,
    required int availableWeightKg,
    required int pricePerKgUsd,
  }) async {
    final input = TripInput(
      origin: origin.trim(),
      destination: destination.trim(),
      departureDate: departureDate.trim(),
      timeZone: 'America/Sao_Paulo',
      availableWeightGrams: availableWeightKg * 1000,
      pricePerKg: Money(amount: (pricePerKgUsd * 100).toString(), currency: 'USD'),
    );

    try {
      final created = await _clientForActor('traveler').createTrip(input);
      final enriched = Trip(
        id: created.id,
        travelerName: travelerName.trim().isNotEmpty ? travelerName.trim() : 'Você (Viajante)',
        origin: created.origin,
        destination: created.destination,
        departureDate: created.departureDate,
        timeZone: created.timeZone,
        availableWeightGrams: created.availableWeightGrams,
        pricePerKg: created.pricePerKg,
        rating: 5.0,
        reviewCount: 12,
      );
      _trips = [enriched, ..._trips];
      _selectedTrip = enriched;
      notifyListeners();
      return enriched;
    } catch (_) {
      final localTrip = Trip(
        id: 'trip-${DateTime.now().millisecondsSinceEpoch}',
        travelerName: travelerName.trim().isNotEmpty ? travelerName.trim() : 'Você (Viajante)',
        origin: origin.trim(),
        destination: destination.trim(),
        departureDate: departureDate.trim(),
        timeZone: 'America/Sao_Paulo',
        availableWeightGrams: availableWeightKg * 1000,
        pricePerKg: Money(amount: (pricePerKgUsd * 100).toString(), currency: 'USD'),
        rating: 5.0,
        reviewCount: 12,
      );
      _trips = [localTrip, ..._trips];
      _selectedTrip = localTrip;
      notifyListeners();
      return localTrip;
    }
  }
}
