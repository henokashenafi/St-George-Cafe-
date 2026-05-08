import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/models/table_model.dart';
import 'package:st_george_pos/models/zone_model.dart';
import 'package:st_george_pos/models/waiter.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:st_george_pos/services/order_workflow_service.dart';
import 'package:st_george_pos/services/zone_service.dart';
import 'package:st_george_pos/providers/pos_providers.dart';

// ── State ─────────────────────────────────────────────────────────────────

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
      error: error, // allow clearing error by passing null
      selectedTable: selectedTable ?? this.selectedTable,
      assignedWaiter: assignedWaiter ?? this.assignedWaiter,
      currentOrder: currentOrder ?? this.currentOrder,
      existingOrders: existingOrders ?? this.existingOrders,
      canCreateNewOrder: canCreateNewOrder ?? this.canCreateNewOrder,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────

class OrderWorkflowNotifier extends Notifier<OrderWorkflowState> {
  @override
  OrderWorkflowState build() => const OrderWorkflowState();

  Future<void> initializeForTable(int tableId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final tables = await ref.read(tablesProvider.future);
      final zones = await _getZones();
      final waiters = await ref.read(waitersProvider.future);
      final orders = await ref.read(ordersProvider.future);

      final table = tables.where((t) => t.id == tableId).firstOrNull;
      if (table == null) throw Exception('Table not found');

      final existingOrders = OrderWorkflowService.getHeldOrdersForTable(
        tableId,
        orders,
      );
      final mostRecentOrder = OrderWorkflowService.getMostRecentOrderForTable(
        tableId,
        orders,
      );
      var assignedWaiter = OrderWorkflowService.getAssignedWaiterForTable(
        tableId,
        zones,
        waiters,
      );
      if (assignedWaiter == null && waiters.isNotEmpty) {
        assignedWaiter = waiters.first;
      }

      state = state.copyWith(
        isLoading: false,
        selectedTable: table,
        assignedWaiter: assignedWaiter,
        existingOrders: existingOrders,
        currentOrder: mostRecentOrder,
        canCreateNewOrder:
            mostRecentOrder == null ||
            mostRecentOrder.status == OrderStatus.completed,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createNewOrderSession({
    required int cashierId,
    required String cashierName,
  }) async {
    if (state.selectedTable == null || state.assignedWaiter == null) {
      state = state.copyWith(error: 'Table or waiter not selected');
      return;
    }
    try {
      final newOrder = OrderModel(
        tableId: state.selectedTable!.id!,
        tableName: state.selectedTable!.name,
        waiterId: state.assignedWaiter!.id!,
        waiterName: state.assignedWaiter!.name,
        cashierId: cashierId,
        cashierName: cashierName,
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isHeld: false,
      );

      state = state.copyWith(currentOrder: newOrder, isCreatingOrder: false);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void addItemsToOrder(List<OrderItem> items) {
    if (state.currentOrder == null) {
      state = state.copyWith(error: 'No active order');
      return;
    }
    try {
      final updatedOrder = state.currentOrder!.copyWith(
        items: [...state.currentOrder!.items, ...items],
        totalAmount:
            state.currentOrder!.totalAmount +
            items.fold(0.0, (sum, item) => sum + item.subtotal),
        updatedAt: DateTime.now(),
      );
      state = state.copyWith(currentOrder: updatedOrder);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

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

      final updatedExistingOrders = state.existingOrders
          .map((o) => o.id == heldOrder.id ? updatedOrder : o)
          .toList();

      state = state.copyWith(
        currentOrder: updatedOrder,
        existingOrders: updatedExistingOrders,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void setWaiter(Waiter waiter) {
    state = state.copyWith(assignedWaiter: waiter);
  }

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

      state = state.copyWith(currentOrder: newSession, isCreatingOrder: false);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<OrderModel> combineSessionsForBilling() async {
    if (state.existingOrders.isEmpty) throw Exception('No sessions to combine');
    try {
      final zones = await _getZones();
      final waiters = await ref.read(waitersProvider.future);

      return OrderWorkflowService.combineSessionsForBilling(
        tableId: state.selectedTable!.id!,
        sessions: state.existingOrders,
        zones: zones,
        waiters: waiters,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  void reset() => state = const OrderWorkflowState();

  void clearError() => state = state.copyWith(error: null);

  Future<List<Zone>> _getZones() async {
    final tables = await ref.read(tablesProvider.future);
    final waiters = await ref.read(waitersProvider.future);
    return ZoneService.getDefaultZones(tables, waiters);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

final orderWorkflowProvider =
    NotifierProvider<OrderWorkflowNotifier, OrderWorkflowState>(
      OrderWorkflowNotifier.new,
    );

final zoneConfigurationProvider = FutureProvider<List<Zone>>((ref) async {
  final tables = await ref.read(tablesProvider.future);
  final waiters = await ref.read(waitersProvider.future);
  return ZoneService.getDefaultZones(tables, waiters);
});
