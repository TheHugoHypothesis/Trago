import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/trago_api_client.dart';
import '../models/purchase_request.dart';
import '../state/app_state.dart';
import '../theme/trago_theme.dart';

class IncomingRequestsScreen extends StatefulWidget {
  const IncomingRequestsScreen({super.key});

  @override
  State<IncomingRequestsScreen> createState() => _IncomingRequestsScreenState();
}

class _IncomingRequestsScreenState extends State<IncomingRequestsScreen> {
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      await context.read<AppState>().refreshIncomingRequests();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar as solicitações.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _decide(PurchaseRequest request, bool accept) async {
    setState(() {
      _busyId = request.id;
      _error = null;
    });
    try {
      await context.read<AppState>().decidePurchaseRequest(
        request,
        accept: accept,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept ? 'Solicitação aceita.' : 'Solicitação rejeitada.',
            ),
          ),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'A API não confirmou a decisão. Tente novamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<AppState>().incomingRequests;
    return Scaffold(
      backgroundColor: TragoColors.background,
      appBar: AppBar(title: const Text('Solicitações recebidas')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: TragoColors.skyLight,
                border: Border.all(color: TragoColors.skyBorder),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Aceitar reserva a capacidade informada após confirmação da API. Isso não confirma pagamento, custódia ou transporte.',
                style: TextStyle(color: TragoColors.navy, fontSize: 12.5),
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 28),
              const Center(child: CircularProgressIndicator()),
            ] else if (_error != null) ...[
              const SizedBox(height: 18),
              Text(
                _error!,
                style: const TextStyle(color: TragoColors.coralDark),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _refresh,
                child: const Text('Tentar novamente'),
              ),
            ] else if (requests.isEmpty) ...[
              const SizedBox(height: 32),
              const Icon(
                Icons.inbox_outlined,
                size: 52,
                color: TragoColors.muted,
              ),
              const SizedBox(height: 10),
              const Center(child: Text('Nenhuma solicitação recebida.')),
            ] else ...[
              const SizedBox(height: 16),
              for (final request in requests)
                _IncomingCard(
                  request: request,
                  busy: _busyId == request.id,
                  onAccept: () => _decide(request, true),
                  onReject: () => _decide(request, false),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IncomingCard extends StatelessWidget {
  final PurchaseRequest request;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _IncomingCard({
    required this.request,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          request.product.description,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(request.statusLabelPt),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Pedido ${request.id}\nViagem ${request.tripId}\nConta compradora ${request.accountId}\nPeso estimado: ${request.product.estimatedWeightGrams} g',
            ),
          ),
          if (request.tripCapacity case final capacity?) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Capacidade confirmada: ${capacity.availableWeightGrams} g disponível, ${capacity.reservedWeightGrams} g reservada de ${capacity.totalWeightGrams} g.',
                style: const TextStyle(
                  color: TragoColors.muted,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
          if (request.isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onReject,
                    child: const Text('Rejeitar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: busy ? null : onAccept,
                    child: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Aceitar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
