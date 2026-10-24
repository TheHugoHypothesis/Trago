import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/public_integrations_service.dart';
import '../models/catalog_product.dart';
import '../models/purchase_request.dart';
import '../state/app_state.dart';
import '../theme/trago_theme.dart';

class DraftScreen extends StatefulWidget {
  final ValueChanged<int> onNavigateTab;

  const DraftScreen({super.key, required this.onNavigateTab});

  @override
  State<DraftScreen> createState() => _DraftScreenState();
}

class _DraftScreenState extends State<DraftScreen> {
  int _activeStep = 1; // 1: Pedido, 2: Cálculo Fiscal, 3: Pagamento, 4: Acompanhamento
  String _productTitle = 'Fone de ouvido sem fio (Exemplo)';
  String _productUrl = 'https://www.amazon.com/dp/B09XS7JWHH';
  int _priceUsd = 300;
  double _weightKg = 0.8;
  String _selectedCategory = 'Eletrônicos';
  IconData _productIcon = Icons.headphones_rounded;
  String _productImageAsset = 'assets/images/products/sony_xm5.jpg';
  String? _lastSyncedProductId;
  bool _isSubmitting = false;

  static const List<String> _categories = [
    'Eletrônicos',
    'Áudio',
    'Games',
    'Fotografia',
    'Moda & Luxo',
    'Peças & PME',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final selectedProduct = Provider.of<AppState>(context).selectedCatalogProduct;
    if (_lastSyncedProductId != selectedProduct.id) {
      _lastSyncedProductId = selectedProduct.id;
      _productTitle = selectedProduct.name;
      _productUrl = selectedProduct.storeUrl;
      _priceUsd = selectedProduct.priceUsd;
      _weightKg = selectedProduct.weightKg;
      _productIcon = selectedProduct.icon;
      _productImageAsset = selectedProduct.imageAsset;
      if (_categories.contains(selectedProduct.category)) {
        _selectedCategory = selectedProduct.category;
      }
    }
  }

  Future<void> _openStoreLink() async {
    final uri = Uri.tryParse(_productUrl);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  void _openEditProductDialog(BuildContext context, AppState state) {
    final titleCtrl = TextEditingController(text: _productTitle);
    final urlCtrl = TextEditingController(text: _productUrl);
    final priceCtrl = TextEditingController(text: _priceUsd.toString());
    final weightCtrl = TextEditingController(text: _weightKg.toStringAsFixed(1));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TragoColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          22,
          22,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personalizar ou trocar produto',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: TragoColors.navy,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Escolha um item do catálogo rápido ou edite os dados abaixo:',
                style: TextStyle(fontSize: 13, color: TragoColors.muted),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kCuratedCatalog.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, idx) {
                    final item = kCuratedCatalog[idx];
                    return ActionChip(
                      avatar: Icon(item.icon, size: 16, color: TragoColors.navy),
                      label: Text(
                        item.brand,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: TragoColors.navy,
                        ),
                      ),
                      backgroundColor: TragoColors.skyLight,
                      onPressed: () {
                        state.selectCatalogProduct(item);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Nome do produto'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(labelText: 'Link da loja no exterior'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Valor (US\$)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Peso (kg)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      if (titleCtrl.text.trim().isNotEmpty) {
                        _productTitle = titleCtrl.text.trim();
                      }
                      _productUrl = urlCtrl.text.trim();
                      _priceUsd = (int.tryParse(priceCtrl.text.trim()) ?? _priceUsd)
                          .clamp(10, 20000);
                      _weightKg = (double.tryParse(
                                    weightCtrl.text.trim().replaceAll(',', '.'),
                                  ) ??
                                  _weightKg)
                              .clamp(0.1, 20.0);
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Atualizar cálculo fiscal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPaymentSheet(BuildContext context, AppState state, TaxBreakdown tax) {
    setState(() => _activeStep = 3);
    final pixPayload =
        '00020126580014BR.GOV.BCB.PIX0136trago-escrow-${state.selectedTrip.id}5204000053039865407${tax.totalBrl}.005802BR5913TRAGO GLOBAL6009SAO PAULO62070503***6304ABCD';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TragoColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Confirmar Importação Segura',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: TragoColors.navy,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: TragoColors.mintLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Custódia Protegida',
                      style: TextStyle(
                        color: TragoColors.mint,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'O viajante ${state.selectedTrip.cleanTravelerName} só recebe o repasse após você confirmar o recebimento do produto em ${state.selectedTrip.destination}.',
                style: const TextStyle(color: TragoColors.muted, fontSize: 13.5),
              ),
              const SizedBox(height: 16),

              // QR Code PIX Gerado via qr_flutter (pub.dev)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: TragoColors.borderGray),
                    boxShadow: TragoColors.softShadow,
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: pixPayload,
                        version: QrVersions.auto,
                        size: 145,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: TragoColors.navy,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: TragoColors.navy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'QR Code PIX com Custódia Trago!',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: TragoColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TragoColors.skyLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TragoColors.skyBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total final garantido (com impostos)',
                            style: TextStyle(
                              color: TragoColors.navy,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'US\$ ${tax.totalUsd} (≈ R\$ ${tax.totalBrl})',
                            style: const TextStyle(
                              color: TragoColors.navy,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.verified_user_rounded,
                      color: TragoColors.verifiedBlue,
                      size: 32,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: Text(
                    _isSubmitting ? 'Confirmando pedido…' : 'Confirmar e Reservar Espaço',
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);
                          setState(() => _isSubmitting = true);
                          await state.createOrder(
                            description: _productTitle,
                            url: _productUrl,
                            priceUsd: _priceUsd,
                            weightGrams: (_weightKg * 1000).round(),
                          );
                          if (!mounted) return;
                          setState(() {
                            _isSubmitting = false;
                            _activeStep = 4;
                          });
                          nav.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Pedido confirmado com cálculo fiscal garantido!',
                              ),
                              backgroundColor: TragoColors.mint,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          widget.onNavigateTab(1); // Vai para a aba Pedidos
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final trip = state.selectedTrip;
    final fxRate = state.marketData.usdToBrl;
    final distanceKm = PublicIntegrationsService.calculateDistanceKm(
      trip.origin,
      trip.destination,
    );
    final tax = TaxBreakdown.calculate(
      productUsd: _priceUsd.toDouble(),
      weightKg: _weightKg,
      pricePerKgUsd: trip.pricePerKgUsdInt.clamp(35, 45),
      exchangeRateBrl: fxRate,
    );

    return Scaffold(
      backgroundColor: TragoColors.background,
      appBar: AppBar(
        backgroundColor: TragoColors.paper,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 30, color: TragoColors.navy),
          onPressed: () => widget.onNavigateTab(0),
        ),
        title: const Text('Detalhes do pedido'),
        actions: [
          IconButton(
            tooltip: 'Compartilhar simulação fiscal',
            icon: const Icon(Icons.share_outlined, color: TragoColors.navy),
            onPressed: () {
              SharePlus.instance.share(
                ShareParams(
                  text:
                      'Simulação Trago!: $_productTitle por US\$ ${tax.totalUsd} (≈ R\$ ${tax.totalBrl}) com impostos inclusos via ${trip.cleanTravelerName} (${trip.origin} → ${trip.destination}).',
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        children: [
          // Stepper de 4 etapas idêntico ao Design.png
          _OrderStepper(
            activeStep: _activeStep,
            onStepTap: (step) => setState(() => _activeStep = step),
          ),
          const SizedBox(height: 20),

          // Card do Produto com Foto Real (idêntico à tela 3 do Design.png)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: TragoColors.paper,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: TragoColors.borderGray),
              boxShadow: TragoColors.softShadow,
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Foto Real do Produto em moldura arredondada
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 78,
                        height: 78,
                        child: Image.asset(
                          _productImageAsset,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: const Color(0xFFF1F5F9),
                            child: Icon(
                              _productIcon,
                              size: 42,
                              color: TragoColors.navy,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _productTitle,
                            style: const TextStyle(
                              color: TragoColors.navy,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              height: 1.22,
                            ),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _openStoreLink,
                            child: Text(
                              _productUrl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: TragoColors.verifiedBlue,
                                fontSize: 13,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _openEditProductDialog(context, state),
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: TragoColors.verifiedBlue,
                        size: 21,
                      ),
                      tooltip: 'Editar produto',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: TragoColors.borderGray),
                const SizedBox(height: 14),

                // Valor do produto (USD)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Valor do produto (USD)',
                        style: TextStyle(
                          color: TragoColors.slate,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _openEditProductDialog(context, state),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          'US\$ $_priceUsd',
                          style: const TextStyle(
                            color: TragoColors.navy,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Peso estimado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Peso estimado',
                        style: TextStyle(
                          color: TragoColors.slate,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _openEditProductDialog(context, state),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 128,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: TragoColors.paper,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: TragoColors.borderGray),
                        ),
                        child: Text(
                          '${_weightKg.toStringAsFixed(1).replaceAll('.', ',')} kg',
                          style: const TextStyle(
                            color: TragoColors.navy,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Categoria
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Categoria',
                        style: TextStyle(
                          color: TragoColors.slate,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      width: 148,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: TragoColors.paper,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TragoColors.borderGray),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: TragoColors.navy,
                          ),
                          items: _categories
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    style: const TextStyle(
                                      color: TragoColors.navy,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Card Azul Claro: Cálculo estimado de valores (idêntico ao Design.png)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: TragoColors.skyLight,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: TragoColors.skyBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Cálculo estimado de valores',
                        style: TextStyle(
                          color: TragoColors.navy,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.info_outline_rounded,
                      color: TragoColors.verifiedBlue,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Rota aérea: $distanceKm km • Câmbio comercial: R\$ ${fxRate.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(
                    color: TragoColors.verifiedBlue,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),

                _CostLineItem(
                  icon: Icons.inventory_2_outlined,
                  title: 'Produto + Frete com viajante',
                  subtitle: '(US\$ ${tax.productUsd} + US\$ ${tax.travelerFeeUsd} com ${trip.cleanTravelerName})',
                  amountText: 'US\$ ${tax.productPlusFreightUsd}',
                ),
                const SizedBox(height: 14),

                _CostLineItem(
                  icon: Icons.description_outlined,
                  title: 'Tributos de importação (estimado)',
                  subtitle: '(Impostos e taxas alfandegárias)',
                  amountText: 'US\$ ${tax.importTaxUsd}',
                ),
                const SizedBox(height: 14),

                _CostLineItem(
                  icon: Icons.monetization_on_outlined,
                  title: 'Taxa de serviço Trago!',
                  subtitle: '(6% sobre o valor total)',
                  amountText: 'US\$ ${tax.serviceFeeUsd}',
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: TragoColors.skyBorder),
                const SizedBox(height: 14),

                // Total estimado
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Flexible(
                      child: Text(
                        'Total estimado',
                        style: TextStyle(
                          color: TragoColors.navy,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: TragoColors.verifiedBlue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'US\$ ${tax.totalUsd}',
                          style: const TextStyle(
                            color: TragoColors.navy,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '≈ R\$ ${tax.totalBrl}',
                          style: const TextStyle(
                            color: TragoColors.verifiedBlue,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Banner Verde "Sem surpresas!" idêntico ao Design.png
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TragoColors.mintLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: TragoColors.mintBorder),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  color: TragoColors.mint,
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sem surpresas!',
                        style: TextStyle(
                          color: TragoColors.navy,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'O cálculo fiscal é feito antecipadamente, garantindo previsibilidade e conformidade aduaneira.',
                        style: TextStyle(
                          color: TragoColors.slate,
                          fontSize: 12.8,
                          height: 1.32,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Botão Coral "Avançar para o pagamento →"
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: TragoColors.coral,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: () => _openPaymentSheet(context, state, tax),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Avançar para o pagamento',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 22),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStepper extends StatelessWidget {
  final int activeStep;
  final ValueChanged<int> onStepTap;

  const _OrderStepper({
    required this.activeStep,
    required this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    const steps = [
      {'num': 1, 'label': 'Pedido'},
      {'num': 2, 'label': 'Cálculo Fiscal'},
      {'num': 3, 'label': 'Pagamento'},
      {'num': 4, 'label': 'Acompanhamento'},
    ];

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          return Expanded(
            child: Container(
              height: 1.5,
              margin: const EdgeInsets.only(bottom: 18),
              color: TragoColors.borderGray,
            ),
          );
        }
        final item = steps[index ~/ 2];
        final num = item['num'] as int;
        final label = item['label'] as String;
        final isActive = num <= activeStep;

        return GestureDetector(
          onTap: () => onStepTap(num),
          child: Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isActive ? TragoColors.verifiedBlue : const Color(0xFFD0D5DD),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$num',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? TragoColors.navy : TragoColors.muted,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _CostLineItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String amountText;

  const _CostLineItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amountText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            icon,
            color: TragoColors.verifiedBlue,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: TragoColors.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: TragoColors.muted,
                  fontSize: 12.2,
                ),
              ),
            ],
          ),
        ),
        Text(
          amountText,
          style: const TextStyle(
            color: TragoColors.navy,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
