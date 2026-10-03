import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mq_navigation/app/l10n/generated/app_localizations.dart';
import 'package:mq_navigation/app/theme/mq_colors.dart';
import 'package:mq_navigation/app/theme/mq_spacing.dart';
import 'package:mq_navigation/features/safety/data/datasources/safety_poi_source.dart';
import 'package:mq_navigation/features/safety/domain/entities/emergency_contact.dart';
import 'package:mq_navigation/features/safety/domain/entities/safety_poi.dart';
import 'package:mq_navigation/features/safety/presentation/widgets/safety_action_card.dart';
import 'package:mq_navigation/shared/extensions/context_extensions.dart';

class SafetyToolkitPage extends StatefulWidget {
  const SafetyToolkitPage({super.key});

  @override
  State<SafetyToolkitPage> createState() => _SafetyToolkitPageState();
}

class _SafetyToolkitPageState extends State<SafetyToolkitPage> {
  final _source = SafetyPoiSource();
  bool _flashlightOn = false;

  Future<void> _callNumber(String phoneNumber) async {
    final uri = Uri(
      scheme: 'tel',
      path: phoneNumber.replaceAll(RegExp(r'\D'), ''),
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _toggleFlashlight() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      if (mounted) {
        setState(() => _flashlightOn = !_flashlightOn);
      }
    } catch (_) {
      if (mounted) {
        context.showSnackBar(l10n.safetyFlashlightUnavailable);
      }
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(
        left: MqSpacing.space4,
        right: MqSpacing.space4,
        top: MqSpacing.space6,
        bottom: MqSpacing.space3,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: isDark
              ? Colors.white.withValues(alpha: 0.5)
              : MqColors.contentTertiary,
        ),
      ),
    );
  }

  Widget _buildPoiList(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    List<SafetyPoi> pois,
    IconData icon,
  ) {
    if (pois.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: MqSpacing.space4),
        child: Text(
          l10n.safetyNoLocations,
          style: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.4)
                : MqColors.contentTertiary,
          ),
        ),
      );
    }

    return Column(
      children: pois.map((poi) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.space4,
            vertical: MqSpacing.space1,
          ),
          child: Container(
            padding: const EdgeInsets.all(MqSpacing.space3),
            decoration: BoxDecoration(
              color: isDark ? MqColors.charcoal800 : Colors.white,
              borderRadius: BorderRadius.circular(MqSpacing.radiusMd),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : MqColors.charcoal800.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: MqColors.red),
                const SizedBox(width: MqSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        poi.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : MqColors.charcoal900,
                        ),
                      ),
                      if (poi.description != null)
                        Text(
                          '${poi.buildingCode} — ${poi.description}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : MqColors.contentTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmergencyContact(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    EmergencyContact contact,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MqSpacing.space4,
        vertical: MqSpacing.space1,
      ),
      child: SafetyActionCard(
        icon: contact.isEmergency
            ? Icons.warning_amber_rounded
            : Icons.phone_in_talk,
        title: _resolveContactLabel(l10n, contact),
        subtitle: _resolveContactDescription(l10n, contact),
        value: contact.phoneNumber,
        isDestructive: contact.isEmergency,
        onTap: () => _callNumber(contact.phoneNumber),
      ),
    );
  }

  String _resolveContactLabel(AppLocalizations l10n, EmergencyContact contact) {
    if (contact.label.contains('Emergency')) return l10n.safetyEmergencyLabel;
    if (contact.label.contains('Campus Security')) {
      return l10n.safetySecurityLabel;
    }
    if (contact.label.contains('Health Service')) return l10n.safetyHealthLabel;
    if (contact.label.contains('Afterhours Support')) {
      return l10n.safetySupportLabel;
    }
    return contact.label;
  }

  String? _resolveContactDescription(
    AppLocalizations l10n,
    EmergencyContact contact,
  ) {
    if (contact.description == null) return null;
    final d = contact.description!;
    if (d.contains('Life-threatening')) return l10n.safetyEmergencyDesc;
    if (d.contains('24/7 campus security')) return l10n.safetySecurityDesc;
    if (d.contains('Health Service appointments')) return l10n.safetyHealthDesc;
    if (d.contains('1800 CRISIS')) return l10n.safetySupportDesc;
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: isDark ? MqColors.charcoal900 : MqColors.sand100,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          l10n.safetyToolkit,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : MqColors.charcoal900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Privacy notice
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MqSpacing.space4,
                  MqSpacing.space2,
                  MqSpacing.space4,
                  MqSpacing.space4,
                ),
                child: Container(
                  padding: const EdgeInsets.all(MqSpacing.space3),
                  decoration: BoxDecoration(
                    color: MqColors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(MqSpacing.radiusMd),
                    border: Border.all(
                      color: MqColors.red.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.privacy_tip,
                        size: 20,
                        color: MqColors.red,
                      ),
                      const SizedBox(width: MqSpacing.space2),
                      Expanded(
                        child: Text(
                          l10n.safetyPrivacyNote,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: MqColors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Quick Actions
              _buildSectionHeader(context, l10n.safetyQuickActions, isDark),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MqSpacing.space4,
                ),
                child: Column(
                  children: [
                    SafetyActionCard(
                      icon: _flashlightOn
                          ? Icons.flash_on
                          : Icons.flashlight_on,
                      title: _flashlightOn
                          ? l10n.safetyFlashlightOn
                          : l10n.safetyFlashlight,
                      subtitle: l10n.safetyFlashlightDesc,
                      isActive: _flashlightOn,
                      onTap: _toggleFlashlight,
                    ),
                    const SizedBox(height: MqSpacing.space2),
                    SafetyActionCard(
                      icon: Icons.navigation,
                      title: l10n.safetyNavigateToSecurity,
                      subtitle: l10n.safetyNavigateToSecurityDesc,
                      onTap: () {
                        context.showSnackBar(
                          l10n.safetyNavigateToSecurityToast,
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Emergency Contacts
              _buildSectionHeader(
                context,
                l10n.safetyEmergencyContacts,
                isDark,
              ),
              ..._source.emergencyContacts.map(
                (c) => _buildEmergencyContact(context, isDark, l10n, c),
              ),

              // Shuttle Info
              _buildSectionHeader(context, l10n.safetySecurityShuttle, isDark),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MqSpacing.space4,
                ),
                child: SafetyActionCard(
                  icon: Icons.airport_shuttle,
                  title: l10n.safetySecurityShuttle,
                  subtitle: _source.securityShuttleInfo,
                  onTap: () => _callNumber('(02) 9850 7111'),
                ),
              ),

              // First Aid
              _buildSectionHeader(context, l10n.safetyFirstAid, isDark),
              _buildPoiList(
                context,
                isDark,
                l10n,
                _source.firstAidLocations,
                Icons.medical_services,
              ),

              // Defibrillators
              _buildSectionHeader(context, l10n.safetyDefibrillator, isDark),
              _buildPoiList(
                context,
                isDark,
                l10n,
                _source.defibrillatorLocations,
                Icons.favorite_border,
              ),

              const SizedBox(height: MqSpacing.space8),
            ],
          ),
        ),
      ),
    );
  }
}
