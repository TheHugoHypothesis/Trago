import 'package:flutter_test/flutter_test.dart';
import 'package:trago/api/public_integrations_service.dart';
import 'package:trago/models/account.dart';
import 'package:trago/models/catalog_product.dart';
import 'package:trago/models/money.dart';
import 'package:trago/models/purchase_request.dart';
import 'package:trago/models/trip.dart';

void main() {
  group('PublicIntegrationsService & Map Tests', () {
    test('calculates distance and generates flight arc points', () {
      final distance = PublicIntegrationsService.calculateDistanceKm(
        'Nova York (EUA)',
        'São Paulo (SP)',
      );
      expect(distance, greaterThan(7000));
      final nyc = PublicIntegrationsService.resolveHub('Nova York (EUA)').coordinates;
      final sp = PublicIntegrationsService.resolveHub('São Paulo (SP)').coordinates;
      final arc = PublicIntegrationsService.generateFlightArc(nyc, sp);
      expect(arc.length, greaterThan(10));
    });
  });

  group('Money Model Tests', () {
    test('formats USD cents properly', () {
      const money = Money(amount: '4500', currency: 'USD');
      expect(money.format(), equals('\$45.00 USD'));
    });

    test('formats BRL values properly', () {
      const money = Money(amount: '15000', currency: 'BRL');
      expect(money.format(), equals('R\$ 150,00'));
    });
  });

  group('Account Model Tests', () {
    test('identifies organization correctly', () {
      const org = Account(
        id: 'org-1',
        type: 'ORGANIZATION',
        displayName: 'Empresa A',
        taxId: '12.345.678/0001-90',
      );
      const pf = Account(id: 'pf-1', type: 'PERSONAL', displayName: 'Pessoa B');

      expect(org.isOrganization, isTrue);
      expect(pf.isOrganization, isFalse);
    });
  });

  group('Trip & Catalog Tests', () {
    test('calculates availableWeightKg and formats price per kg', () {
      const trip = Trip(
        id: 'trip-1',
        travelerName: 'Ana C. (exemplo)',
        origin: 'Nova York (EUA)',
        destination: 'São Paulo (SP)',
        departureDate: '2026-12-15',
        timeZone: 'America/Sao_Paulo',
        availableWeightGrams: 8000,
        pricePerKg: Money(amount: '4500', currency: 'USD'),
      );
      expect(trip.availableWeightKg, equals(8.0));
      expect(trip.cleanTravelerName, equals('Ana C.'));
      expect(trip.formattedPricePerKg, equals('US\$ 45'));
      expect(trip.formattedDatePt, equals('15 de dez de 2026'));
    });

    test('curated catalog has products and categories', () {
      expect(kCuratedCatalog, isNotEmpty);
      expect(kCatalogCategories, contains('Eletrônicos'));
      expect(kCuratedCatalog.first.savingsPercentage, greaterThan(15));
    });
  });

  group('TaxBreakdown Fiscal Calculation Tests', () {
    test('matches Design.png fiscal calculation breakdown', () {
      final tax = TaxBreakdown.calculate(
        productUsd: 300,
        weightKg: 0.8,
        pricePerKgUsd: 40,
      );
      expect(tax.productUsd, equals(300));
      expect(tax.travelerFeeUsd, equals(32));
      expect(tax.productPlusFreightUsd, equals(332));
      expect(tax.importTaxUsd, equals(96));
      expect(tax.serviceFeeUsd, equals(21));
      expect(tax.totalUsd, equals(449));
    });
  });
}
