import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';

// ================================================================
// ÉVOLUTION DES PRIX D'UN ARTICLE DANS LE TEMPS (par magasin)
// ================================================================
class HistoriquePrixScreen extends ConsumerStatefulWidget {
  final Article article;
  const HistoriquePrixScreen({super.key, required this.article});

  @override
  ConsumerState<HistoriquePrixScreen> createState() =>
      _HistoriquePrixScreenState();
}

class _HistoriquePrixScreenState extends ConsumerState<HistoriquePrixScreen> {
  List<PrixHistorique>? _historique;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final h = await ref
        .read(dbServiceProvider)
        .getHistoriquePrix(widget.article.id);
    if (mounted) setState(() => _historique = h);
  }

  @override
  Widget build(BuildContext context) {
    final historique = _historique;

    return Scaffold(
      appBar: AppBar(title: Text('Évolution — ${widget.article.nom}')),
      body: historique == null
          ? const Center(child: CircularProgressIndicator())
          : historique.length < 2
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      "Pas encore assez de prix enregistrés pour tracer une "
                      'évolution. Reviens après avoir mis à jour ce prix '
                      'quelques fois.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _buildGraphique(historique),
    );
  }

  Widget _buildGraphique(List<PrixHistorique> historique) {
    // Un tracé par magasin (les prix "génériques" comptent comme un magasin
    // à part, nommé ci-dessous).
    final parMagasin = <String, List<PrixHistorique>>{};
    for (final h in historique) {
      (parMagasin[h.magasin] ??= []).add(h);
    }

    final debut = historique.first.date;
    double xDe(DateTime d) => d.difference(debut).inHours / 24.0;

    final couleurs = Theme.of(context).colorScheme;
    final palette = [
      couleurs.primary,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];

    final series = parMagasin.entries.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (var i = 0; i < series.length; i++)
                Chip(
                  avatar: CircleAvatar(
                      backgroundColor: palette[i % palette.length]),
                  label: Text(series[i].key.isEmpty
                      ? 'Prix générique'
                      : series[i].key),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) =>
                          Text('${value.toStringAsFixed(2)} €',
                              style: const TextStyle(fontSize: 10)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final date = debut.add(Duration(hours: (value * 24).round()));
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${date.day}/${date.month}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  for (var i = 0; i < series.length; i++)
                    LineChartBarData(
                      spots: series[i]
                          .value
                          .map((h) => FlSpot(xDe(h.date), h.prix))
                          .toList(),
                      isCurved: false,
                      color: palette[i % palette.length],
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
