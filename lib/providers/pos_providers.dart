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

enum DashboardView {
  home,
  tables,
  orders,
  heldOrders,
  menu,
  waiters,
  reports,
  settings,
  users,
  zones,
  newOrder,
}

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
    NotifierProvider<DashboardViewNotifier, DashboardView>(
      DashboardViewNotifier.new,
    );

// ── Zone filter on table grid ─────────────────────────────────────────────

class ZoneFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? id) => state = id;
}

final selectedZoneFilterProvider = NotifierProvider<ZoneFilterNotifier, int?>(
  ZoneFilterNotifier.new,
);

class SearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String val) => state = val;
}

final productSearchProvider = NotifierProvider<SearchNotifier, String>(
  SearchNotifier.new,
);
final orderSearchProvider = NotifierProvider<SearchNotifier, String>(
  SearchNotifier.new,
);
final userSearchProvider = NotifierProvider<SearchNotifier, String>(
  SearchNotifier.new,
);

// ── Data Providers ────────────────────────────────────────────────────────

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getCategories();
});

final productsProvider = FutureProvider.family<List<Product>, int?>((
  ref,
  categoryId,
) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getProducts(categoryId: categoryId);
});

class SelectedCategoryNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? id) => state = id;
}

final selectedCategoryProvider =
    NotifierProvider<SelectedCategoryNotifier, int?>(
      SelectedCategoryNotifier.new,
    );

final tableZonesProvider = FutureProvider<List<TableZone>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getTableZones();
});

final tablesProvider = FutureProvider.autoDispose<List<TableModel>>((
  ref,
) async {
  final repo = ref.watch(posRepositoryProvider);
  final zoneFilter = ref.watch(selectedZoneFilterProvider);
  return await repo.getTables(zoneId: zoneFilter);
});

final waitersProvider = FutureProvider.autoDispose<List<Waiter>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getWaiters();
});

final ordersProvider = FutureProvider.autoDispose<List<OrderModel>>((
  ref,
) async {
  final repo = ref.watch(posRepositoryProvider);
  final filter = ref.watch(reportDateFilterProvider);
  return await repo.getAllOrders(from: filter.from, to: filter.to);
});

final activeOrdersProvider = FutureProvider.autoDispose<List<OrderModel>>((
  ref,
) async {
  final repo = ref.watch(posRepositoryProvider);
  final allOrders = await repo.getAllOrders();
  return allOrders
      .where(
        (o) => o.status == OrderStatus.pending || o.status == OrderStatus.held,
      )
      .toList();
});

final todaysOrdersProvider = FutureProvider.autoDispose<List<OrderModel>>((
  ref,
) async {
  final repo = ref.watch(posRepositoryProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  return await repo.getAllOrders(from: today, to: tomorrow);
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

class WaiterFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? waiterId) => state = waiterId;
}

final reportWaiterFilterProvider = NotifierProvider<WaiterFilterNotifier, int?>(
  WaiterFilterNotifier.new,
);

final activeOrderProvider = FutureProvider.autoDispose
    .family<OrderModel?, int?>((ref, tableId) async {
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

final activeOrderServiceProvider = Provider.autoDispose(
  (ref) => ActiveOrderService(ref),
);

// ── Report Analytics ──────────────────────────────────────────────────────

class ReportAnalytics {
  final Map<String, ({int qty, double revenue})> topProducts;
  final Map<String, double> dailySales;
  final Map<String, ({double revenue, int orders})> waiterPerformance;
  final Map<String, double> categorySales;
  final Map<int, double> hourlySales;
  final Map<String, Map<String, double>> waiterCategorySales;
  final double avgOrderValue;
  final String? mostSoldItem;

  ReportAnalytics({
    required this.topProducts,
    required this.dailySales,
    required this.waiterPerformance,
    required this.categorySales,
    required this.hourlySales,
    required this.waiterCategorySales,
    required this.avgOrderValue,
    this.mostSoldItem,
  });
}

final reportAnalyticsProvider = Provider.autoDispose<ReportAnalytics?>((ref) {
  final ordersAsync = ref.watch(ordersProvider);
  return ordersAsync.when(
    data: (list) {
      final completed = list
          .where((o) => o.status == OrderStatus.completed)
          .toList();

      final products = <String, ({int qty, double revenue})>{};
      final daily = <String, double>{};
      final waiters = <String, ({double revenue, int orders})>{};
      final categories = <String, double>{};
      final hourly = <int, double>{};
      final waiterCats = <String, Map<String, double>>{};

      for (final o in completed) {
        // Daily
        final dateKey =
            '${o.createdAt.year}-${o.createdAt.month}-${o.createdAt.day}';
        daily[dateKey] = (daily[dateKey] ?? 0) + o.grandTotal;

        // Hourly
        final hour = o.createdAt.hour;
        hourly[hour] = (hourly[hour] ?? 0) + o.grandTotal;

        // Waiter
        final wName = o.waiterName;
        final wData = waiters[wName] ?? (revenue: 0.0, orders: 0);
        waiters[wName] = (
          revenue: wData.revenue + o.grandTotal,
          orders: wData.orders + 1,
        );

        // Waiter Category
        if (!waiterCats.containsKey(wName)) waiterCats[wName] = {};

        // Products & Categories
        for (final item in o.items) {
          final pName = item.productName;
          final pData = products[pName] ?? (qty: 0, revenue: 0.0);
          products[pName] = (
            qty: pData.qty + item.quantity,
            revenue: pData.revenue + item.subtotal,
          );

          final catName = item.categoryName ?? 'Other';
          categories[catName] = (categories[catName] ?? 0) + item.subtotal;

          waiterCats[wName]![catName] =
              (waiterCats[wName]![catName] ?? 0) + item.subtotal;
        }
      }

      final totalRevenue = completed.fold(0.0, (sum, o) => sum + o.grandTotal);
      final avgValue = completed.isEmpty
          ? 0.0
          : totalRevenue / completed.length;

      String? mostSold;
      int maxQty = 0;
      products.forEach((name, data) {
        if (data.qty > maxQty) {
          maxQty = data.qty;
          mostSold = name;
        }
      });

      return ReportAnalytics(
        topProducts: products,
        dailySales: daily,
        waiterPerformance: waiters,
        categorySales: categories,
        hourlySales: hourly,
        waiterCategorySales: waiterCats,
        avgOrderValue: avgValue,
        mostSoldItem: mostSold,
      );
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
