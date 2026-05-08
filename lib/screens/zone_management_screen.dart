import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/models/zone_model.dart';
import 'package:st_george_pos/models/table_model.dart';
import 'package:st_george_pos/models/waiter.dart';
import 'package:st_george_pos/providers/pos_providers.dart';
import 'package:st_george_pos/services/zone_service.dart';
import 'package:st_george_pos/locales/app_localizations.dart';

class ZoneManagementScreen extends ConsumerStatefulWidget {
  const ZoneManagementScreen({super.key});

  @override
  ConsumerState<ZoneManagementScreen> createState() =>
      _ZoneManagementScreenState();
}

class _ZoneManagementScreenState extends ConsumerState<ZoneManagementScreen> {
  List<Zone> zones = [];
  List<TableModel> allTables = [];
  List<Waiter> allWaiters = [];
  List<TableModel> unassignedTables = [];
  bool isLoading = false;
  List<String> validationErrors = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final tablesAsync = await ref.read(tablesProvider.future);
      final waitersAsync = await ref.read(waitersProvider.future);

      allTables = tablesAsync;
      allWaiters = waitersAsync;

      // Initialize with default zones if none exist
      zones = ZoneService.getDefaultZones(allTables, allWaiters);
      _updateUnassignedTables();
      _validateConfiguration();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _updateUnassignedTables() {
    final assignedTableIds = zones
        .expand((zone) => zone.tables.map((t) => t.id!))
        .toSet();
    unassignedTables = allTables
        .where((table) => !assignedTableIds.contains(table.id!))
        .toList();
  }

  void _validateConfiguration() {
    validationErrors = ZoneService.validateZoneConfiguration(zones, allTables);
  }

  void _showAssignWaiterDialog(Zone zone) {
    final availableWaiters = allWaiters
        .where(
          (waiter) =>
              !zones.any((z) => z.waiterId == waiter.id && z.id != zone.id),
        )
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(ref.t('zoneManagement.assignWaiter')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${ref.t('zoneManagement.zone')}: ${zone.name}'),
            const SizedBox(height: 16),
            DropdownButton<Waiter>(
              hint: Text(ref.t('zoneManagement.waiter')),
              value: availableWaiters
                  .where((w) => w.id == zone.waiterId)
                  .firstOrNull,
              dropdownColor: const Color(0xFF121212),
              style: const TextStyle(color: Colors.white),
              isExpanded: true,
              items: availableWaiters
                  .map(
                    (waiter) => DropdownMenuItem(
                      value: waiter,
                      child: Text('${waiter.name} (${waiter.code})'),
                    ),
                  )
                  .toList(),
              onChanged: (waiter) {
                if (waiter != null) {
                  setState(() {
                    zones = ZoneService.assignWaiterToZone(waiter, zone, zones);
                    _validateConfiguration();
                  });
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.t('common.cancel')),
          ),
        ],
      ),
    );
  }

  void _showAssignTablesDialog(Zone zone) {
    final availableTables = unassignedTables.toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(ref.t('zoneManagement.assignTables')),
        content: SizedBox(
          width: 400,
          height: 300,
          child: Column(
            children: [
              Text('${ref.t('zoneManagement.zone')}: ${zone.name}'),
              Text(
                '${ref.t('zoneManagement.tables')}: ${zone.tables.length}/5',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: availableTables.length,
                  itemBuilder: (context, index) {
                    final table = availableTables[index];
                    return CheckboxListTile(
                      title: Text(table.name),
                      subtitle: Text('Status: ${table.status.name}'),
                      value: zone.tables.any((t) => t.id == table.id),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            if (zone.tables.length < 5) {
                              zones = ZoneService.assignTableToZone(
                                table,
                                zone,
                                zones,
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ref.t(
                                      'zoneManagement.tableLimitExceeded',
                                      replacements: {
                                        'zoneName': zone.name,
                                        'tableCount': '${zone.tables.length}',
                                      },
                                    ),
                                  ),
                                ),
                              );
                            }
                          } else {
                            final updatedZone = zone.copyWith(
                              tables: zone.tables
                                  .where((t) => t.id != table.id)
                                  .toList(),
                            );
                            zones = zones
                                .map((z) => z.id == zone.id ? updatedZone : z)
                                .toList();
                          }
                          _updateUnassignedTables();
                          _validateConfiguration();
                        });
                        Navigator.pop(ctx);
                        _showAssignTablesDialog(zone); // Refresh dialog
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.t('common.cancel')),
          ),
        ],
      ),
    );
  }

  void _resetToDefault() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(ref.t('zoneManagement.resetToDefault')),
        content: Text(ref.t('zoneManagement.confirmReset')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.t('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                zones = ZoneService.getDefaultZones(allTables, allWaiters);
                _updateUnassignedTables();
                _validateConfiguration();
              });
              Navigator.pop(ctx);
            },
            child: Text(ref.t('common.confirm')),
          ),
        ],
      ),
    );
  }

  Future<void> _saveConfiguration() async {
    setState(() => isLoading = true);
    try {
      final repo = ref.read(posRepositoryProvider);

      for (final zone in zones) {
        if (zone.id != null) {
          await repo.updateTableZone(
            zone.id!,
            zone.name,
            waiterId: zone.waiterId,
          );
        } else {
          final newId = await repo.addTableZone(
            zone.name,
            waiterId: zone.waiterId,
          );
          for (final table in zone.tables) {
            await repo.updateTable(table.id!, table.name, zoneId: newId);
          }
          continue;
        }

        for (final table in zone.tables) {
          await repo.updateTable(table.id!, table.name, zoneId: zone.id);
        }
      }

      for (final table in unassignedTables) {
        await repo.updateTable(table.id!, table.name, zoneId: null);
      }

      ref.invalidate(tablesProvider);
      ref.invalidate(tableZonesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.t('zoneManagement.saveConfiguration'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${ref.t('common.error')}: $e')));
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildZoneCard(Zone zone) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  zone.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _showAssignWaiterDialog(zone),
                      icon: const Icon(
                        Icons.person_add,
                        color: Color(0xFFD4AF37),
                      ),
                      tooltip: ref.t('zoneManagement.assignWaiter'),
                    ),
                    IconButton(
                      onPressed: () => _showAssignTablesDialog(zone),
                      icon: const Icon(
                        Icons.table_restaurant,
                        color: Color(0xFFD4AF37),
                      ),
                      tooltip: ref.t('zoneManagement.assignTables'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (zone.waiterName != null) ...[
              Text(
                '${ref.t('zoneManagement.waiter')}: ${zone.waiterName}',
                style: const TextStyle(color: Colors.white70),
              ),
            ] else ...[
              Text(
                ref.t('zoneManagement.waiter'),
                style: const TextStyle(color: Colors.white38),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${ref.t('zoneManagement.tables')}: ${zone.tables.length}/5',
              style: const TextStyle(color: Colors.white70),
            ),
            if (zone.tables.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: zone.tables
                    .map(
                      (table) => Chip(
                        label: Text(table.name),
                        backgroundColor: table.status == TableStatus.occupied
                            ? Colors.red.withOpacity(0.2)
                            : Colors.green.withOpacity(0.2),
                        labelStyle: const TextStyle(fontSize: 12),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    final stats = ZoneService.getZoneStatistics(zones);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.t('zoneManagement.zoneStatistics'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    ref.t('zoneManagement.totalZones'),
                    '${stats['totalZones']}',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    ref.t('zoneManagement.totalTables'),
                    '${stats['totalTables']}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    ref.t('zoneManagement.zonesWithWaiters'),
                    '${stats['zonesWithWaiters']}',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    ref.t('zoneManagement.zonesWithoutWaiters'),
                    '${stats['zonesWithoutWaiters']}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildStatItem(
              ref.t('zoneManagement.averageTablesPerZone'),
              (stats['averageTablesPerZone'] as double).toStringAsFixed(1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD4AF37),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        title: Text(ref.t('zoneManagement.title')),
        backgroundColor: Colors.black.withOpacity(0.3),
        actions: [
          IconButton(
            onPressed: _resetToDefault,
            icon: const Icon(Icons.refresh),
            tooltip: ref.t('zoneManagement.resetToDefault'),
          ),
          IconButton(
            onPressed: _saveConfiguration,
            icon: const Icon(Icons.save),
            tooltip: ref.t('zoneManagement.saveConfiguration'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatistics(),
            if (validationErrors.isNotEmpty) ...[
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                color: Colors.red.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.t('zoneManagement.validationErrors'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...validationErrors.map(
                        (error) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            error,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            Text(
              ref.t('zoneManagement.title'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ...zones.map(_buildZoneCard),
            if (unassignedTables.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                ref.t('zoneManagement.unassignedTables'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.white.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: unassignedTables
                        .map(
                          (table) => Chip(
                            label: Text(table.name),
                            backgroundColor: Colors.orange.withOpacity(0.2),
                            labelStyle: const TextStyle(fontSize: 12),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
