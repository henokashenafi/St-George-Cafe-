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
import 'package:st_george_pos/models/settings.dart';

enum DashboardView { home, tables, orders, menu, waiters, reports, settings, users }

// ── Repository & Services ─────────────────────────────────────────────────

final posRepositoryProvider = Provider((ref) => PosRepository());


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

final appSettingsProvider = FutureProvider<Map<String, String>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getSettings();
});

final cafeSettingsProvider = FutureProvider<CafeSettings>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getCafeSettings();
});

// ── Dashboard View ────────────────────────────────────────────────────────

class DashboardViewNotifier extends Notifier<DashboardView> {
  @override
  DashboardView build() => DashboardView.home;
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

final activeOrderProvider = FutureProvider.autoDispose.family<OrderModel?, int?>((ref, tableId) async {
  if (tableId == null) return null;
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

  Future<void> refreshTableData(int? tableId) async {
    if (tableId != null) {
      ref.invalidate(activeOrderProvider(tableId));
    }
    ref.invalidate(tablesProvider);
    ref.invalidate(ordersProvider); // To refresh dashboard stats
  }

  Future<OrderModel?> createNewOrder(OrderModel order) async {
    final id = await repo.createOrder(order);
    await refreshTableData(order.tableId);
    // Fetch the newly created order
    return await repo.getActiveOrderForTable(order.tableId);
  }

  Future<int> addItems(int orderId, List<OrderItem> items, int? tableId) async {
    final roundNumber = await repo.addItemsToOrder(orderId, items);
    await refreshTableData(tableId);
    return roundNumber;
  }

  Future<void> saveSettings(CafeSettings settings) async {
    await repo.saveSettings(settings);
    ref.invalidate(cafeSettingsProvider);
  }
}

final activeOrderServiceProvider =
    Provider.autoDispose((ref) => ActiveOrderService(ref));
