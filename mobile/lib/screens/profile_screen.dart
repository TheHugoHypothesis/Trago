import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/trago_api_client.dart';
import '../state/app_state.dart';
import '../theme/trago_theme.dart';
import 'publish_screen.dart';
import 'my_trips_screen.dart';

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

  Future<String?> _prompt(
    BuildContext context, {
    required String title,
    required String label,
    TextInputType? keyboardType,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _createOrganization(BuildContext context, AppState state) async {
    final name = await _prompt(
      context,
      title: 'Nova conta empresarial',
      label: 'Nome da empresa',
    );
    if (name == null || !context.mounted) return;
    try {
      await state.createOrganizationAccount(name);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta empresarial criada e selecionada.'),
          ),
        );
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _addMember(BuildContext context, AppState state) async {
    final email = await _prompt(
      context,
      title: 'Autorizar membro',
      label: 'Email do usuário cadastrado',
      keyboardType: TextInputType.emailAddress,
    );
    if (email == null || !context.mounted) return;
    try {
      await state.addMemberToSelectedOrganization(email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acesso empresarial autorizado.')),
        );
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final current = state.selectedAccount;
    final user = state.authUser;

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
                    state.isDemoMode
                        ? (current?.isOrganization == true ? 'PJ' : 'PF')
                        : (user?.displayName.trim().isNotEmpty == true
                              ? user!.displayName.trim()[0].toUpperCase()
                              : 'U'),
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
                              state.isDemoMode
                                  ? current?.displayName ??
                                        'Conta de demonstração'
                                  : user?.displayName ?? 'Usuário autenticado',
                              style: const TextStyle(
                                color: TragoColors.navy,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.isDemoMode
                            ? (current?.taxId != null
                                  ? 'CNPJ: ${current!.taxId}'
                                  : 'Conta de demonstração; identidade não verificada')
                            : user?.email ?? 'Sessão autenticada',
                        style: const TextStyle(
                          color: TragoColors.muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: TragoColors.mintLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Sem verificação documental',
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
          Text(
            state.accounts.isEmpty
                ? 'Conta de compras'
                : 'Alternar modalidade de importação',
            style: TextStyle(
              color: TragoColors.navy,
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.accounts.isEmpty
                ? 'Não foi possível carregar uma conta vinculada à sua sessão.'
                : 'Mantenha suas compras pessoais separadas das importações da sua empresa.',
            style: TextStyle(color: TragoColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),

          ...state.accounts.map((acc) {
            final isSelected = acc.id == current?.id;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isSelected ? TragoColors.skyLight : TragoColors.paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? TragoColors.verifiedBlue
                      : TragoColors.borderGray,
                  width: isSelected ? 1.6 : 1.0,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  onTap: () => state.selectAccount(acc.id),
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? TragoColors.navy
                        : TragoColors.surfaceLight,
                    child: Icon(
                      acc.isOrganization
                          ? Icons.business_rounded
                          : Icons.person_outline_rounded,
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
                        ? (acc.accessRole == 'OWNER'
                              ? 'Conta empresarial • titular'
                              : 'Conta empresarial • acesso autorizado')
                        : 'Compras internacionais para uso pessoal',
                    style: const TextStyle(
                      color: TragoColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: TragoColors.verifiedBlue,
                        )
                      : const Icon(
                          Icons.chevron_right_rounded,
                          color: TragoColors.muted,
                        ),
                ),
              ),
            );
          }),

          if (!state.isDemoMode) ...[
            OutlinedButton.icon(
              onPressed: () => _createOrganization(context, state),
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Criar conta empresarial'),
            ),
            if (current?.canManageMembers == true) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _addMember(context, state),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Autorizar membro por email'),
              ),
            ],
          ],

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
                Text(
                  state.isDemoMode
                      ? 'Publique uma viagem de demonstração. Identidade, encomendas e documentação fiscal não são verificadas.'
                      : 'Publique com seu usuário autenticado. A conta PF/PJ selecionada é usada apenas nas compras.',
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
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MyTripsScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.list_alt_rounded),
                    label: const Text('Minhas viagens'),
                  ),
                ),
              ],
            ),
          ),
          if (!state.isDemoMode) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: state.authBusy ? null : state.logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sair da conta'),
            ),
          ],
        ],
      ),
    );
  }
}
