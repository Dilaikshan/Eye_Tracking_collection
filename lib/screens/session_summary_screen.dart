import 'package:eye_tracking_collection/core/constants/app_colors.dart';
import 'package:eye_tracking_collection/models/user_profile.dart';
import 'package:eye_tracking_collection/screens/collection_grid_screen.dart';
import 'package:eye_tracking_collection/services/research_export_service.dart';
import 'package:flutter/material.dart';

class SessionSummaryArgs {
  final String sessionId;
  final UserProfile profile;
  final String languageCode;

  const SessionSummaryArgs({
    required this.sessionId,
    required this.profile,
    required this.languageCode,
  });
}

class SessionSummaryScreen extends StatefulWidget {
  const SessionSummaryScreen({super.key, required this.args});
  static const String routeName = '/session_summary';
  final SessionSummaryArgs args;

  @override
  State<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen> {
  final ResearchExportService _exportService = ResearchExportService();
  Map<String, dynamic>? _stats;
  bool _loading = true;
  bool _exporting = false;
  String? _exportPath;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats =
        await _exportService.getSessionStats(widget.args.sessionId);
    if (mounted) {
      setState(() {
        _stats = stats;
        _loading = false;
      });
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    final path = await _exportService.exportSession(
      sessionId: widget.args.sessionId,
      participantName: widget.args.profile.name,
    );
    if (mounted) {
      setState(() {
        _exporting = false;
        _exportPath = path;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(path != null
              ? '✅ Exported: $path'
              : '❌ Export failed – check logs'),
          backgroundColor: path != null ? Colors.green : Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Session Summary'),
        backgroundColor: AppColors.surface,
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.tealAccent))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final s = _stats ?? {};
    final total    = s['total']    as int?    ?? 0;
    final withCrops= s['withCrops']as int?    ?? 0;
    final avgConf  = s['avgConfidence'] as double? ?? 0.0;
    final avgEAR   = s['avgEAR']   as double? ?? 0.0;
    final blinks   = s['blinkCount']   as int?    ?? 0;
    final phases   = (s['phaseCounts'] as Map<String, dynamic>?) ?? {};

    final cropsPercent = total > 0
        ? ((withCrops / total) * 100).toStringAsFixed(1)
        : '0.0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const Icon(Icons.check_circle_outline,
              color: Colors.tealAccent, size: 64),
          const SizedBox(height: 12),
          Text(
            'Session Complete!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Participant: ${widget.args.profile.name}',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 24),

          // Stats grid
          _statCard('Total Samples', '$total', Icons.dataset),
          _statCard('Samples with Eye Crops',
              '$withCrops / $total  ($cropsPercent%)', Icons.image),
          _statCard('Average Confidence',
              '${(avgConf * 100).toStringAsFixed(1)}%', Icons.verified),
          _statCard('Average EAR',
              avgEAR.toStringAsFixed(3), Icons.visibility),
          _statCard('Blinks Detected', '$blinks', Icons.remove_red_eye),

          const SizedBox(height: 12),

          // Phase breakdown
          Card(
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Phase Breakdown',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const SizedBox(height: 8),
                  ...phases.entries.map((e) => Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text(
                              '${e.key.toUpperCase()}:',
                              style: const TextStyle(
                                  color: Colors.tealAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${e.value} samples',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Export button
          ElevatedButton.icon(
            onPressed: _exporting ? null : _exportCsv,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(_exporting ? 'Exporting…' : 'Export to CSV'),
          ),

          if (_exportPath != null) ...[
            const SizedBox(height: 8),
            Text(
              '✅ Saved: $_exportPath',
              style: const TextStyle(
                  color: Colors.greenAccent, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 12),

          // Navigation buttons
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed(
                CollectionGridScreen.routeName,
                arguments: CollectionGridArgs(
                  profile: widget.args.profile,
                  languageCode: widget.args.languageCode,
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.tealAccent,
              side: const BorderSide(color: Colors.tealAccent),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.replay),
            label: const Text('Start New Session'),
          ),

          const SizedBox(height: 8),

          TextButton(
            onPressed: () =>
                Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Return to Home',
                style: TextStyle(color: Colors.white38)),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading:
            Icon(icon, color: Colors.tealAccent, size: 22),
        title: Text(label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 13)),
        trailing: Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
      ),
    );
  }
}

