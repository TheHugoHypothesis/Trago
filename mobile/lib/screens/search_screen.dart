import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trip.dart';
import '../state/app_state.dart';
import '../theme/trago_theme.dart';
import '../widgets/traveler_card.dart';

class SearchScreen extends StatefulWidget {
  final ValueChanged<int> onNavigateTab;
  final String? initialOriginFilter;

  const SearchScreen({
    super.key,
    required this.onNavigateTab,
    this.initialOriginFilter,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _selectedOrigin = 'Todas as origens';
  String _selectedDestination = 'São Paulo (SP)';
  String _selectedDateRange = 'Qualquer data';
  String _sortBy = 'recomendados';

  static const List<Map<String, String>> _origins = [
    {'label': 'Todas as origens', 'flag': '🌍'},
    {'label': 'Nova York (EUA)', 'flag': '🇺🇸'},
    {'label': 'Miami (EUA)', 'flag': '🇺🇸'},
    {'label': 'Londres (Reino Unido)', 'flag': '🇬🇧'},
    {'label': 'Tóquio (Japão)', 'flag': '🇯🇵'},
  ];

  static const List<Map<String, String>> _destinations = [
    {'label': 'São Paulo (SP)', 'flag': '🇧🇷'},
    {'label': 'Rio de Janeiro (RJ)', 'flag': '🇧🇷'},
    {'label': 'Curitiba (PR)', 'flag': '🇧🇷'},
  ];

  static const List<String> _dateRanges = [
    'Qualquer data',
    'Até 18 de dez de 2026',
    'Até 25 de dez de 2026',
  ];

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialOriginFilter != null &&
        widget.initialOriginFilter != oldWidget.initialOriginFilter) {
      setState(() {
        _selectedOrigin = widget.initialOriginFilter!;
      });
    }
  }

  String _flagForOrigin(String origin) {
    return _origins
            .where((o) => o['label'] == origin)
            .map((o) => o['flag']!)
            .firstOrNull ??
        '🇺🇸';
  }

  List<Trip> _filterAndSort(List<Trip> allTrips) {
    var list = allTrips.where((t) {
      if (_selectedOrigin != 'Todas as origens') {
        final cityKeyword = _selectedOrigin.split(' ').first.toLowerCase();
        if (!t.origin.toLowerCase().contains(cityKeyword)) return false;
      }
      if (_selectedDateRange == 'Até 18 de dez de 2026') {
        if (t.departureDate.compareTo('2026-12-18') > 0) return false;
      } else if (_selectedDateRange == 'Até 25 de dez de 2026') {
        if (t.departureDate.compareTo('2026-12-25') > 0) return false;
      }
      return true;
    }).toList();

    if (_sortBy == 'menor_preco') {
      list.sort((a, b) => a.pricePerKgUsdInt.compareTo(b.pricePerKgUsdInt));
    } else if (_sortBy == 'maior_espaco') {
      list.sort((a, b) => b.availableWeightGrams.compareTo(a.availableWeightGrams));
    } else if (_sortBy == 'data_proxima') {
      list.sort((a, b) => a.departureDate.compareTo(b.departureDate));
    }
    return list;
  }

  void _showSortMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TragoColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ordenar viajantes por',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: TragoColors.navy,
              ),
            ),
            const SizedBox(height: 12),
            _SortOptionTile(
              title: 'Recomendados (melhor avaliação)',
              selected: _sortBy == 'recomendados',
              onTap: () {
                setState(() => _sortBy = 'recomendados');
                Navigator.pop(ctx);
              },
            ),
            _SortOptionTile(
              title: 'Menor preço por kg',
              selected: _sortBy == 'menor_preco',
              onTap: () {
                setState(() => _sortBy = 'menor_preco');
                Navigator.pop(ctx);
              },
            ),
            _SortOptionTile(
              title: 'Maior espaço disponível na mala',
              selected: _sortBy == 'maior_espaco',
              onTap: () {
                setState(() => _sortBy = 'maior_espaco');
                Navigator.pop(ctx);
              },
            ),
            _SortOptionTile(
              title: 'Data de chegada mais próxima',
              selected: _sortBy == 'data_proxima',
              onTap: () {
                setState(() => _sortBy = 'data_proxima');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final filteredTrips = _filterAndSort(state.trips);

    return Scaffold(
      backgroundColor: TragoColors.background,
      appBar: AppBar(
        backgroundColor: TragoColors.paper,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 30, color: TragoColors.navy),
          onPressed: () => widget.onNavigateTab(0),
        ),
        title: const Text('Encontrar um viajante'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          // Card de Filtros idêntico ao Design.png
          Container(
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
                const Text(
                  'De onde vem o produto?',
                  style: TextStyle(
                    color: TragoColors.navy,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _SelectorField(
                  leadingIcon: Icons.flight_takeoff_rounded,
                  value: _selectedOrigin,
                  trailingFlag: _flagForOrigin(_selectedOrigin),
                  items: _origins.map((e) => e['label']!).toList(),
                  onChanged: (val) => setState(() => _selectedOrigin = val),
                ),
                const SizedBox(height: 14),

                const Text(
                  'Para onde quer receber?',
                  style: TextStyle(
                    color: TragoColors.navy,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _SelectorField(
                  leadingIcon: Icons.location_on_outlined,
                  value: _selectedDestination,
                  trailingFlag: '🇧🇷',
                  items: _destinations.map((e) => e['label']!).toList(),
                  onChanged: (val) => setState(() => _selectedDestination = val),
                ),
                const SizedBox(height: 14),

                const Text(
                  'Quando precisa?',
                  style: TextStyle(
                    color: TragoColors.navy,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _SelectorField(
                  leadingIcon: Icons.calendar_today_outlined,
                  value: _selectedDateRange,
                  items: _dateRanges,
                  onChanged: (val) => setState(() => _selectedDateRange = val),
                ),
                const SizedBox(height: 18),

                // Botão Coral "Buscar viajantes"
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TragoColors.coral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.search_rounded, size: 22),
                    label: const Text(
                      'Buscar viajantes',
                      style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () {
                      state.syncWithBackend();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${filteredTrips.length} viajantes verificados encontrados.'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Cabeçalho "Viajantes disponíveis" + Botão "Ordenar"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Viajantes disponíveis (${filteredTrips.length})',
                  style: const TextStyle(
                    color: TragoColors.navy,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _showSortMenu(context),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.filter_alt_outlined, size: 18, color: TragoColors.navy),
                      SizedBox(width: 4),
                      Text(
                        'Ordenar',
                        style: TextStyle(
                          color: TragoColors.navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (filteredTrips.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: TragoColors.paper,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: TragoColors.borderGray),
              ),
              child: Column(
                children: [
                  const Icon(Icons.flight_outlined, size: 46, color: TragoColors.muted),
                  const SizedBox(height: 12),
                  const Text(
                    'Nenhum viajante para este filtro específico.',
                    style: TextStyle(
                      color: TragoColors.navy,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedOrigin = 'Todas as origens';
                        _selectedDateRange = 'Qualquer data';
                      });
                    },
                    child: const Text('Mostrar todas as rotas'),
                  ),
                ],
              ),
            )
          else
            ...filteredTrips.map(
              (trip) => TravelerCard(
                trip: trip,
                isSelected: state.selectedTrip.id == trip.id,
                onTap: () {
                  state.selectTrip(trip);
                  widget.onNavigateTab(2); // Abre Detalhes do Pedido com este viajante
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectorField extends StatelessWidget {
  final IconData leadingIcon;
  final String value;
  final String? trailingFlag;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _SelectorField({
    required this.leadingIcon,
    required this.value,
    this.trailingFlag,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: TragoColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TragoColors.borderGray, width: 1.2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailingFlag != null) ...[
                Text(trailingFlag!, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.keyboard_arrow_down_rounded, color: TragoColors.navy),
            ],
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                children: [
                  Icon(leadingIcon, size: 19, color: TragoColors.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: TragoColors.navy,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}

class _SortOptionTile extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _SortOptionTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(
          color: selected ? TragoColors.coral : TragoColors.navy,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: TragoColors.coral)
          : null,
      onTap: onTap,
    );
  }
}
