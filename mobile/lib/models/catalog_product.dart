import 'package:flutter/material.dart';

class CatalogProduct {
  final String id;
  final String name;
  final String brand;
  final String category;
  final String originCity;
  final String originFlag;
  final String storeName;
  final String storeUrl;
  final int priceUsd;
  final int weightGrams;
  final int brazilRetailBrl;
  final IconData icon;
  final Color accentColor;
  final String highlightBadge;
  final String shortSpecs;
  final String imageAsset;
  final String imageUrl;

  const CatalogProduct({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.originCity,
    required this.originFlag,
    required this.storeName,
    required this.storeUrl,
    required this.priceUsd,
    required this.weightGrams,
    required this.brazilRetailBrl,
    required this.icon,
    required this.accentColor,
    required this.highlightBadge,
    required this.shortSpecs,
    required this.imageAsset,
    required this.imageUrl,
  });

  double get weightKg => weightGrams / 1000.0;

  String get formattedWeight =>
      '${weightKg.toStringAsFixed(1).replaceAll('.', ',')} kg';

  /// Estimativa aproximada de economia comparada ao varejo tradicional no Brasil
  int get savingsPercentage {
    final estimatedTotalBrl = priceUsd * 1.48 * 5.0; // produto + frete + taxas
    if (brazilRetailBrl <= estimatedTotalBrl) return 25;
    final pct = ((brazilRetailBrl - estimatedTotalBrl) / brazilRetailBrl * 100).round();
    return pct.clamp(18, 60);
  }
}

const List<String> kCatalogCategories = [
  'Todos',
  'Áudio',
  'Eletrônicos',
  'Games',
  'Fotografia',
  'Moda & Luxo',
  'Peças & PME',
];

const List<CatalogProduct> kCuratedCatalog = [
  CatalogProduct(
    id: 'prod-sony-xm5',
    name: 'Fone de ouvido sem fio WH-1000XM5',
    brand: 'Sony',
    category: 'Áudio',
    originCity: 'Nova York (EUA)',
    originFlag: '🇺🇸',
    storeName: 'Amazon US',
    storeUrl: 'https://www.amazon.com/dp/B09XS7JWHH',
    priceUsd: 300,
    weightGrams: 800,
    brazilRetailBrl: 2999,
    icon: Icons.headphones_rounded,
    accentColor: Color(0xFF3B82F6),
    highlightBadge: 'Mais pedido',
    shortSpecs: 'Cancelamento de ruído ativo • 30h bateria • Case incluso',
    imageAsset: 'assets/images/products/sony_xm5.jpg',
    imageUrl: 'https://images.unsplash.com/photo-1618366712010-f4ae9c647dcb?auto=format&fit=crop&w=600&q=80',
  ),
  CatalogProduct(
    id: 'prod-macbook-air-m3',
    name: 'MacBook Air 13" Chip M3 (16GB / 512GB)',
    brand: 'Apple',
    category: 'Eletrônicos',
    originCity: 'Nova York (EUA)',
    originFlag: '🇺🇸',
    storeName: 'Apple Fifth Avenue',
    storeUrl: 'https://www.apple.com/macbook-air/',
    priceUsd: 1099,
    weightGrams: 1600,
    brazilRetailBrl: 12499,
    icon: Icons.laptop_mac_rounded,
    accentColor: Color(0xFF0F172A),
    highlightBadge: 'Até 42% off',
    shortSpecs: 'Tela Liquid Retina 13.6" • M3 8-Core • MagSafe 3',
    imageAsset: 'assets/images/products/macbook_air.jpg',
    imageUrl: 'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?auto=format&fit=crop&w=600&q=80',
  ),
  CatalogProduct(
    id: 'prod-ps5-pro',
    name: 'PlayStation 5 Pro 2TB Digital Edition',
    brand: 'Sony Interactive',
    category: 'Games',
    originCity: 'Miami (EUA)',
    originFlag: '🇺🇸',
    storeName: 'Best Buy Miami',
    storeUrl: 'https://www.bestbuy.com/site/playstation-5-pro',
    priceUsd: 699,
    weightGrams: 3200,
    brazilRetailBrl: 6999,
    icon: Icons.sports_esports_rounded,
    accentColor: Color(0xFF4F46E5),
    highlightBadge: 'Lançamento',
    shortSpecs: 'GPU Ray Tracing avançado • PSSR AI Upscaling • 2TB SSD',
    imageAsset: 'assets/images/products/ps5_pro.jpg',
    imageUrl: 'https://images.unsplash.com/photo-1606144042614-b2417e99c4e3?auto=format&fit=crop&w=600&q=80',
  ),
  CatalogProduct(
    id: 'prod-fujifilm-x100vi',
    name: 'Câmera Digital Fujifilm X100VI Silver',
    brand: 'Fujifilm',
    category: 'Fotografia',
    originCity: 'Tóquio (Japão)',
    originFlag: '🇯🇵',
    storeName: 'BicCamera Shinjuku',
    storeUrl: 'https://www.biccamera.com/bc/item/fujifilm-x100vi',
    priceUsd: 1599,
    weightGrams: 900,
    brazilRetailBrl: 16800,
    icon: Icons.camera_alt_rounded,
    accentColor: Color(0xFF0E9F6E),
    highlightBadge: 'Direto do Japão',
    shortSpecs: 'Sensor 40.2MP X-Trans CMOS 5 HR • IBIS 6.0 stops • 23mmF2',
    imageAsset: 'assets/images/products/fujifilm_x100vi.jpg',
    imageUrl: 'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?auto=format&fit=crop&w=600&q=80',
  ),
  CatalogProduct(
    id: 'prod-ipad-pro-m4',
    name: 'iPad Pro 11" OLED Chip M4 Wi-Fi 256GB',
    brand: 'Apple',
    category: 'Eletrônicos',
    originCity: 'Nova York (EUA)',
    originFlag: '🇺🇸',
    storeName: 'B&H Photo Video',
    storeUrl: 'https://www.bhphotovideo.com/c/product/ipad-pro-m4',
    priceUsd: 999,
    weightGrams: 750,
    brazilRetailBrl: 11299,
    icon: Icons.tablet_mac_rounded,
    accentColor: Color(0xFF2563EB),
    highlightBadge: 'Frete leve',
    shortSpecs: 'Tela Ultra Retina XDR Tandem OLED • Espessura 5.3mm',
    imageAsset: 'assets/images/products/ipad_pro.jpg',
    imageUrl: 'https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?auto=format&fit=crop&w=600&q=80',
  ),
  CatalogProduct(
    id: 'prod-dyson-airwrap',
    name: 'Modelador Dyson Airwrap Multi-Styler Complete',
    brand: 'Dyson',
    category: 'Moda & Luxo',
    originCity: 'Londres (Reino Unido)',
    originFlag: '🇬🇧',
    storeName: 'Harrods London',
    storeUrl: 'https://www.harrods.com/en-gb/shopping/dyson-airwrap',
    priceUsd: 550,
    weightGrams: 1800,
    brazilRetailBrl: 5890,
    icon: Icons.auto_awesome_rounded,
    accentColor: Color(0xFFEC4899),
    highlightBadge: 'Reino Unido',
    shortSpecs: 'Efeito Coanda sem calor extremo • 6 acessórios magnéticos',
    imageAsset: 'assets/images/products/dyson_airwrap.jpg',
    imageUrl: 'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?auto=format&fit=crop&w=600&q=80',
  ),
  CatalogProduct(
    id: 'prod-raspberry-cm5-kit',
    name: 'Kit Prototipagem Industrial Edge AI Jetson Orin Nano',
    brand: 'NVIDIA',
    category: 'Peças & PME',
    originCity: 'Nova York (EUA)',
    originFlag: '🇺🇸',
    storeName: 'DigiKey / Mouser US',
    storeUrl: 'https://www.digikey.com/en/products/jetson-orin-nano',
    priceUsd: 499,
    weightGrams: 650,
    brazilRetailBrl: 5400,
    icon: Icons.memory_rounded,
    accentColor: Color(0xFF059669),
    highlightBadge: 'Ideal para PJ',
    shortSpecs: '40 TOPS AI Performance • Documentação contábil inclusa',
    imageAsset: 'assets/images/products/jetson_orin.jpg',
    imageUrl: 'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=600&q=80',
  ),
];
