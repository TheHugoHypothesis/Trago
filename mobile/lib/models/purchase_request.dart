import 'money.dart';

class TripCapacity {
  final int totalWeightGrams;
  final int reservedWeightGrams;
  final int availableWeightGrams;

  const TripCapacity({
    required this.totalWeightGrams,
    required this.reservedWeightGrams,
    required this.availableWeightGrams,
  });

  factory TripCapacity.fromJson(Map<String, dynamic> json) => TripCapacity(
    totalWeightGrams: (json['totalWeightGrams'] as num).toInt(),
    reservedWeightGrams: (json['reservedWeightGrams'] as num).toInt(),
    availableWeightGrams: (json['availableWeightGrams'] as num).toInt(),
  );

  Map<String, dynamic> toJson() => {
    'totalWeightGrams': totalWeightGrams,
    'reservedWeightGrams': reservedWeightGrams,
    'availableWeightGrams': availableWeightGrams,
  };
}

class TaxBreakdown {
  final int productUsd;
  final int travelerFeeUsd;
  final int importTaxUsd;
  final int serviceFeeUsd;
  final int totalUsd;
  final int totalBrl;

  const TaxBreakdown({
    required this.productUsd,
    required this.travelerFeeUsd,
    required this.importTaxUsd,
    required this.serviceFeeUsd,
    required this.totalUsd,
    required this.totalBrl,
  });

  int get productPlusFreightUsd => productUsd + travelerFeeUsd;

  /// Calcula em tempo real conforme as regras do Design.png:
  /// Ex: US$ 300 produto + 0,8 kg * US$ 40 = US$ 332
  /// Tributos estimados (~28.9% sobre base) = US$ 96
  /// Taxa Trago! (6%) = US$ 21
  /// Total = US$ 449 (≈ R$ 2.230)
  factory TaxBreakdown.calculate({
    required double productUsd,
    required double weightKg,
    required int pricePerKgUsd,
    double exchangeRateBrl = 4.966,
  }) {
    final prod = productUsd.round().clamp(1, 50000);
    final freight = (weightKg * pricePerKgUsd).round().clamp(10, 10000);
    final base = prod + freight;
    final importTax = (base * 0.28915).round();
    final serviceFee = ((base + importTax) * 0.049).round().clamp(5, 5000);
    final total = base + importTax + serviceFee;
    final brl = ((total * exchangeRateBrl) / 10).round() * 10;

    return TaxBreakdown(
      productUsd: prod,
      travelerFeeUsd: freight,
      importTaxUsd: importTax,
      serviceFeeUsd: serviceFee,
      totalUsd: total,
      totalBrl: brl,
    );
  }
}

class Product {
  final String description;
  final String? url;
  final Money price;
  final int estimatedWeightGrams;

  const Product({
    required this.description,
    this.url,
    required this.price,
    required this.estimatedWeightGrams,
  });

  double get estimatedWeightKg => estimatedWeightGrams / 1000.0;

  int get priceUsdInt {
    final parsed = double.tryParse(price.amount) ?? 300;
    if (parsed >= 10000 && !price.amount.contains('.')) {
      return (parsed / 100).round();
    }
    return parsed.round();
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      description: json['description'] as String? ?? '',
      url: json['url'] as String?,
      price: Money.fromJson(json['price'] as Map<String, dynamic>? ?? {}),
      estimatedWeightGrams:
          (json['estimatedWeightGrams'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'description': description,
    if (url != null && url!.isNotEmpty) 'url': url,
    'price': price.toJson(),
    'estimatedWeightGrams': estimatedWeightGrams,
  };
}

class PurchaseRequest {
  final String id;
  final String accountId;
  final String tripId;
  final Product product;
  final String status;
  final String createdAt;
  final String? updatedAt;
  final TripCapacity? tripCapacity;

  const PurchaseRequest({
    required this.id,
    required this.accountId,
    required this.tripId,
    required this.product,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.tripCapacity,
  });

  bool get isPending => status == 'PENDING';

  String get statusLabelPt {
    switch (status) {
      case 'PAID':
      case 'ESCROW_PROTECTED':
        return 'Status legado sem pagamento verificado';
      case 'IN_TRANSIT':
        return 'Trânsito não verificado (exemplo)';
      case 'DELIVERED':
        return 'Entrega não verificada (exemplo)';
      case 'ACCEPTED':
        return 'Aceita pelo viajante';
      case 'REJECTED':
        return 'Rejeitada pelo viajante';
      case 'PENDING':
      default:
        return 'Aguardando decisão';
    }
  }

  factory PurchaseRequest.fromJson(Map<String, dynamic> json) {
    return PurchaseRequest(
      id: json['id'] as String,
      accountId: json['accountId'] as String? ?? '',
      tripId: json['tripId'] as String? ?? '',
      product: Product.fromJson(json['product'] as Map<String, dynamic>? ?? {}),
      status: json['status'] as String? ?? 'PENDING',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String?,
      tripCapacity: json['tripCapacity'] is Map<String, dynamic>
          ? TripCapacity.fromJson(json['tripCapacity'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'accountId': accountId,
    'tripId': tripId,
    'product': product.toJson(),
    'status': status,
    'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
    if (tripCapacity != null) 'tripCapacity': tripCapacity!.toJson(),
  };
}

class RequestInput {
  final String accountId;
  final String tripId;
  final Product product;

  const RequestInput({
    required this.accountId,
    required this.tripId,
    required this.product,
  });

  Map<String, dynamic> toJson() => {
    'accountId': accountId,
    'tripId': tripId,
    'product': product.toJson(),
  };
}
