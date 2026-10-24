import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/trago_theme.dart';
import 'publish_screen.dart';

class ProfileScreen extends StatelessWidget {
  final ValueChanged<int> onNavigateTab;

  const ProfileScreen({super.key, required this.onNavigateTab});

  void _openPublishModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, _) => Container(
          decoration: const BoxDecoration(
            color: TragoColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: PublishScreen(
            onNavigateTab: (tab) {
              Navigator.of(ctx).pop();
              onNavigateTab(tab);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final current = state.selectedAccount;

    return Scaffold(
      backgroundColor: TragoColors.background,
      appBar: AppBar(
        backgroundColor: TragoColors.paper,
        title: const Text('Meu perfil'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          // Cartão do Usuário
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: TragoColors.paper,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: TragoColors.borderGray),
              boxShadow: TragoColors.softShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [TragoColors.navy, TragoColors.verifiedBlue],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    current.isOrganization ? 'PJ' : 'PF',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              current.displayName,
                              style: const TextStyle(
                                color: TragoColors.navy,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: TragoColors.verifiedBlue,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        current.taxId != null
                            ? 'CNPJ: ${current.taxId}'
                            : 'Comprador e Viajante Verificado',
                        style: const TextStyle(
                          color: TragoColors.muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: TragoColors.mintLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Identidade e Conformidade Ativas',
                          style: TextStyle(
                            color: TragoColors.mint,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Alternar entre Conta Pessoal (PF) e Empresa (PJ)
          const Text(
            'Alternar modalidade de importação',
            style: TextStyle(
              color: TragoColors.navy,
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Mantenha suas compras pessoais separadas das importações da sua empresa.',
            style: TextStyle(color: TragoColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),

          ...state.accounts.map((acc) {
            final isSelected = acc.id == current.id;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isSelected ? TragoColors.skyLight : TragoColors.paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? TragoColors.verifiedBlue : TragoColors.borderGray,
                  width: isSelected ? 1.6 : 1.0,
                ),
              ),
              child: ListTile(
                onTap: () => state.selectAccount(acc.id),
                leading: CircleAvatar(
                  backgroundColor: isSelected ? TragoColors.navy : TragoColors.surfaceLight,
                  child: Icon(
                    acc.isOrganization ? Icons.business_rounded : Icons.person_outline_rounded,
                    color: isSelected ? Colors.white : TragoColors.navy,
                    size: 20,
                  ),
                ),
                title: Text(
                  acc.displayName,
                  style: const TextStyle(
                    color: TragoColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                subtitle: Text(
                  acc.isOrganization
                      ? 'Importação corporativa PME • CNPJ ${acc.taxId ?? ""}'
                      : 'Compras internacionais para uso pessoal',
                  style: const TextStyle(color: TragoColors.muted, fontSize: 12),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: TragoColors.verifiedBlue)
                    : const Icon(Icons.chevron_right_rounded, color: TragoColors.muted),
              ),
            );
          }),

          const SizedBox(height: 20),

          // Modo Viajante Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: TragoColors.navy,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.flight_takeoff_rounded, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'Vai viajar para o exterior?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Rentabilize o espaço livre da sua mala trazendo encomendas verificadas e com documentação fiscal pronta.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _openPublishModal(context),
                    child: const Text('Publicar minha próxima viagem'),
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
