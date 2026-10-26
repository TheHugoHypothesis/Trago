import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/trago_api_client.dart';
import '../models/trip.dart';
import '../state/app_state.dart';
import '../theme/trago_theme.dart';
import 'publish_screen.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  bool _loading = true;
  String? _error;

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
      await context.read<AppState>().refreshMyTrips();
    } on ApiException catch (error) {
      if (mounted) _error = error.message;
    } catch (_) {
      if (mounted) _error = 'Não foi possível carregar suas viagens.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(Trip trip) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublishScreen(trip: trip, onNavigateTab: (_) {}),
      ),
    );
  }

  Future<void> _cancel(Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar viagem?'),
        content: const Text(
          'A viagem deixará de aceitar novos pedidos. Pedidos existentes serão preservados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancelar viagem'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AppState>().cancelTrip(trip);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Viagem cancelada na API.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trips = context.watch<AppState>().myTrips;
    return Scaffold(
      backgroundColor: TragoColors.background,
      appBar: AppBar(title: const Text('Minhas viagens')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 240),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 120),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _refresh,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              )
            : trips.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 120),
                  Icon(
                    Icons.flight_outlined,
                    size: 52,
                    color: TragoColors.muted,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Você ainda não publicou viagens.',
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: trips.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _OwnedTripCard(
                  trip: trips[index],
                  onEdit: () => _edit(trips[index]),
                  onCancel: () => _cancel(trips[index]),
                ),
              ),
      ),
    );
  }
}

class _OwnedTripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  const _OwnedTripCard({
    required this.trip,
    required this.onEdit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (trip.status) {
      'CANCELLED' => ('Cancelada', TragoColors.coral),
      'EXPIRED' => ('Expirada', TragoColors.muted),
      _ => ('Disponível', TragoColors.mint),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${trip.origin} → ${trip.destination}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('${trip.formattedDatePt} • ${trip.formattedPricePerKg}/kg'),
            const SizedBox(height: 4),
            Text(
              'Capacidade: ${trip.formattedAvailableWeight} disponível de ${trip.formattedTotalWeight} • ${trip.formattedReservedWeight} reservada',
              style: const TextStyle(color: TragoColors.muted, fontSize: 12.5),
            ),
            if (trip.isAvailable) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                  TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
