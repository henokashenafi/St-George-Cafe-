import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/models/category.dart';
import 'package:st_george_pos/models/product.dart';
import 'package:st_george_pos/models/table_model.dart';
import 'package:st_george_pos/models/waiter.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:st_george_pos/services/pos_repository.dart';
import 'package:st_george_pos/services/print_service.dart';

enum DashboardView { tables, orders, menu, waiters, reports }

class DashboardViewNotifier extends Notifier<DashboardView> {
  @override
  DashboardView build() => DashboardView.tables;
  set state(DashboardView view) => super.state = view;
}

final dashboardViewProvider = NotifierProvider<DashboardViewNotifier, DashboardView>(DashboardViewNotifier.new);

final posRepositoryProvider = Provider((ref) => PosRepository());
final printServiceProvider = Provider((ref) => PrintService());

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getCategories();
});

final productsProvider = FutureProvider.family<List<Product>, int?>((ref, categoryId) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getProducts(categoryId: categoryId);
});

final tablesProvider = FutureProvider.autoDispose<List<TableModel>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getTables();
});

final waitersProvider = FutureProvider.autoDispose<List<Waiter>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getWaiters();
});

final ordersProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getAllOrders();
});

final activeOrderProvider = FutureProvider.autoDispose.family<OrderModel?, int>((ref, tableId) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getActiveOrderForTable(tableId);
});

class ActiveOrderService {
  final Ref ref;
  ActiveOrderService(this.ref);

  PosRepository get repo => ref.read(posRepositoryProvider);

  Future<void> loadOrderForTable(int tableId) async {
    ref.invalidate(activeOrderProvider(tableId));
  }

  Future<void> createNewOrder(OrderModel order) async {
    await repo.createOrder(order);
    await loadOrderForTable(order.tableId);
  }

  Future<void> addItems(int orderId, List<OrderItem> items, int tableId) async {
    await repo.addItemsToOrder(orderId, items);
    await loadOrderForTable(tableId);
  }
}

final activeOrderServiceProvider = Provider.autoDispose((ref) => ActiveOrderService(ref));
