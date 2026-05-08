import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/models/zone_model.dart';
import 'package:st_george_pos/models/waiter.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:st_george_pos/services/order_workflow_service.dart';
import 'package:st_george_pos/services/zone_service.dart';
import 'package:st_george_pos/providers/pos_providers.dart';

/// Provider for current order workflow state
class OrderWorkflowNotifier extends StateNotifier<OrderWorkflowState> {
  OrderWorkflowNotifier(this.ref) : super(const OrderWorkflowState());

  final Ref ref;

  /// Initialize workflow for a specific table
  Future<void> initializeForTable(int tableId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final tables = await ref.read(tablesProvider.future);
      final zones = await _getZones();
      final waiters = await ref.read(waitersProvider.future);
      final orders = await ref.read(ordersProvider.future);
      
      final table = tables.where((t) => t.id == tableId).firstOrNull;
      if (table == null) {
        throw Exception('Table not found');
      }

      // Validate workflow
      final validationErrors = OrderWorkflowService.validateOrderWorkflow(
        tableId: tableId,
        zones: zones,
        waiters: waiters,
      );
      
      if (validationErrors.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: validationErrors.join(', '),
        );
        return;
      }

      // Get existing orders for this table
      final existingOrders = OrderWorkflowService.getHeldOrdersForTable(tableId, orders);
      final mostRecentOrder = OrderWorkflowService.getMostRecentOrderForTable(tableId, orders);
      
      // Get assigned waiter
      final assignedWaiter = OrderWorkflowService.getAssignedWaiterForTable(tableId, zones, waiters);
      
      state = state.copyWith(
        isLoading: false,
        selectedTable: table,
        assignedWaiter: assignedWaiter,
        existingOrders: existingOrders,
        currentOrder: mostRecentOrder,
        canCreateNewOrder: mostRecentOrder == null || mostRecentOrder.status == OrderStatus.completed,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Create a new order session
  Future<void> createNewOrderSession({
    required int cashierId,
    required String cashierName,
  }) async {
    if (state.selectedTable == null || state.assignedWaiter == null) {
      state = state.copyWith(error: 'Table or waiter not selected');
      return;
    }

    try {
      final zones = await _getZones();
      final waiters = await ref.read(waitersProvider.future);
      
      final newOrder = OrderWorkflowService.createOrderSession(
        tableId: state.selectedTable!.id!,
        tableName: state.selectedTable!.name,
        zones: zones,
        waiters: waiters,
        cashierId: cashierId,
        cashierName: cashierName,
      );

      state = state.copyWith(
        currentOrder: newOrder,
        isCreatingOrder: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Add items to current order
  void addItemsToOrder(List<OrderItem> items) {
    if (state.currentOrder == null) {
      state = state.copyWith(error: 'No active order');
      return;
    }

    try {
      final updatedOrder = state.currentOrder!.copyWith(
        items: [...state.currentOrder!.items, ...items],
        totalAmount: state.currentOrder!.totalAmount + 
                    items.fold(0.0, (sum, item) => sum + item.subtotal),
        updatedAt: DateTime.now(),
      );

      state = state.copyWith(currentOrder: updatedOrder);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Add items to existing held order
  Future<void> addToExistingHeldOrder({
    required OrderModel heldOrder,
    required List<OrderItem> newItems,
  }) async {
    try {
      final zones = await _getZones();
      final waiters = await ref.read(waitersProvider.future);
      
      final updatedOrder = OrderWorkflowService.addToExistingSession(
        existingOrder: heldOrder,
        newItems: newItems,
        zones: zones,
        waiters: waiters,
      );

      // Update current order and existing orders list
      final updatedExistingOrders = state.existingOrders.map((order) {
        return order.id == heldOrder.id ? updatedOrder : order;
      }).toList();

      state = state.copyWith(
        currentOrder: updatedOrder,
        existingOrders: updatedExistingOrders,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Hold current order
  void holdCurrentOrder() {
    if (state.currentOrder == null) {
      state = state.copyWith(error: 'No order to hold');
      return;
    }

    try {
      final heldOrder = OrderWorkflowService.holdOrder(state.currentOrder!);
      
      state = state.copyWith(
        currentOrder: heldOrder,
        existingOrders: [...state.existingOrders, heldOrder],
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Create new session for table with existing held orders
  Future<void> createNewSessionForHeldTable({
    required int cashierId,
    required String cashierName,
  }) async {
    if (state.selectedTable == null) {
      state = state.copyWith(error: 'No table selected');
      return;
    }

    try {
      final zones = await _getZones();
      final waiters = await ref.read(waitersProvider.future);
      
      final newSession = OrderWorkflowService.createSessionForHeldTable(
        tableId: state.selectedTable!.id!,
        tableName: state.selectedTable!.name,
        heldOrders: state.existingOrders,
        zones: zones,
        waiters: waiters,
        cashierId: cashierId,
        cashierName: cashierName,
      );

      state = state.copyWith(
        currentOrder: newSession,
        isCreatingOrder: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Combine sessions for final billing
  Future<OrderModel> combineSessionsForBilling() async {
    if (state.existingOrders.isEmpty) {
      throw Exception('No sessions to combine');
    }

    try {
      final zones = await _getZones();
      final waiters = await ref.read(waitersProvider.future);
      
      final combinedOrder = OrderWorkflowService.combineSessionsForBilling(
        tableId: state.selectedTable!.id!,
        sessions: state.existingOrders,
        zones: zones,
        waiters: waiters,
      );

      return combinedOrder;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Reset workflow state
  void reset() {
    state = const OrderWorkflowState();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Get zones (mock implementation for now)
  Future<List<Zone>> _getZones() async {
    // For now, return default zones
    // In a real implementation, this would fetch from database
    final tables = await ref.read(tablesProvider.future);
    final waiters = await ref.read(waitersProvider.future);
    return ZoneService.getDefaultZones(tables, waiters);
  }
}

/// State for order workflow
class OrderWorkflowState {
  final bool isLoading;
  final bool isCreatingOrder;
  final String? error;
  final TableModel? selectedTable;
  final Waiter? assignedWaiter;
  final OrderModel? currentOrder;
  final List<OrderModel> existingOrders;
  final bool canCreateNewOrder;

  const OrderWorkflowState({
    this.isLoading = false,
    this.isCreatingOrder = false,
    this.error,
    this.selectedTable,
    this.assignedWaiter,
    this.currentOrder,
    this.existingOrders = const [],
    this.canCreateNewOrder = true,
  });

  OrderWorkflowState copyWith({
    bool? isLoading,
    bool? isCreatingOrder,
    String? error,
    TableModel? selectedTable,
    Waiter? assignedWaiter,
    OrderModel? currentOrder,
    List<OrderModel>? existingOrders,
    bool? canCreateNewOrder,
  }) {
    return OrderWorkflowState(
      isLoading: isLoading ?? this.isLoading,
      isCreatingOrder: isCreatingOrder ?? this.isCreatingOrder,
      error: error ?? this.error,
      selectedTable: selectedTable ?? this.selectedTable,
      assignedWaiter: assignedWaiter ?? this.assignedWaiter,
      currentOrder: currentOrder ?? this.currentOrder,
      existingOrders: existingOrders ?? this.existingOrders,
      canCreateNewOrder: canCreateNewOrder ?? this.canCreateNewOrder,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderWorkflowState &&
        other.isLoading == isLoading &&
        other.isCreatingOrder == isCreatingOrder &&
        other.error == error &&
        other.selectedTable == selectedTable &&
        other.assignedWaiter == assignedWaiter &&
        other.currentOrder == currentOrder &&
        other.existingOrders.length == existingOrders.length &&
        other.canCreateNewOrder == canCreateNewOrder;
  }

  @override
  int get hashCode {
    return Object.hash(
      isLoading,
      isCreatingOrder,
      error,
      selectedTable,
      assignedWaiter,
      currentOrder,
      existingOrders.length,
      canCreateNewOrder,
    );
  }
}

/// Provider for order workflow
final orderWorkflowProvider = StateNotifierProvider<OrderWorkflowNotifier, OrderWorkflowState>((ref) {
  return OrderWorkflowNotifier(ref);
});

/// Provider for zone configuration
final zoneConfigurationProvider = FutureProvider<List<Zone>>((ref) async {
  final tables = await ref.read(tablesProvider.future);
  final waiters = await ref.read(waitersProvider.future);
  return ZoneService.getDefaultZones(tables, waiters);
});
