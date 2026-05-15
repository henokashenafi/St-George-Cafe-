import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/services/system_log_service.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:st_george_pos/locales/app_localizations.dart';
import 'package:st_george_pos/core/database_helper.dart';
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
                FutureBuilder<int>(
                  future: DatabaseHelper().database.then((db) async {
                    final res = await db.rawQuery('PRAGMA user_version');
                    return res.first.values.first as int;
                  }),
                  builder: (context, snapshot) {
                    return Text(
                      'Database Schema Version: ${snapshot.data ?? "..."}',
                      style: const TextStyle(fontSize: 10, color: Colors.white38),
                    );
                  },
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
    final passwordCtrl = TextEditingController();
    bool isError = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('CLEAR ORDER HISTORY?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will delete ALL sales history, shifts, and reports. Menu items, waiters, and settings will NOT be touched.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              const Text(
                'Enter Security Password:',
                style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: const TextStyle(color: Colors.white24),
                  errorText: isError ? 'Incorrect Password' : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              onPressed: () {
                if (passwordCtrl.text == 'cafe12345678') {
                  Navigator.pop(context, true);
                } else {
                  setState(() => isError = true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: const Text('CLEAR HISTORY'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        final db = await DatabaseHelper().database;
        await db.transaction((txn) async {
          await txn.delete('orders');
          await txn.delete('order_items');
          await txn.delete('shifts');
          await txn.delete('z_reports');
          await txn.delete('audit_logs');
          await txn.update('tables', {'status': 'available'});
        });
        SystemLogService.log('History cleared successfully.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order history cleared successfully.')),
          );
        }
      } catch (e) {
        SystemLogService.log('Error clearing history: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}
