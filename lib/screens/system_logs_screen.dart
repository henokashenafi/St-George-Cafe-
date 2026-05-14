import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/services/system_log_service.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:st_george_pos/locales/app_localizations.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  String _logFilePath = 'Loading...';
  late final Stream<int> _refreshStream;

  @override
  void initState() {
    super.initState();
    _loadFilePath();
    // Auto-refresh logs every 2 seconds while screen is open
    _refreshStream = Stream.periodic(const Duration(seconds: 2), (i) => i);
  }

  Future<void> _loadFilePath() async {
    final path = await SystemLogService.getLogFilePath();
    if (mounted) setState(() => _logFilePath = path);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _refreshStream,
      builder: (context, snapshot) {
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
                  icon: const Icon(Icons.storage, size: 20, color: Colors.orangeAccent),
                  onPressed: () => _confirmDeleteDatabase(context),
                  tooltip: 'Delete Database (DANGEROUS)',
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
      },
    );
  }

  Future<void> _confirmDeleteDatabase(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DELETE DATABASE?'),
        content: const Text(
            'This will WIPE ALL DATA (orders, waiters, products, settings) and close the app. You will need to restart the app manually to create a fresh database.\n\nAre you absolutely sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE EVERYTHING'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        final dbFile = File(p.join(docDir.path, 'st_george_pos.db'));
        if (await dbFile.exists()) {
          await dbFile.delete();
          SystemLogService.log('Database deleted successfully.');
        }
        // Force exit so the user restarts with a clean state
        exit(0);
      } catch (e) {
        SystemLogService.log('Error deleting database: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}
