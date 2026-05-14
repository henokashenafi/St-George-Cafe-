import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/models/app_user.dart';
import 'package:st_george_pos/models/category.dart';
import 'package:st_george_pos/models/product.dart';
import 'package:st_george_pos/models/table_model.dart';
import 'package:st_george_pos/models/table_zone.dart';
import 'package:st_george_pos/models/waiter.dart';
import '../models/charge.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:st_george_pos/services/pos_repository.dart';
import 'package:st_george_pos/models/settings.dart';
import 'package:st_george_pos/models/shift.dart';
import 'package:st_george_pos/models/z_report.dart';
import 'package:st_george_pos/models/station.dart';

enum DashboardView { home, tables, orders, heldOrders, menu, waiters, reports, settings, users, auditLogs, pos, charges, systemLogs }

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

class SelectedTableNotifier extends Notifier<TableModel?> {
  @override
  TableModel? build() => null;
  void set(TableModel? table) => state = table;
}

final selectedTableProvider =
    NotifierProvider<SelectedTableNotifier, TableModel?>(SelectedTableNotifier.new);

// ── Data Providers ────────────────────────────────────────────────────────

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getCategories();
});

final productsProvider = FutureProvider.family<List<Product>, int?>((ref, categoryId) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getProducts(categoryId: categoryId);
});

final stationsProvider = FutureProvider<List<Station>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getStations();
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
  final String label;

  const DateFilter({this.from, this.to, this.label = 'Custom'});

  static DateFilter today() {
    final now = DateTime.now();
    return DateFilter(
      from: DateTime(now.year, now.month, now.day),
      to: DateTime(now.year, now.month, now.day, 23, 59, 59),
      label: 'TODAY',
    );
  }

  static DateFilter yesterday() {
    final yest = DateTime.now().subtract(const Duration(days: 1));
    return DateFilter(
      from: DateTime(yest.year, yest.month, yest.day),
      to: DateTime(yest.year, yest.month, yest.day, 23, 59, 59),
      label: 'YESTERDAY',
    );
  }

  static DateFilter thisWeek() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    return DateFilter(
      from: DateTime(start.year, start.month, start.day),
      to: now,
      label: 'THIS WEEK',
    );
  }

  static DateFilter thisMonth() {
    final now = DateTime.now();
    return DateFilter(
      from: DateTime(now.year, now.month, 1),
      to: DateTime(now.year, now.month, now.day, 23, 59, 59),
      label: 'THIS MONTH',
    );
  }

  static DateFilter allTime() {
    return const DateFilter(
      from: null,
      to: null,
      label: 'ALL TIME',
    );
  }
}

class DateFilterNotifier extends Notifier<DateFilter> {
  @override
  DateFilter build() => DateFilter.today();

  void set(DateFilter f) => state = f;
}

final reportDateFilterProvider =
    NotifierProvider<DateFilterNotifier, DateFilter>(DateFilterNotifier.new);

enum DateFilterType { today, week, month, all, custom }

class DateTypeNotifier extends Notifier<DateFilterType> {
  @override
  DateFilterType build() => DateFilterType.today;
  void set(DateFilterType t) => state = t;
}

final reportDateTypeProvider =
    NotifierProvider<DateTypeNotifier, DateFilterType>(DateTypeNotifier.new);

class WaiterFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? id) => state = id;
}

final reportWaiterFilterProvider =
    NotifierProvider<WaiterFilterNotifier, int?>(WaiterFilterNotifier.new);

final zReportsProvider = FutureProvider.autoDispose<List<ZReportModel>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getZReports();
});

final activeOrderProvider = FutureProvider.autoDispose.family<OrderModel?, int?>((ref, tableId) async {
  if (tableId == null) return null;
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getActiveOrderForTable(tableId);
});

final usersProvider = FutureProvider.autoDispose<List<AppUser>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getUsers();
});

final auditLogsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getAuditLogs();
});

final currentShiftProvider = FutureProvider.autoDispose<ShiftModel?>((ref) async {
  final user = ref.watch(authProvider);
  if (user == null) return null;
  final repo = ref.watch(posRepositoryProvider);
  return await repo.getActiveShift(user.id!);
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
    // Inject current shift ID if available
    final user = ref.read(authProvider);
    int? shiftId;
    if (user != null) {
      final shift = await repo.getActiveShift(user.id!);
      shiftId = shift?.id;
    }
    
    final id = await repo.createOrder(order.copyWith(shiftId: shiftId));
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

  Future<void> startShift(double startingCash) async {
    final user = ref.read(authProvider);
    if (user != null) {
      await repo.startShift(user.id!, startingCash);
      ref.invalidate(currentShiftProvider);
    }
  }

  Future<void> endShift(int shiftId, double actualCash) async {
    final reportData = await repo.getShiftReportData(shiftId);
    await repo.createZReport(shiftId, reportData);
    await repo.endShift(shiftId, actualCash);
    ref.invalidate(currentShiftProvider);
  }
}

final activeOrderServiceProvider =
    Provider((ref) => ActiveOrderService(ref));

// --- Dynamic Charges Provider ---
final chargesProvider = FutureProvider<List<ChargeModel>>((ref) async {
  final repo = ref.watch(posRepositoryProvider);
  final data = await repo.getCharges();
  return data.map((e) => ChargeModel.fromMap(e)).toList();
});

class ChargesNotifier extends Notifier<AsyncValue<List<ChargeModel>>> {
  @override
  AsyncValue<List<ChargeModel>> build() {
    _load();
    return const AsyncValue.loading();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(posRepositoryProvider);
      final data = await repo.getCharges();
      state = AsyncValue.data(data.map((e) => ChargeModel.fromMap(e)).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(ChargeModel charge) async {
    await ref.read(posRepositoryProvider).addCharge(charge.toMap());
    await _load();
  }

  Future<void> update(ChargeModel charge) async {
    if (charge.id != null) {
      await ref.read(posRepositoryProvider).updateCharge(charge.id!, charge.toMap());
      await _load();
    }
  }

  Future<void> delete(int id) async {
    await ref.read(posRepositoryProvider).deleteCharge(id);
    await _load();
  }
}

final chargesListProvider = NotifierProvider<ChargesNotifier, AsyncValue<List<ChargeModel>>>(ChargesNotifier.new);
