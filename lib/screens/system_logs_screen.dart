import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/services/system_log_service.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:st_george_pos/locales/app_localizations.dart';

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  String _logFilePath = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadFilePath();
  }

  Future<void> _loadFilePath() async {
    final path = await SystemLogService.getLogFilePath();
    if (mounted) setState(() => _logFilePath = path);
  }

  @override
  Widget build(BuildContext context) {
    final logs = SystemLogService.logs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SYSTEM DEBUG LOGS',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Log File: $_logFilePath',
                  style: const TextStyle(fontSize: 10, color: Colors.white38),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => setState(() {}),
                  tooltip: 'Refresh Logs',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  onPressed: () {
                    SystemLogService.clear();
                    setState(() {});
                  },
                  tooltip: 'Clear In-Memory Logs',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GlassContainer(
            opacity: 0.05,
            child: logs.isEmpty
                ? const Center(child: Text('No system logs captured yet.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final isError = log.toLowerCase().contains('error') || 
                                     log.toLowerCase().contains('failed') ||
                                     log.toLowerCase().contains('exception');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: isError ? Colors.redAccent : Colors.white70,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
