import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/purchase_request.dart';
import '../state/app_state.dart';
import '../theme/trago_theme.dart';
import 'incoming_requests_screen.dart';

class OrdersScreen extends StatelessWidget {
  final ValueChanged<int> onNavigateTab;

  const OrdersScreen({super.key, required this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final orders = state.ordersForCurrentAccount;
    final currentAccount = state.selectedAccount;

    return Scaffold(
      backgroundColor: TragoColors.background,
      appBar: AppBar(
        backgroundColor: TragoColors.paper,
        title: const Text('Meus pedidos'),
        actions: [
          IconButton(
            tooltip: 'Solicitações recebidas',
            icon: const Icon(Icons.inbox_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const IncomingRequestsScreen(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: TragoColors.skyLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  currentAccount?.displayName ?? 'Sem conta vinculada',
                  style: const TextStyle(
                    color: TragoColors.navy,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.syncWithBackend(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            // Estado real do protótipo acadêmico.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TragoColors.mintLight,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: TragoColors.mintBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: TragoColors.mint,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.isDemoMode
                              ? 'Demonstração acadêmica'
                              : 'Acompanhamento de solicitações',
                          style: const TextStyle(
                            color: TragoColors.navy,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Acompanhe solicitações pendentes, aceitas e rejeitadas. Aceite reserva capacidade, mas não confirma pagamento ou custódia.',
                          style: TextStyle(
                            color: TragoColors.slate,
                            fontSize: 12.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            if (orders.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: TragoColors.paper,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: TragoColors.borderGray),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.shopping_bag_outlined,
                      size: 52,
                      color: TragoColors.muted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      currentAccount == null
                          ? 'Sua conta de compras será criada na próxima etapa'
                          : 'Você ainda não tem pedidos nesta conta',
                      style: TextStyle(
                        color: TragoColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentAccount == null
                          ? 'A sessão está autenticada, mas o provisionamento PF/PJ pertence à T06.'
                          : 'Explore o catálogo global ou simule a importação de qualquer produto do exterior.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: TragoColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    if (currentAccount != null)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Importar um produto'),
                        onPressed: () => onNavigateTab(2),
                      ),
                  ],
                ),
              )
            else
              ...orders.map((req) => _OrderCard(request: req)),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final PurchaseRequest request;

  const _OrderCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final priceUsd = request.product.priceUsdInt;
    final weightKg = request.product.estimatedWeightKg;
    final tax = TaxBreakdown.calculate(
      productUsd: priceUsd.toDouble(),
      weightKg: weightKg > 0 ? weightKg : 0.8,
      pricePerKgUsd: 40,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TragoColors.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: TragoColors.borderGray),
        boxShadow: TragoColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: TragoColors.skyLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: TragoColors.navy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.product.description,
                      style: const TextStyle(
                        color: TragoColors.navy,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Peso: ${weightKg.toStringAsFixed(1).replaceAll('.', ',')} kg • Valor base: US\$ $priceUsd',
                      style: const TextStyle(
                        color: TragoColors.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: TragoColors.mintLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  request.statusLabelPt,
                  style: const TextStyle(
                    color: TragoColors.mint,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            request.id.endsWith('-demo')
                ? 'Pedido de exemplo; não há histórico real.'
                : 'Status confirmado pela API: ${request.status}.',
            style: const TextStyle(color: TragoColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: TragoColors.borderGray),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Estimativa ilustrativa',
                style: TextStyle(color: TragoColors.muted, fontSize: 12.5),
              ),
              Text(
                'US\$ ${tax.totalUsd} (≈ R\$ ${tax.totalBrl})',
                style: const TextStyle(
                  color: TragoColors.navy,
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
