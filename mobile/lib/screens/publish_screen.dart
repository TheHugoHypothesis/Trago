import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/trago_theme.dart';

class PublishScreen extends StatefulWidget {
  final ValueChanged<int> onNavigateTab;

  const PublishScreen({super.key, required this.onNavigateTab});

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  final _nameController = TextEditingController(text: 'Mariana V.');
  String _selectedOrigin = 'Nova York (EUA)';
  String _selectedDestination = 'São Paulo (SP)';
  final _dateController = TextEditingController(text: '2026-12-26');
  double _availableKg = 8.0;
  int _pricePerKgUsd = 42;
  bool _isPublishing = false;

  static const List<String> _origins = [
    'Nova York (EUA)',
    'Miami (EUA)',
    'Londres (Reino Unido)',
    'Tóquio (Japão)',
    'Paris (França)',
  ];

  static const List<String> _destinations = [
    'São Paulo (SP)',
    'Rio de Janeiro (RJ)',
    'Curitiba (PR)',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  int get _estimatedEarningsUsd => (_availableKg * _pricePerKgUsd).round();
  int get _estimatedEarningsBrl => (_estimatedEarningsUsd * 4.98).round();

  Future<void> _submit() async {
    setState(() => _isPublishing = true);
    final state = Provider.of<AppState>(context, listen: false);
    await state.publishTrip(
      travelerName: _nameController.text,
      origin: _selectedOrigin,
      destination: _selectedDestination,
      departureDate: _dateController.text,
      availableWeightKg: _availableKg.round(),
      pricePerKgUsd: _pricePerKgUsd,
    );
    if (!mounted) return;
    setState(() => _isPublishing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sua viagem foi publicada e já está visível para compradores!'),
        backgroundColor: TragoColors.mint,
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.onNavigateTab(3); // Vai para a lista de viagens
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TragoColors.background,
      appBar: AppBar(
        backgroundColor: TragoColors.paper,
        title: const Text('Cadastrar minha viagem'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        children: [
          // Card de Ganho Estimado (Navy + Mint)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [TragoColors.navy, TragoColors.navyLight],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: TragoColors.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: TragoColors.mintLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Simulador do Viajante',
                        style: TextStyle(
                          color: TragoColors.mint,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.luggage_rounded, color: Colors.white70),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Ganho estimado nesta viagem',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'US\$ $_estimatedEarningsUsd',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '≈ R\$ $_estimatedEarningsBrl',
                      style: const TextStyle(
                        color: Color(0xFF6EE7B7),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Para ${_availableKg.toInt()} kg disponíveis a US\$ $_pricePerKgUsd/kg • Declaração aduaneira assistida.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Formulário da Viagem
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: TragoColors.paper,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: TragoColors.borderGray),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detalhes do seu voo',
                  style: TextStyle(
                    color: TragoColors.navy,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome de exibição no perfil',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedOrigin,
                  decoration: const InputDecoration(
                    labelText: 'Cidade de origem do voo',
                    prefixIcon: Icon(Icons.flight_takeoff_rounded),
                  ),
                  items: _origins
                      .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedOrigin = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedDestination,
                  decoration: const InputDecoration(
                    labelText: 'Cidade de chegada no Brasil',
                    prefixIcon: Icon(Icons.flight_land_rounded),
                  ),
                  items: _destinations
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedDestination = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: 'Data do voo (AAAA-MM-DD)',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                ),
                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Espaço livre na bagagem',
                      style: TextStyle(
                        color: TragoColors.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${_availableKg.toInt()} kg',
                      style: const TextStyle(
                        color: TragoColors.coral,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _availableKg,
                  min: 1,
                  max: 23,
                  divisions: 22,
                  activeColor: TragoColors.coral,
                  onChanged: (val) => setState(() => _availableKg = val),
                ),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sua tarifa por kg',
                      style: TextStyle(
                        color: TragoColors.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'US\$ $_pricePerKgUsd / kg',
                      style: const TextStyle(
                        color: TragoColors.navy,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _pricePerKgUsd.toDouble(),
                  min: 25,
                  max: 65,
                  divisions: 40,
                  activeColor: TragoColors.navy,
                  onChanged: (val) => setState(() => _pricePerKgUsd = val.round()),
                ),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.airplanemode_active_rounded),
                    label: Text(
                      _isPublishing ? 'Publicando oferta…' : 'Publicar oferta de bagagem',
                    ),
                    onPressed: _isPublishing ? null : _submit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
