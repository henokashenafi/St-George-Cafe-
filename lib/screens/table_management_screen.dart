import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/models/table_model.dart';
import 'package:st_george_pos/models/table_zone.dart';
import 'package:st_george_pos/models/waiter.dart';
import 'package:st_george_pos/providers/pos_providers.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:st_george_pos/locales/app_localizations.dart';

class TableManagementScreen extends ConsumerStatefulWidget {
  const TableManagementScreen({super.key});

  @override
  ConsumerState<TableManagementScreen> createState() =>
      _TableManagementScreenState();
}

class _TableManagementScreenState extends ConsumerState<TableManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFFD4AF37),
          tabs: [
            Tab(text: ref.t('tables.tablesTab')),
            Tab(text: ref.t('tables.zonesTab')),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [_TablesTab(), _ZonesTab()],
          ),
        ),
      ],
    );
  }
}

// ── Tables Tab ────────────────────────────────────────────────────────────

class _TablesTab extends ConsumerWidget {
  const _TablesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final tablesAsync = ref.watch(tablesProvider);
    final zonesAsync = ref.watch(tableZonesProvider);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(ref.t('tables.addTable')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              onPressed: () =>
                  _showTableDialog(context, ref, null, zonesAsync.value ?? []),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: tablesAsync.when(
            data: (tables) => GlassContainer(
              opacity: 0.05,
              child: ListView.separated(
                itemCount: tables.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, index) {
                  final t = tables[index];
                  final isOccupied = t.status == TableStatus.occupied;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isOccupied
                          ? const Color(0xFF006B3C).withOpacity(0.2)
                          : Colors.white10,
                      child: Icon(
                        Icons.table_bar,
                        color: isOccupied
                            ? const Color(0xFFD4AF37)
                            : Colors.white38,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      t.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      t.zoneName != null
                          ? '${ref.t('tables.zone')}: ${t.zoneName}'
                          : ref.t('tables.noZoneAssigned'),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isOccupied
                                ? const Color(0xFF006B3C).withOpacity(0.2)
                                : Colors.white10,
                            borderRadius: BorderRadius.zero,
                          ),
                          child: Text(
                            t.status == TableStatus.available
                                ? ref.t('tables.statusAvailable')
                                : t.status == TableStatus.occupied
                                ? ref.t('tables.statusOccupied')
                                : ref.t('tables.statusReserved'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isOccupied
                                  ? const Color(0xFF006B3C)
                                  : Colors.white38,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: Colors.white54,
                          ),
                          onPressed: () => _showTableDialog(
                            context,
                            ref,
                            t,
                            zonesAsync.value ?? [],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          onPressed: isOccupied
                              ? null
                              : () => _confirmDeleteTable(context, ref, t),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('${ref.t('common.error')}: $e'),
          ),
        ),
      ],
    );
  }

  void _showTableDialog(
    BuildContext context,
    WidgetRef ref,
    TableModel? existing,
    List<TableZone> zones,
  ) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    int? selectedZoneId = existing?.zoneId;

    Future<void> doSave(BuildContext ctx) async {
      if (nameController.text.trim().isEmpty) return;
      final repo = ref.read(posRepositoryProvider);
      if (existing == null) {
        await repo.addTable(nameController.text.trim(), zoneId: selectedZoneId);
      } else {
        await repo.updateTable(
          existing.id!,
          nameController.text.trim(),
          zoneId: selectedZoneId,
        );
      }
      ref.invalidate(tablesProvider);
      Navigator.pop(ctx);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            existing == null
                ? ref.t('tables.addTable')
                : ref.t('tables.editTable'),
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: ref.t('tables.tableName'),
                    labelStyle: const TextStyle(color: Colors.white54),
                  ),
                  onSubmitted: (_) => doSave(ctx),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  value: selectedZoneId,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: ref.t('tables.zoneOptional'),
                    labelStyle: const TextStyle(color: Colors.white54),
                  ),
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text(ref.t('tables.noZone')),
                    ),
                    ...zones.map(
                      (z) => DropdownMenuItem<int?>(
                        value: z.id,
                        child: Text(z.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => selectedZoneId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ref.t('common.cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
              ),
              onPressed: () => doSave(ctx),
              child: Text(
                existing == null ? ref.t('common.add') : ref.t('common.save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTable(
    BuildContext context,
    WidgetRef ref,
    TableModel table,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(ref.t('tables.deleteTable')),
        content: Text(
          ref.t(
            'tables.deleteTableConfirm',
            replacements: {'name': table.name},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.t('common.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await ref.read(posRepositoryProvider).deleteTable(table.id!);
              ref.invalidate(tablesProvider);
              Navigator.pop(ctx);
            },
            child: Text(ref.t('common.delete')),
          ),
        ],
      ),
    );
  }
}

// ── Zones Tab ─────────────────────────────────────────────────────────────

class _ZonesTab extends ConsumerWidget {
  const _ZonesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final zonesAsync = ref.watch(tableZonesProvider);
    final waitersAsync = ref.watch(waitersProvider);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(ref.t('tables.addZone')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              onPressed: () =>
                  _showZoneDialog(context, ref, null, waitersAsync.value ?? []),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: zonesAsync.when(
            data: (zones) => zones.isEmpty
                ? Center(
                    child: Opacity(
                      opacity: 0.4,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.map_outlined, size: 56),
                          const SizedBox(height: 12),
                          Text(ref.t('tables.noZonesYet')),
                        ],
                      ),
                    ),
                  )
                : GlassContainer(
                    opacity: 0.05,
                    child: ListView.separated(
                      itemCount: zones.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, index) {
                        final z = zones[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF006B3C),
                            child: Icon(
                              Icons.map_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            z.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            z.waiterName != null
                                ? '${ref.t('tables.waiter')}: ${z.waiterName}'
                                : ref.t('tables.noWaiterAssigned'),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: Colors.white54,
                                ),
                                onPressed: () => _showZoneDialog(
                                  context,
                                  ref,
                                  z,
                                  waitersAsync.value ?? [],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () =>
                                    _confirmDeleteZone(context, ref, z),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('${ref.t('common.error')}: $e'),
          ),
        ),
      ],
    );
  }

  void _showZoneDialog(
    BuildContext context,
    WidgetRef ref,
    TableZone? existing,
    List<Waiter> waiters,
  ) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    int? selectedWaiterId = existing?.waiterId;

    Future<void> doSave(BuildContext ctx) async {
      if (nameController.text.trim().isEmpty) return;
      final repo = ref.read(posRepositoryProvider);
      if (existing == null) {
        await repo.addTableZone(
          nameController.text.trim(),
          waiterId: selectedWaiterId,
        );
      } else {
        await repo.updateTableZone(
          existing.id!,
          nameController.text.trim(),
          waiterId: selectedWaiterId,
        );
      }
      ref.invalidate(tableZonesProvider);
      ref.invalidate(waitersProvider);
      Navigator.pop(ctx);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            existing == null
                ? ref.t('tables.addZone')
                : ref.t('tables.editZone'),
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: ref.t('tables.zoneName'),
                    labelStyle: const TextStyle(color: Colors.white54),
                  ),
                  onSubmitted: (_) => doSave(ctx),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  value: selectedWaiterId,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: ref.t('tables.assignedWaiterOptional'),
                    labelStyle: const TextStyle(color: Colors.white54),
                  ),
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text(ref.t('tables.noWaiter')),
                    ),
                    ...waiters.map(
                      (w) => DropdownMenuItem<int?>(
                        value: w.id,
                        child: Text(w.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => selectedWaiterId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ref.t('common.cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
              ),
              onPressed: () => doSave(ctx),
              child: Text(
                existing == null ? ref.t('common.add') : ref.t('common.save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteZone(BuildContext context, WidgetRef ref, TableZone zone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(ref.t('tables.deleteZone')),
        content: Text(
          ref.t('tables.deleteZoneConfirm', replacements: {'name': zone.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.t('common.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await ref.read(posRepositoryProvider).deleteTableZone(zone.id!);
              ref.invalidate(tableZonesProvider);
              ref.invalidate(tablesProvider);
              Navigator.pop(ctx);
            },
            child: Text(ref.t('common.delete')),
          ),
        ],
      ),
    );
  }
}
