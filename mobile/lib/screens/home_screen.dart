import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/catalog_product.dart';
import '../state/app_state.dart';
import '../theme/trago_theme.dart';
import '../widgets/catalog_product_card.dart';
import '../widgets/trago_logo.dart';
import '../widgets/world_route_hero.dart';
import 'publish_screen.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int> onNavigateTab;
  final ValueChanged<String>? onSearchOrigin;

  const HomeScreen({
    super.key,
    required this.onNavigateTab,
    this.onSearchOrigin,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'Todos';

  List<CatalogProduct> get _filteredProducts {
    if (_selectedCategory == 'Todos') return kCuratedCatalog;
    return kCuratedCatalog
        .where((p) => p.category == _selectedCategory)
        .toList();
  }

  void _openPublishSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: TragoColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: PublishScreen(
            onNavigateTab: (tab) {
              Navigator.of(ctx).pop();
              widget.onNavigateTab(tab);
            },
          ),
        ),
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TragoColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: TragoColors.navy,
                ),
                SizedBox(width: 10),
                Text(
                  'Notificações',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: TragoColors.navy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _NotificationTile(
              icon: Icons.flight_land_rounded,
              color: TragoColors.verifiedBlue,
              title: 'Exemplo de notificação de viagem',
              subtitle: 'Voo e chegada não são monitorados.',
              time: 'Demo',
            ),
            const Divider(height: 20, color: TragoColors.borderGray),
            _NotificationTile(
              icon: Icons.verified_user_outlined,
              color: TragoColors.mint,
              title: 'Exemplo de estimativa fiscal',
              subtitle: 'Sem garantia de câmbio ou validação aduaneira.',
              time: 'Demo',
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final currentAccount = state.selectedAccount;

    return Scaffold(
      backgroundColor: TragoColors.paper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            // Top Header: TRAGO! Logo + Seletor PF/PJ sutil + Sino
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: TragoLogo(showTagline: true, fontSize: 30),
                ),
                Row(
                  children: [
                    // Botão rápido de perfil PF/PJ
                    InkWell(
                      onTap: () => widget.onNavigateTab(4),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: TragoColors.skyLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: TragoColors.skyBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              currentAccount?.isOrganization == true
                                  ? Icons.business_rounded
                                  : Icons.person_outline_rounded,
                              size: 15,
                              color: TragoColors.navy,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              currentAccount == null
                                  ? 'Sessão'
                                  : currentAccount.isOrganization
                                  ? 'Conta PJ'
                                  : 'Conta PF',
                              style: const TextStyle(
                                color: TragoColors.navy,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Stack(
                      children: [
                        IconButton(
                          onPressed: () => _showNotificationsSheet(context),
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            color: TragoColors.navy,
                            size: 28,
                          ),
                        ),
                        Positioned(
                          right: 11,
                          top: 11,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: TragoColors.coral,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Hero Headline idêntica ao Design.png
            const Text(
              'Compre no exterior\ne receba com viajantes\nreais.',
              style: TextStyle(
                color: TragoColors.navy,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1.16,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Produtos do mundo todo, mais rápido,\nmais econômico e com segurança.',
              style: TextStyle(
                color: TragoColors.slate,
                fontSize: 15.5,
                fontWeight: FontWeight.w400,
                height: 1.38,
              ),
            ),
            const SizedBox(height: 18),

            // Mapa Global Animado
            WorldRouteHero(
              onCityTap: (city) {
                widget.onSearchOrigin?.call(city);
                widget.onNavigateTab(3); // Aba Viagens
              },
            ),
            const SizedBox(height: 18),

            // CTA 1: Coral "Quero importar um produto"
            _PrimaryActionBanner(
              backgroundColor: TragoColors.coral,
              icon: Icons.search_rounded,
              title: 'Quero importar um produto',
              subtitle: 'Encontre viajantes para trazer o seu pedido',
              shadow: TragoColors.coralGlow,
              onTap: () => widget.onNavigateTab(3), // Encontrar um viajante
            ),
            const SizedBox(height: 12),

            // CTA 2: Navy "Sou viajante"
            _PrimaryActionBanner(
              backgroundColor: TragoColors.navy,
              icon: Icons.airplanemode_active_rounded,
              title: 'Sou viajante',
              subtitle: 'Monetize o espaço da sua bagagem',
              onTap: () => _openPublishSheet(context),
            ),
            const SizedBox(height: 22),

            // 3 Pilares de Valor do Design.png
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ValuePropBadge(
                    icon: Icons.attach_money_rounded,
                    title: 'Até 60%',
                    subtitle: 'de economia',
                  ),
                ),
                Expanded(
                  child: _ValuePropBadge(
                    icon: Icons.bolt_rounded,
                    title: 'Mais rápido',
                    subtitle: 'que o frete tradicional',
                  ),
                ),
                Expanded(
                  child: _ValuePropBadge(
                    icon: Icons.verified_user_outlined,
                    title: 'Simulação',
                    subtitle: 'sem pagamento real',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Catálogo de Produtos em Destaque
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Catálogo Global em Destaque',
                        style: TextStyle(
                          color: TragoColors.navy,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Escolha um produto para simular impostos e frete',
                        style: TextStyle(
                          color: TragoColors.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigateTab(2),
                  child: const Text(
                    'Criar próprio',
                    style: TextStyle(
                      color: TragoColors.coral,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Chips de Categoria
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kCatalogCategories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = kCatalogCategories[index];
                  final selected = cat == _selectedCategory;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    selectedColor: TragoColors.navy,
                    backgroundColor: TragoColors.surfaceLight,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : TragoColors.navy,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: selected
                            ? TragoColors.navy
                            : TragoColors.borderGray,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Carrossel Horizontal do Catálogo
            SizedBox(
              height: 315,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = _filteredProducts[index];
                  return CatalogProductCard(
                    product: product,
                    onImportTap: () {
                      state.selectCatalogProduct(product);
                      widget.onNavigateTab(
                        2,
                      ); // Vai direto para Detalhes do Pedido
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionBanner extends StatelessWidget {
  final Color backgroundColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<BoxShadow>? shadow;
  final VoidCallback onTap;

  const _PrimaryActionBanner({
    required this.backgroundColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.shadow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: shadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 12.8,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ValuePropBadge extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ValuePropBadge({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: TragoColors.skyLight,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: TragoColors.verifiedBlue, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: TragoColors.navy,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: TragoColors.muted,
            fontSize: 11.5,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;

  const _NotificationTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: TragoColors.navy,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: TragoColors.muted,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: const TextStyle(color: TragoColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}
