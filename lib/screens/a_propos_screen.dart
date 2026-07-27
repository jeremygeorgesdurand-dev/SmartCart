import 'package:flutter/material.dart';
import '../services/version_info.dart';

// ================================================================
// ÉCRAN À PROPOS — version, date de mise à jour, historique
// ================================================================
class AProposScreen extends StatelessWidget {
  const AProposScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version actuelle'),
            trailing: Text(
              'v${VersionInfo.version} (build ${VersionInfo.buildNumber})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Dernière mise à jour'),
            trailing: Text(
              VersionInfo.dateMiseAJour,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Historique des versions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog(
              context: context,
              builder: (_) => const _HistoriqueVersionsDialog(),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoriqueVersionsDialog extends StatelessWidget {
  const _HistoriqueVersionsDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Historique des versions',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: VersionInfo.historique.map((release) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'v${release.version}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(release.date,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Theme.of(context).colorScheme.outline)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...release.changements.map((c) => Padding(
                              padding: const EdgeInsets.only(left: 8, bottom: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('• ',
                                      style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary)),
                                  Expanded(
                                      child: Text(c,
                                          style: const TextStyle(fontSize: 13))),
                                ],
                              ),
                            )),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
