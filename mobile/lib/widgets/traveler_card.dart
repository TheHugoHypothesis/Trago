import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../theme/trago_theme.dart';

class TravelerCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  final bool isSelected;

  const TravelerCard({
    super.key,
    required this.trip,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: TragoColors.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? TragoColors.coral : TragoColors.borderGray,
          width: isSelected ? 1.8 : 1.0,
        ),
        boxShadow: TragoColors.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Viagens de exemplo e identidade sem verificação documental.
                Column(
                  children: [
                    _TravelerAvatar(trip: trip),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: TragoColors.mintLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        trip.isDemo ? 'Exemplo' : 'Não verificado',
                        style: TextStyle(
                          color: TragoColors.mint,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Coluna Central: Nome, avaliação, rota, data e espaço
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              trip.cleanTravelerName,
                              style: const TextStyle(
                                color: TragoColors.navy,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (trip.isDemo)
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: TragoColors.starAmber,
                              size: 17,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                '${trip.rating.toStringAsFixed(1)} (${trip.reviewCount}) • avaliação ilustrativa',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: TragoColors.muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.flight_takeoff_rounded,
                        text: '${trip.origin} → ${trip.destination}',
                      ),
                      const SizedBox(height: 4),
                      _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        text: trip.formattedDatePt,
                      ),
                      const SizedBox(height: 4),
                      _InfoRow(
                        icon: Icons.luggage_outlined,
                        text:
                            'Disponível: ${trip.formattedAvailableWeight} de ${trip.formattedTotalWeight}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Coluna Direita: Preço por kg + Seta
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          trip.formattedPricePerKg,
                          style: const TextStyle(
                            color: TragoColors.navy,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Text(
                          'por kg',
                          style: TextStyle(
                            color: TragoColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 38),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: TragoColors.muted,
                      size: 24,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TravelerAvatar extends StatelessWidget {
  final Trip trip;

  const _TravelerAvatar({required this.trip});

  @override
  Widget build(BuildContext context) {
    final colors = trip.avatarColors;
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          trip.avatarAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              trip.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: TragoColors.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: TragoColors.slate,
              fontSize: 12.8,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
