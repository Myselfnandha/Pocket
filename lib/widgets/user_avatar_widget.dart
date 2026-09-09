import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

class AvatarItem {
  final String id;
  final String label;
  final String assetPath;

  const AvatarItem({
    required this.id,
    required this.label,
    required this.assetPath,
  });
}

const Map<String, String> kLegacyAvatarMap = {
  'cyber_hacker': 'quantum_flow',
  'wealth_architect': 'solar_wealth',
  'neon_nomad': 'emerald_growth',
  'crypto_vault': 'cosmic_vault',
};

const List<AvatarItem> kAvatarGallery = [
  AvatarItem(
    id: 'solar_wealth',
    label: 'Solar Wealth',
    assetPath: 'assets/avatars/solar_wealth.svg',
  ),
  AvatarItem(
    id: 'emerald_growth',
    label: 'Emerald Growth',
    assetPath: 'assets/avatars/emerald_growth.svg',
  ),
  AvatarItem(
    id: 'quantum_flow',
    label: 'Quantum Flow',
    assetPath: 'assets/avatars/quantum_flow.svg',
  ),
  AvatarItem(
    id: 'cosmic_vault',
    label: 'Cosmic Vault',
    assetPath: 'assets/avatars/cosmic_vault.svg',
  ),
];

class UserAvatarWidget extends StatelessWidget {
  final String avatarId;
  final double size;
  final Color? glowColor;
  final String? fallbackInitial;

  const UserAvatarWidget({
    super.key,
    required this.avatarId,
    this.size = 40,
    this.glowColor,
    this.fallbackInitial,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGlow = glowColor ?? AppColors.primaryGreenLight;
    final resolvedId = kLegacyAvatarMap[avatarId] ?? avatarId;
    final item = kAvatarGallery.firstWhere(
      (a) => a.id == resolvedId,
      orElse: () => kAvatarGallery.first,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: effectiveGlow.withValues(alpha: 0.65),
          width: size > 48 ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: effectiveGlow.withValues(alpha: 0.35),
            blurRadius: size > 48 ? 14 : 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: SvgPicture.asset(
          item.assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholderBuilder: (ctx) => _fallbackLetter(effectiveGlow),
        ),
      ),
    );
  }

  Widget _fallbackLetter(Color color) {
    final letter = (fallbackInitial != null && fallbackInitial!.isNotEmpty)
        ? fallbackInitial![0].toUpperCase()
        : 'N';

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: const Color(0xFF1E1E1E),
      child: Text(
        letter,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.45,
        ),
      ),
    );
  }
}
