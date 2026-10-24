class Money {
  final String amount;
  final String currency;

  const Money({
    required this.amount,
    required this.currency,
  });

  factory Money.fromJson(Map<String, dynamic> json) {
    return Money(
      amount: json['amount']?.toString() ?? '0',
      currency: json['currency']?.toString() ?? 'USD',
    );
  }

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'currency': currency,
  };

  /// Formata o valor com base na moeda (valores inteiros em centavos ou unidades).
  String format() {
    final parsed = double.tryParse(amount);
    if (parsed == null) return '$currency $amount';

    // Se o valor parece estar em centavos (ex: 4500 para $45.00)
    final value = parsed > 999 && !amount.contains('.') ? parsed / 100.0 : parsed;

    if (currency == 'BRL') {
      return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
    } else {
      return '\$${value.toStringAsFixed(2)} $currency';
    }
  }

  @override
  String toString() => format();
}
