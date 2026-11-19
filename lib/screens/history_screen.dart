import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/history_provider.dart';
import '../models/history_log.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/title_bar.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'All';

  static const _filters = [
    'All',
    'Swine Bath',
    'Foot Bath',
    'Tunnel',
    'Thermal',
    'System'
  ];

  IconData _iconFor(String category) {
    switch (category) {
      case 'Swine Bath':
      case 'Foot Bath':
      case 'Tunnel':
        return Icons.water_drop_rounded;
      case 'Thermal':
        return Icons.thermostat_rounded;
      case 'System':
      default:
        return Icons.memory_rounded;
    }
  }

  Color _colorFor(String category) {
    switch (category) {
      case 'Swine Bath':
        return AppColors.teal;
      case 'Foot Bath':
        return Colors.lightBlue;
      case 'Tunnel':
        return AppColors.yellow;
      case 'Thermal':
        return AppColors.red;
      case 'System':
      default:
        return AppColors.titleBarBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HistoryProvider>();
    final logs = provider.logs;

    final filtered = _filter == 'All'
        ? logs
        : logs.where((l) => l.category == _filter).toList();

    final pad = Responsive.pagePadding(context);
    final muted = context.extras.muted;

    return Scaffold(
      appBar: const TitleBar(
        screenName: 'Activity History',
      ),
      body: ResponsiveScaffoldBody(
        child: RefreshIndicator(
          onRefresh: provider.fetchLogs,
          color: AppColors.teal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Filter Chips Bar
              Padding(
                padding: EdgeInsets.fromLTRB(pad, pad, pad, 8),
                child: SizedBox(
                  height: 36,
                  child: ListView.separated(
                    primary: false,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final f = _filters[i];
                      final selected = f == _filter;
                      return ChoiceChip(
                        label: Text(f),
                        selected: selected,
                        selectedColor: _colorFor(f).withValues(alpha: 0.25),
                        onSelected: (_) => setState(() => _filter = f),
                      );
                    },
                  ),
                ),
              ),

              // Main List Content Body
              Expanded(
                child: _buildBodyContent(provider, filtered, pad, muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent(
    HistoryProvider provider,
    List<HistoryLog> filtered,
    double pad,
    Color muted,
  ) {
    // 1. Loading State
    if (provider.isLoading && provider.logs.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.teal),
      );
    }

    // 2. Error State
    if (provider.errorMessage != null && provider.logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.red, size: 48),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                provider.errorMessage!,
                style: TextStyle(color: muted, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: provider.fetchLogs,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // 3. Empty State
    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_rounded, size: 48, color: muted),
                const SizedBox(height: 12),
                Text(
                  _filter == 'All'
                      ? 'No activity logs found'
                      : 'No logs in "$_filter"',
                  style: TextStyle(color: muted, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 4. Activity Logs List
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(pad, 8, pad, pad),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final log = filtered[i];
        return _LogTile(
          log: log,
          icon: _iconFor(log.category),
          color: _colorFor(log.category),
        );
      },
    );
  }
}

class _LogTile extends StatelessWidget {
  final HistoryLog log;
  final IconData icon;
  final Color color;

  const _LogTile({
    required this.log,
    required this.icon,
    required this.color,
  });

  String _formatTs(DateTime dt) {
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$mo-$d  $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.extras.muted;
    final border = context.extras.border;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.extras.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  log.description,
                  style: TextStyle(color: muted, fontSize: 12.5),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatTs(log.timestamp),
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}