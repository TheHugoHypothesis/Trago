import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../api/public_integrations_service.dart';
import '../theme/trago_theme.dart';

bool get _isFlutterTestEnvironment {
  if (kIsWeb) return false;
  try {
    return Platform.environment.containsKey('FLUTTER_TEST');
  } catch (_) {
    return false;
  }
}

class WorldRouteHero extends StatefulWidget {
  final ValueChanged<String>? onCityTap;

  const WorldRouteHero({super.key, this.onCityTap});

  @override
  State<WorldRouteHero> createState() => _WorldRouteHeroState();
}

class _WorldRouteHeroState extends State<WorldRouteHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openFullInteractiveMap(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, _) => _FullInteractiveRouteMapSheet(
          onSelectHub: (hubName) {
            Navigator.pop(ctx);
            widget.onCityTap?.call(hubName);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nyc = PublicIntegrationsService.globalHubs['Nova York (EUA)']!.coordinates;
    final lon = PublicIntegrationsService.globalHubs['Londres (Reino Unido)']!.coordinates;
    final tyo = PublicIntegrationsService.globalHubs['Tóquio (Japão)']!.coordinates;
    final sp = PublicIntegrationsService.globalHubs['São Paulo (SP)']!.coordinates;

    final polylines = [
      Polyline(
        points: PublicIntegrationsService.generateFlightArc(nyc, sp),
        color: TragoColors.navy.withValues(alpha: 0.75),
        strokeWidth: 2.2,
        pattern: const StrokePattern.dotted(),
      ),
      Polyline(
        points: PublicIntegrationsService.generateFlightArc(lon, sp),
        color: TragoColors.verifiedBlue.withValues(alpha: 0.75),
        strokeWidth: 2.2,
        pattern: const StrokePattern.dotted(),
      ),
      Polyline(
        points: PublicIntegrationsService.generateFlightArc(tyo, sp),
        color: TragoColors.coral.withValues(alpha: 0.75),
        strokeWidth: 2.2,
        pattern: const StrokePattern.dotted(),
      ),
    ];

    return Container(
      height: 205,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF2F8FF),
            Color(0xFFDCEEFF),
            Color(0xFFEAF5FE),
          ],
        ),
        border: Border.all(color: const Color(0xFFD5E8FA), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final floatOffset = math.sin(t * math.pi * 2) * 3.5;

            return Stack(
              children: [
                // Camada Real do flutter_map com arcos geodésicos e tiles públicos
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.88,
                    child: FlutterMap(
                      options: const MapOptions(
                        initialCenter: LatLng(16.0, -22.0),
                        initialZoom: 1.35,
                        interactionOptions: InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                        backgroundColor: Color(0xFFEAF5FE),
                      ),
                      children: [
                        if (!_isFlutterTestEnvironment)
                          TileLayer(
                            urlTemplate:
                                'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.trago.mobile',
                          ),
                        PolylineLayer(polylines: polylines),
                      ],
                    ),
                  ),
                ),

                // Silhueta complementar e curvas tracejadas fiéis ao Design.png
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _WorldMapRoutesPainter(progress: t),
                    ),
                  ),
                ),

                // Pill: Nova York
                Positioned(
                  left: 16,
                  top: 38 + floatOffset * 0.6,
                  child: _CityRoutePill(
                    flag: '🇺🇸',
                    city: 'Nova York',
                    onTap: () => widget.onCityTap?.call('Nova York (EUA)'),
                  ),
                ),

                // Pill: Londres
                Positioned(
                  left: 132,
                  top: 18 - floatOffset * 0.5,
                  child: _CityRoutePill(
                    flag: '🇬🇧',
                    city: 'Londres',
                    onTap: () => widget.onCityTap?.call('Londres (Reino Unido)'),
                  ),
                ),

                // Pill: Tóquio
                Positioned(
                  right: 16,
                  top: 44 + floatOffset * 0.7,
                  child: _CityRoutePill(
                    flag: '🇯🇵',
                    city: 'Tóquio',
                    onTap: () => widget.onCityTap?.call('Tóquio (Japão)'),
                  ),
                ),

                // Aviões nas rotas
                Positioned(
                  left: 112,
                  top: 74,
                  child: Transform.rotate(
                    angle: 0.45,
                    child: const Icon(
                      Icons.airplanemode_active_rounded,
                      color: TragoColors.navy,
                      size: 20,
                    ),
                  ),
                ),
                Positioned(
                  right: 88,
                  top: 22,
                  child: Transform.rotate(
                    angle: 0.25,
                    child: const Icon(
                      Icons.airplanemode_active_rounded,
                      color: TragoColors.navy,
                      size: 18,
                    ),
                  ),
                ),

                // Botão para expandir o Mapa Interativo (flutter_map completo)
                Positioned(
                  left: 14,
                  bottom: 12,
                  child: Material(
                    color: TragoColors.navy.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      onTap: () => _openFullInteractiveMap(context),
                      borderRadius: BorderRadius.circular(18),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.map_outlined, color: Colors.white, size: 14),
                            SizedBox(width: 5),
                            Text(
                              'Explorar mapa ao vivo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Pin Coral + Caixa de Encomenda (Destino Brasil)
                Positioned(
                  right: 54,
                  bottom: 12 - floatOffset * 0.4,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: TragoColors.coral,
                              shape: BoxShape.circle,
                              boxShadow: TragoColors.coralGlow,
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          Container(
                            width: 12,
                            height: 4,
                            decoration: BoxDecoration(
                              color: TragoColors.navy.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      const _ParcelBoxIllustration(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FullInteractiveRouteMapSheet extends StatelessWidget {
  final ValueChanged<String> onSelectHub;

  const _FullInteractiveRouteMapSheet({required this.onSelectHub});

  @override
  Widget build(BuildContext context) {
    final hubs = PublicIntegrationsService.globalHubs;
    final sp = hubs['São Paulo (SP)']!;

    final originEntries = [
      'Nova York (EUA)',
      'Miami (EUA)',
      'Londres (Reino Unido)',
      'Tóquio (Japão)',
      'Paris (França)',
    ];

    final polylines = originEntries.map((key) {
      final origin = hubs[key]!;
      return Polyline(
        points: PublicIntegrationsService.generateFlightArc(
          origin.coordinates,
          sp.coordinates,
        ),
        color: TragoColors.coral,
        strokeWidth: 3.0,
      );
    }).toList();

    final markers = <Marker>[
      ...originEntries.map((key) {
        final hub = hubs[key]!;
        return Marker(
          point: hub.coordinates,
          width: 125,
          height: 42,
          child: GestureDetector(
            onTap: () => onSelectHub(key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TragoColors.navy, width: 1.5),
                boxShadow: TragoColors.softShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(hub.flag, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${hub.name} (${hub.code})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: TragoColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
      Marker(
        point: sp.coordinates,
        width: 130,
        height: 46,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: TragoColors.coral,
            borderRadius: BorderRadius.circular(18),
            boxShadow: TragoColors.coralGlow,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  'São Paulo (GRU)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: TragoColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                const Icon(Icons.public_rounded, color: TragoColors.navy),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rotas Globais Ativas (OpenStreetMap)',
                        style: TextStyle(
                          color: TragoColors.navy,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Toque em um aeroporto para filtrar viajantes daquela origem',
                        style: TextStyle(
                          color: TragoColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(12.0, -30.0),
                  initialZoom: 2.1,
                ),
                children: [
                  if (!_isFlutterTestEnvironment)
                    TileLayer(
                      urlTemplate:
                          'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.trago.mobile',
                    ),
                  PolylineLayer(polylines: polylines),
                  MarkerLayer(markers: markers),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CityRoutePill extends StatelessWidget {
  final String flag;
  final String city;
  final VoidCallback? onTap;

  const _CityRoutePill({
    required this.flag,
    required this.city,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 2,
      shadowColor: TragoColors.navy.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(flag, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text(
                city,
                style: const TextStyle(
                  color: TragoColors.navy,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParcelBoxIllustration extends StatelessWidget {
  const _ParcelBoxIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 42,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD99B66), Color(0xFFB57642)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TragoColors.navy, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: TragoColors.navy.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            child: Container(
              width: 8,
              color: const Color(0xFFF3D0A4).withValues(alpha: 0.75),
            ),
          ),
          const Icon(
            Icons.inventory_2_outlined,
            size: 20,
            color: TragoColors.navy,
          ),
        ],
      ),
    );
  }
}

class _WorldMapRoutesPainter extends CustomPainter {
  final double progress;

  _WorldMapRoutesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final continentPaint = Paint()
      ..color = const Color(0xFFC7E2FC).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.04, size.height * 0.15, size.width * 0.28, size.height * 0.45),
      continentPaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.36, size.height * 0.10, size.width * 0.25, size.height * 0.38),
      continentPaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.68, size.height * 0.18, size.width * 0.26, size.height * 0.42),
      continentPaint,
    );

    final nyc = Offset(size.width * 0.18, size.height * 0.62);
    final lon = Offset(size.width * 0.44, size.height * 0.36);
    final tyo = Offset(size.width * 0.82, size.height * 0.48);
    final brazil = Offset(size.width * 0.62, size.height * 0.78);

    _drawDashedCurve(
      canvas,
      nyc,
      Offset(size.width * 0.32, size.height * 0.40),
      lon,
    );
    _drawDashedCurve(
      canvas,
      nyc,
      Offset(size.width * 0.38, size.height * 0.82),
      brazil,
    );
    _drawDashedCurve(
      canvas,
      lon,
      Offset(size.width * 0.55, size.height * 0.56),
      brazil,
    );
    _drawDashedCurve(
      canvas,
      tyo,
      Offset(size.width * 0.74, size.height * 0.72),
      brazil,
    );

    final dotPaint = Paint()..color = TragoColors.navy;
    for (final pt in [nyc, lon, tyo, brazil]) {
      canvas.drawCircle(pt, 4.0, dotPaint);
    }
  }

  void _drawDashedCurve(Canvas canvas, Offset p0, Offset p1, Offset p2) {
    final path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy);

    final paint = Paint()
      ..color = TragoColors.navy.withValues(alpha: 0.7)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final segment = metric.extractPath(distance, distance + 5);
        canvas.drawPath(segment, paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WorldMapRoutesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
