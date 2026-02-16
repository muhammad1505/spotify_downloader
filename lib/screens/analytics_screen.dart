import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../managers/analytics_manager.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<AnalyticsManager>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalyticsManager>(
      builder: (context, manager, _) {
        final summary = manager.summary;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Text('📊', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 10),
                  Text(
                    'Analytics',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _statCard('Total downloads', summary.totalDownloads.toString()),
              _statCard('Failed downloads', summary.failedDownloads.toString()),
              _statCard('Top artist', summary.topArtist),
              _statCard('Top track', summary.topTrack),
              const SizedBox(height: 16),
              _chartCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(String title, String value) {
    return Card(
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 14)),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _chartCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  color: AppTheme.spotifyGreen,
                  barWidth: 3,
                  spots: const [
                    FlSpot(0, 1),
                    FlSpot(1, 3),
                    FlSpot(2, 2),
                    FlSpot(3, 5),
                    FlSpot(4, 4),
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
