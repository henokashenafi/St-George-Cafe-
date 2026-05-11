import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/providers/pos_providers.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:intl/intl.dart';

class AuditLogsScreen extends ConsumerWidget {
  const AuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(auditLogsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              const Icon(Icons.history, color: Color(0xFFD4AF37), size: 28),
              const SizedBox(width: 12),
              const Text(
                'SYSTEM AUDIT LOGS',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(auditLogsProvider),
              ),
            ],
          ),
        ),
        Expanded(
          child: logsAsync.when(
            data: (logs) => logs.isEmpty
                ? const Center(child: Text('No audit logs found.'))
                : GlassContainer(
                    opacity: 0.05,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final date = DateTime.parse(log['created_at']);
                        return ListTile(
                          leading: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('HH:mm').format(date),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              Text(
                                DateFormat('dd/MM').format(date),
                                style: const TextStyle(color: Colors.white38, fontSize: 10),
                              ),
                            ],
                          ),
                          title: Text(
                            log['action'].toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                          subtitle: log['details'] != null
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    log['details'],
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                )
                              : null,
                          trailing: log['user_id'] != null
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.zero,
                                  ),
                                  child: Text(
                                    'UID: ${log['user_id']}',
                                    style: const TextStyle(fontSize: 10, color: Colors.white38),
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}
