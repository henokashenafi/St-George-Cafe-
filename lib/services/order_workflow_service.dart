import 'package:st_george_pos/models/zone_model.dart';
import 'package:st_george_pos/models/table_model.dart';
import 'package:st_george_pos/models/waiter.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:st_george_pos/services/zone_service.dart';

class OrderWorkflowService {
  /// Get automatically assigned waiter for a table based on zone configuration
  static Waiter? getAssignedWaiterForTable(
    int tableId, 
    List<Zone> zones, 
    List<Waiter> waiters
  ) {
    return ZoneService.getAssignedWaiter(tableId, zones, waiters);
  }

  /// Get automatically assigned waiter for a table by table name
  static Waiter? getAssignedWaiterForTableByName(
    String tableName,
    List<Zone> zones,
    List<Waiter> waiters
  ) {
    return ZoneService.getAssignedWaiterByName(tableName, zones, waiters);
  }

  /// Create a new order session with automatic waiter assignment
  static OrderModel createOrderSession({
    required int tableId,
    required String tableName,
    required List<Zone> zones,
    required List<Waiter> waiters,
    int? cashierId,
    String? cashierName,
  }) {
    final assignedWaiter = getAssignedWaiterForTable(tableId, zones, waiters);
    final zone = ZoneService.getZoneByTable(tableId, zones);
    
    if (assignedWaiter == null) {
      throw Exception('No waiter assigned to table $tableName. Please configure zone assignments.');
    }

    final now = DateTime.now();
    final sessionId = _generateSessionId(tableId, now);
    
    return OrderModel(
      tableId: tableId,
      tableName: tableName,
      waiterId: assignedWaiter.id!,
      waiterName: assignedWaiter.name,
      cashierId: cashierId,
      cashierName: cashierName ?? '',
      status: OrderStatus.pending,
      createdAt: now,
      updatedAt: now,
      sessionId: sessionId,
      isHeld: false,
      zoneId: zone?.id,
    );
  }

  /// Add items to an existing order session (for holding functionality)
  static OrderModel addToExistingSession({
    required OrderModel existingOrder,
    required List<OrderItem> newItems,
    required List<Zone> zones,
    required List<Waiter> waiters,
  }) {
    // Verify the assigned waiter is still correct
    final currentWaiter = getAssignedWaiterForTable(existingOrder.tableId, zones, waiters);
    
    if (currentWaiter == null) {
      throw Exception('Waiter assignment has changed. Please refresh the order.');
    }

    // Combine existing items with new items
    final combinedItems = <OrderItem>[];
    
    // Add existing items
    combinedItems.addAll(existingOrder.items);
    
    // Add new items, merging with existing quantities if same product
    for (final newItem in newItems) {
      final existingItemIndex = combinedItems.indexWhere(
        (item) => item.productId == newItem.productId
      );
      
      if (existingItemIndex >= 0) {
        // Update quantity of existing item
        final existingItem = combinedItems[existingItemIndex];
        combinedItems[existingItemIndex] = existingItem.copyWith(
          quantity: existingItem.quantity + newItem.quantity,
        );
      } else {
        // Add new item
        combinedItems.add(newItem);
      }
    }

    // Recalculate total
    final newTotal = combinedItems.fold(0.0, (sum, item) => sum + item.subtotal);

    return existingOrder.copyWith(
      items: combinedItems,
      totalAmount: newTotal,
      updatedAt: DateTime.now(),
      isHeld: true, // Mark as held since we're adding to existing session
    );
  }

  /// Hold an order for later addition (when new customers join table)
  static OrderModel holdOrder(OrderModel order) {
    return order.copyWith(
      status: OrderStatus.held,
      isHeld: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Create a new session for a table that has existing held orders
  static OrderModel createSessionForHeldTable({
    required int tableId,
    required String tableName,
    required List<OrderModel> heldOrders,
    required List<Zone> zones,
    required List<Waiter> waiters,
    int? cashierId,
    String? cashierName,
  }) {
    // Create new session
    final newSession = createOrderSession(
      tableId: tableId,
      tableName: tableName,
      zones: zones,
      waiters: waiters,
      cashierId: cashierId,
      cashierName: cashierName,
    );

    // Link to parent order (first held order)
    if (heldOrders.isNotEmpty) {
      return newSession.copyWith(
        parentOrderId: heldOrders.first.id,
      );
    }

    return newSession;
  }

  /// Get all held orders for a specific table
  static List<OrderModel> getHeldOrdersForTable(
    int tableId,
    List<OrderModel> allOrders
  ) {
    return allOrders
        .where((order) => 
            order.tableId == tableId && 
            (order.isHeld || order.status == OrderStatus.held))
        .toList();
  }

  /// Combine multiple sessions for final billing
  static OrderModel combineSessionsForBilling({
    required int tableId,
    required List<OrderModel> sessions,
    required List<Zone> zones,
    required List<Waiter> waiters,
  }) {
    if (sessions.isEmpty) {
      throw Exception('No sessions found for table $tableId');
    }

    // Use the first session as the base
    final baseSession = sessions.first;
    final assignedWaiter = getAssignedWaiterForTable(tableId, zones, waiters);
    
    // Combine all items from all sessions
    final combinedItems = <OrderItem>[];
    final sessionIds = <String>[];
    
    for (final session in sessions) {
      combinedItems.addAll(session.items);
      sessionIds.add(session.sessionId);
    }

    // Calculate combined total
    final combinedTotal = combinedItems.fold(0.0, (sum, item) => sum + item.subtotal);

    // Create combined order for billing
    return OrderModel(
      tableId: tableId,
      tableName: baseSession.tableName,
      waiterId: assignedWaiter?.id ?? baseSession.waiterId,
      waiterName: assignedWaiter?.name ?? baseSession.waiterName,
      cashierId: baseSession.cashierId,
      cashierName: baseSession.cashierName,
      status: OrderStatus.pending,
      createdAt: baseSession.createdAt,
      updatedAt: DateTime.now(),
      totalAmount: combinedTotal,
      items: combinedItems,
      sessionId: 'combined_${sessionIds.join('_')}',
      isHeld: false,
      zoneId: baseSession.zoneId,
    );
  }

  /// Generate unique session ID for tracking
  static String _generateSessionId(int tableId, DateTime timestamp) {
    return 'table_${tableId}_${timestamp.millisecondsSinceEpoch}';
  }

  /// Check if a table has active or held orders
  static bool hasActiveOrHeldOrders(int tableId, List<OrderModel> orders) {
    return orders.any((order) => 
        order.tableId == tableId && 
        (order.status == OrderStatus.pending || order.status == OrderStatus.held)
    );
  }

  /// Get the most recent order for a table
  static OrderModel? getMostRecentOrderForTable(int tableId, List<OrderModel> orders) {
    final tableOrders = orders
        .where((order) => order.tableId == tableId)
        .toList();
    
    if (tableOrders.isEmpty) return null;
    
    tableOrders.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return tableOrders.first;
  }

  /// Validate order workflow before processing
  static List<String> validateOrderWorkflow({
    required int tableId,
    required List<Zone> zones,
    required List<Waiter> waiters,
    OrderModel? existingOrder,
  }) {
    final errors = <String>[];
    
    // Check if table has zone assignment
    final zone = ZoneService.getZoneByTable(tableId, zones);
    if (zone == null) {
      errors.add('Table $tableId is not assigned to any zone');
    }
    
    // Check if zone has waiter assignment
    if (zone?.waiterId == null) {
      errors.add('Zone ${zone?.name} does not have an assigned waiter');
    }
    
    // Check if waiter exists
    if (zone?.waiterId != null) {
      final waiterExists = waiters.any((w) => w.id == zone!.waiterId);
      if (!waiterExists) {
        errors.add('Assigned waiter not found in system');
      }
    }
    
    // Check existing order compatibility
    if (existingOrder != null) {
      if (existingOrder.tableId != tableId) {
        errors.add('Existing order belongs to different table');
      }
      
      if (existingOrder.status == OrderStatus.completed) {
        errors.add('Cannot modify completed order');
      }
    }
    
    return errors;
  }
}
