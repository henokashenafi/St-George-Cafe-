import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/models/app_user.dart';
import 'package:st_george_pos/models/category.dart';
import 'package:st_george_pos/models/product.dart';
import 'package:st_george_pos/models/table_model.dart';
import 'package:st_george_pos/models/table_zone.dart';
import 'package:st_george_pos/models/waiter.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:st_george_pos/services/pos_repository.dart';
import 'package:st_george_pos/services/print_service.dart';

enum DashboardView { tables, orders, menu, waiters, reports, settings, users }

// ── Repository & Services ─────────────────────────────────────────────────

final posRepositoryProvider = Provider((ref) => PosRepository());
final printServiceProvider = Provider((ref) => PrintService());

// ── Auth ──────────────────────────────────────────────────────────────────

class AuthNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() => null;

  Future<bool> login(String username, String password) async {
    final repo = ref.read(posRepositoryProvider);
    final user = await repo.login(username, password);
    if (user != null) {
      state = user;
      return true;
    }
    return false;
  }

  void logout() => state = null;
}

final authProvider = NotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);

// ── Settings ──────────────────────────────────────────────────────────────

final settingsProvider = FutureProvider<Map<String, String>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getSettings();
});

// ── Dashboard View ────────────────────────────────────────────────────────

class DashboardViewNotifier extends Notifier<DashboardView> {
  @override
  DashboardView build() => DashboardView.tables;
  set state(DashboardView view) => super.state = view;
}

final dashboardViewProvider =
    NotifierProvider<DashboardViewNotifier, DashboardView>(DashboardViewNotifier.new);

// ── Zone filter on table grid ─────────────────────────────────────────────

class ZoneFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? id) => state = id;
}

final selectedZoneFilterProvider =
    NotifierProvider<ZoneFilterNotifier, int?>(ZoneFilterNotifier.new);

// ── Data Providers ────────────────────────────────────────────────────────

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getCategories();
});

final productsProvider = FutureProvider.family<List<Product>, int?>((ref, categoryId) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getProducts(categoryId: categoryId);
});

final tableZonesProvider = FutureProvider<List<TableZone>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getTableZones();
});

final tablesProvider = FutureProvider.autoDispose<List<TableModel>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  final zoneFilter = ref.watch(selectedZoneFilterProvider);
  return await repo.getTables(zoneId: zoneFilter);
});

final waitersProvider = FutureProvider.autoDispose<List<Waiter>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getWaiters();
});

final ordersProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  final filter = ref.watch(reportDateFilterProvider);
  return await repo.getAllOrders(from: filter.from, to: filter.to);
});

// ── Report date filter ────────────────────────────────────────────────────

class DateFilter {
  final DateTime? from;
  final DateTime? to;
  const DateFilter({this.from, this.to});
}

class DateFilterNotifier extends Notifier<DateFilter> {
  @override
  DateFilter build() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return DateFilter(from: start, to: end);
  }

  void set(DateFilter f) => state = f;
}

final reportDateFilterProvider =
    NotifierProvider<DateFilterNotifier, DateFilter>(DateFilterNotifier.new);

final activeOrderProvider =
    FutureProvider.autoDispose.family<OrderModel?, int>((ref, tableId) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getActiveOrderForTable(tableId);
});

final usersProvider = FutureProvider.autoDispose<List<AppUser>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getUsers();
});

// ── Active Order Service ──────────────────────────────────────────────────

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

final activeOrderServiceProvider =
    Provider.autoDispose((ref) => ActiveOrderService(ref));
