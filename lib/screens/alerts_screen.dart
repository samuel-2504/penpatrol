import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/alerts_provider.dart';
import '../models/alert.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/title_bar.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch initial database alerts after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlertsProvider>().fetchAlerts();
    });
  }

  String _formatTs(DateTime dt) {
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$mo-$d  $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertsProvider>();
    final alerts = provider.alerts;
    final pad = Responsive.pagePadding(context);
    final muted = context.extras.muted;

    return Scaffold(
      appBar: TitleBar(
        screenName: 'Alerts',
        showNotifications: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ResponsiveScaffoldBody(
        child: RefreshIndicator(
          onRefresh: provider.fetchAlerts,
          color: AppColors.teal,
          child: Column(
            children: [
              if (alerts.isNotEmpty && !provider.isLoading)
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, pad, pad, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${alerts.length} active',
                        style: TextStyle(
                            color: muted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                      TextButton.icon(
                        onPressed: provider.clearAll,
                        icon: const Icon(Icons.clear_all_rounded,
                            size: 18, color: AppColors.orange),
                        label: const Text('Clear All',
                            style: TextStyle(color: AppColors.orange)),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _buildContent(provider, alerts, pad, muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AlertsProvider provider, List<Alert> alerts, double pad, Color muted) {
    // 1. Loading State
    if (provider.isLoading && alerts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.teal),
      );
    }

    // 2. Error State
    if (provider.errorMessage != null && alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage!,
              style: TextStyle(color: muted, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: provider.fetchAlerts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // 3. Empty State
    if (alerts.isEmpty) {
      return ListView(
        shrinkWrap: true,
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.teal, size: 56),
                const SizedBox(height: 14),
                Text('No active alerts',
                    style: TextStyle(
                        color: muted,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      );
    }

    // 4. Data List
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(pad, 8, pad, pad),
      itemCount: alerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final a = alerts[i];
        return Dismissible(
          key: ValueKey(a.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => provider.dismiss(a.id),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.delete_rounded, color: AppColors.red),
          ),
          child: _AlertCard(
            alert: a,
            formattedTime: _formatTs(a.timestamp),
            onDismiss: () => provider.dismiss(a.id),
          ),
        );
      },
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Alert alert;
  final String formattedTime;
  final VoidCallback onDismiss;

  const _AlertCard({
    required this.alert,
    required this.formattedTime,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.severityColor(alert.severity.name);
    final muted = context.extras.muted;
    final border = context.extras.border;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.extras.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      alert.severity == AlertSeverity.critical
                          ? Icons.error_rounded
                          : Icons.warning_amber_rounded,
                      color: color,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        alert.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                if (alert.subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(alert.subtitle,
                   style: TextStyle(color: muted, fontSize: 12.5)),
                ],
                const SizedBox(height: 6),
                Text(formattedTime,
                    style: TextStyle(
                        color: muted, fontSize: 11, fontFamily: 'monospace')),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: muted, size: 18),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}