import 'package:st_george_pos/models/zone_model.dart';
import 'package:st_george_pos/models/table_model.dart';
import 'package:st_george_pos/models/waiter.dart';

class ZoneService {
  static const int _tablesPerZone = 5;
  static const int _totalZones = 5;

  /// Get default zone configuration (5 zones, 5 tables each)
  static List<Zone> getDefaultZones(List<TableModel> allTables, List<Waiter> allWaiters) {
    final zones = <Zone>[];
    
    for (int i = 0; i < _totalZones; i++) {
      final zoneIndex = i + 1;
      final startTable = (i * _tablesPerZone) + 1;
      final endTable = startTable + _tablesPerZone - 1;
      
      // Get tables for this zone
      final zoneTables = allTables.where((table) {
        final tableNumber = int.tryParse(table.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return tableNumber >= startTable && tableNumber <= endTable;
      }).toList();
      
      // Get waiter for this zone (waiter 1 for zone 1, etc.)
      final zoneWaiter = allWaiters.where((waiter) => waiter.code == zoneIndex.toString()).firstOrNull;
      
      zones.add(Zone(
        name: 'Zone $zoneIndex',
        waiterId: zoneWaiter?.id,
        waiterName: zoneWaiter?.name,
        tables: zoneTables,
      ));
    }
    
    return zones;
  }

  /// Get zone by table ID
  static Zone? getZoneByTable(int tableId, List<Zone> zones) {
    for (final zone in zones) {
      if (zone.tables.any((table) => table.id == tableId)) {
        return zone;
      }
    }
    return null;
  }

  /// Get zone by table number (extracted from table name)
  static Zone? getZoneByTableNumber(String tableName, List<Zone> zones) {
    final tableNumber = int.tryParse(tableName.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final zoneIndex = ((tableNumber - 1) ~/ _tablesPerZone) + 1;
    
    return zones.where((zone) => zone.name == 'Zone $zoneIndex').firstOrNull;
  }

  /// Get assigned waiter for a table
  static Waiter? getAssignedWaiter(int tableId, List<Zone> zones, List<Waiter> allWaiters) {
    final zone = getZoneByTable(tableId, zones);
    if (zone?.waiterId != null) {
      return allWaiters.where((waiter) => waiter.id == zone!.waiterId).firstOrNull;
    }
    return null;
  }

  /// Get assigned waiter for a table by table name
  static Waiter? getAssignedWaiterByName(String tableName, List<Zone> zones, List<Waiter> allWaiters) {
    final zone = getZoneByTableNumber(tableName, zones);
    if (zone?.waiterId != null) {
      return allWaiters.where((waiter) => waiter.id == zone!.waiterId).firstOrNull;
    }
    return null;
  }

  /// Assign table to zone
  static List<Zone> assignTableToZone(TableModel table, Zone targetZone, List<Zone> zones) {
    return zones.map((zone) {
      if (zone.id == targetZone.id) {
        return zone.copyWith(
          tables: [...zone.tables, table],
        );
      }
      // Remove table from other zones if it exists there
      if (zone.tables.any((t) => t.id == table.id)) {
        return zone.copyWith(
          tables: zone.tables.where((t) => t.id != table.id).toList(),
        );
      }
      return zone;
    }).toList();
  }

  /// Assign waiter to zone
  static List<Zone> assignWaiterToZone(Waiter waiter, Zone targetZone, List<Zone> zones) {
    // Remove waiter from all zones first (one waiter per zone)
    var updatedZones = zones.map((zone) {
      if (zone.waiterId == waiter.id) {
        return zone.copyWith(waiterId: null, waiterName: null);
      }
      return zone;
    }).toList();

    // Assign waiter to target zone
    updatedZones = updatedZones.map((zone) {
      if (zone.id == targetZone.id) {
        return zone.copyWith(waiterId: waiter.id, waiterName: waiter.name);
      }
      return zone;
    }).toList();

    return updatedZones;
  }

  /// Validate zone configuration
  static List<String> validateZoneConfiguration(List<Zone> zones, List<TableModel> allTables) {
    final errors = <String>[];
    
    // Check if all tables are assigned to zones
    final assignedTableIds = zones.expand((zone) => zone.tables.map((t) => t.id)).toSet();
    final unassignedTables = allTables.where((table) => !assignedTableIds.contains(table.id));
    
    if (unassignedTables.isNotEmpty) {
      errors.add('Unassigned tables: ${unassignedTables.map((t) => t.name).join(', ')}');
    }

    // Check zone table limits
    for (final zone in zones) {
      if (zone.tables.length > _tablesPerZone) {
        errors.add('Zone ${zone.name} has ${zone.tables.length} tables (max: $_tablesPerZone)');
      }
    }

    // Check for duplicate waiter assignments
    final waiterAssignments = <int, List<Zone>>{};
    for (final zone in zones) {
      if (zone.waiterId != null) {
        waiterAssignments.putIfAbsent(zone.waiterId!, () => []).add(zone);
      }
    }

    for (final entry in waiterAssignments.entries) {
      if (entry.value.length > 1) {
        errors.add('Waiter ${entry.key} is assigned to multiple zones: ${entry.value.map((z) => z.name).join(', ')}');
      }
    }

    return errors;
  }

  /// Get zone statistics
  static Map<String, dynamic> getZoneStatistics(List<Zone> zones) {
    final totalTables = zones.fold(0, (sum, zone) => sum + zone.tables.length);
    final zonesWithWaiters = zones.where((zone) => zone.waiterId != null).length;
    final zonesWithoutWaiters = zones.length - zonesWithWaiters;

    return {
      'totalZones': zones.length,
      'totalTables': totalTables,
      'zonesWithWaiters': zonesWithWaiters,
      'zonesWithoutWaiters': zonesWithoutWaiters,
      'averageTablesPerZone': totalTables / zones.length,
    };
  }
}

extension on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
}
