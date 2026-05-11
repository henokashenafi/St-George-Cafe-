import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/locales/app_localizations.dart';
import 'package:ethiopian_datetime/ethiopian_datetime.dart';

class EthiopianDateDisplay extends StatelessWidget {
  const EthiopianDateDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final now = ETDateTime.now();
    final formatted = ETDateFormat("MMMM d, yyyy").format(now);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month, size: 14, color: Color(0xFFD4AF37)),
          const SizedBox(width: 6),
          Text(
            formatted,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class LanguageSwitcher extends ConsumerWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(languageProvider);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButton<AppLanguage>(
        value: currentLanguage,
        dropdownColor: const Color(0xFF1A1A1A),
        style: const TextStyle(color: Colors.white70, fontSize: 13),
        icon: const Icon(
          Icons.keyboard_arrow_down,
          color: Colors.white54,
          size: 16,
        ),
        underline: const SizedBox(),
        items: [
          DropdownMenuItem(
            value: AppLanguage.en,
            child: Text(
              AppLocalizations.getLanguageDisplayName(AppLanguage.en),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          DropdownMenuItem(
            value: AppLanguage.am,
            child: Text(
              AppLocalizations.getLanguageDisplayName(AppLanguage.am),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
        onChanged: (AppLanguage? language) async {
          if (language != null) {
            await ref.read(languageProvider.notifier).changeLanguage(language);
          }
        },
      ),
    );
  }
}

class CompactLanguageSwitcher extends ConsumerWidget {
  const CompactLanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(languageProvider);

    return PopupMenuButton<AppLanguage>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.zero,
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.getLanguageDisplayName(currentLanguage),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
      color: const Color(0xFF1A1A1A),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: AppLanguage.en,
          child: Text(
            AppLocalizations.getLanguageDisplayName(AppLanguage.en),
            style: TextStyle(
              color: currentLanguage == AppLanguage.en
                  ? const Color(0xFFD4AF37)
                  : Colors.white70,
            ),
          ),
        ),
        PopupMenuItem(
          value: AppLanguage.am,
          child: Text(
            AppLocalizations.getLanguageDisplayName(AppLanguage.am),
            style: TextStyle(
              color: currentLanguage == AppLanguage.am
                  ? const Color(0xFFD4AF37)
                  : Colors.white70,
            ),
          ),
        ),
      ],
      onSelected: (AppLanguage? language) async {
        if (language != null) {
          await ref.read(languageProvider.notifier).changeLanguage(language);
        }
      },
    );
  }
}
