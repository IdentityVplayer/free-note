import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/app_provider.dart';
import 'folder_picker_screen.dart';

/// First-run guide (v1.18.1). Shown once on a fresh install, it explains the
/// three things the user needs to know to get started:
///   1. pick a notes folder,
///   2. long-press the folder button to reveal its full path,
///   3. double-tap the folder button to re-select / edit it.
///
/// Dismissing it (via "选择文件夹" or "稍后") marks the guide as seen, after
/// which [AppProvider.onboardingDone] becomes true and [FreeNoteApp] routes to
/// the folder picker (if no folder is set) or the home screen.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<AppProvider>();

    final steps = [
      (Icons.folder_open, l10n.t('onboardingStep1')),
      (Icons.touch_app, l10n.t('onboardingStep2')),
      (Icons.edit_note, l10n.t('onboardingStep3')),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Icon(
                Icons.note_alt_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.t('onboardingTitle'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.t('onboardingDesc'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: ListView.separated(
                  itemCount: steps.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer,
                      child: Text('${i + 1}'),
                    ),
                    title: Text(steps[i].$2),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(l10n.t('onboardingStart')),
                  onPressed: () async {
                    await provider.markOnboardingDone();
                    if (provider.needsFolderSelection && context.mounted) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FolderPickerScreen(),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => provider.markOnboardingDone(),
                  child: Text(l10n.t('onboardingSkip')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
