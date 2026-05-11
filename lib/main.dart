import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:st_george_pos/models/app_user.dart';
import 'package:st_george_pos/models/table_model.dart';
import 'package:st_george_pos/providers/pos_providers.dart';
import 'package:st_george_pos/screens/login_screen.dart';
import 'package:st_george_pos/screens/management_screens.dart';
import 'package:st_george_pos/screens/order_screen.dart';
import 'package:st_george_pos/screens/settings_screen.dart' hide SettingsScreen;
import 'package:st_george_pos/screens/table_management_screen.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/services/pos_repository.dart';
import 'package:st_george_pos/locales/app_localizations.dart';
import 'package:st_george_pos/widgets/language_switcher.dart';
import 'package:st_george_pos/screens/audit_logs_screen.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    final isDesktop =
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  final repo = PosRepository();
  await repo.init();

  // Initialize saved language and load it
  final savedLang = await AppLocalizations.getSavedLanguage();
  await AppLocalizations.load(savedLang);

  runApp(
    ProviderScope(
      overrides: [posRepositoryProvider.overrideWithValue(repo)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    return MaterialApp(
      title: 'St George Cafe POS',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4AF37),
          brightness: Brightness.light,
          primary: const Color(0xFFD4AF37),
          secondary: const Color(0xFF006B3C),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4AF37),
          brightness: Brightness.dark,
          primary: const Color(0xFFD4AF37),
          secondary: const Color(0xFF006B3C),
          surface: const Color(0xFF1A1A1A),
          background: const Color(0xFF121212),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

/// Watches auth state and routes to login or dashboard
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    if (user == null) return const LoginScreen();
    return const DashboardScreen();
  }
}

// ── Dashboard ─────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final user = ref.watch(authProvider)!;
    final isDirector = user.role == UserRole.director;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          ref.t('app.title'),
          style: const TextStyle(
            letterSpacing: 4,
            fontWeight: FontWeight.w900,
            color: Color(0xFFD4AF37),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        actions: [
          // Ethiopian calendar date display
          const EthiopianDateDisplay(),
          // Language switcher
          const LanguageSwitcher(),
          // Logged-in user chip
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.zero,
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Icon(
                  isDirector
                      ? Icons.admin_panel_settings_outlined
                      : Icons.point_of_sale,
                  size: 16,
                  color: isDirector ? const Color(0xFFD4AF37) : Colors.white54,
                ),
                const SizedBox(width: 6),
                Text(
                  user.username,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(tablesProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF121212), Color(0xFF003D22), Color(0xFF121212)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Row(
          children: [
            // Sidebar
            Container(
              width: 100,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                border: const Border(right: BorderSide(color: Colors.white10)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    _SidebarItem(
                      icon: Icons.dashboard_outlined,
                      label: ref.t('navigation.dashboard'),
                      isActive:
                          ref.watch(dashboardViewProvider) ==
                          DashboardView.home,
                      onTap: () =>
                          ref.read(dashboardViewProvider.notifier).state =
                              DashboardView.home,
                    ),
                    if (!isDirector) ...[
                      _SidebarItem(
                        icon: Icons.history,
                        label: ref.t('navigation.history'),
                        isActive:
                            ref.watch(dashboardViewProvider) ==
                            DashboardView.orders,
                        onTap: () =>
                            ref.read(dashboardViewProvider.notifier).state =
                                DashboardView.orders,
                      ),
                      _SidebarItem(
                        icon: Icons.pause_circle_outline,
                        label: ref.t('navigation.held'),
                        isActive:
                            ref.watch(dashboardViewProvider) ==
                            DashboardView.heldOrders,
                        onTap: () =>
                            ref.read(dashboardViewProvider.notifier).state =
                                DashboardView.heldOrders,
                      ),
                      _SidebarItem(
                        icon: Icons.restaurant_menu,
                        label: ref.t('navigation.menu'),
                        isActive:
                            ref.watch(dashboardViewProvider) ==
                            DashboardView.menu,
                        onTap: () =>
                            ref.read(dashboardViewProvider.notifier).state =
                                DashboardView.menu,
                      ),
                      _SidebarItem(
                        icon: Icons.people,
                        label: ref.t('navigation.waiters'),
                        isActive:
                            ref.watch(dashboardViewProvider) ==
                            DashboardView.waiters,
                        onTap: () =>
                            ref.read(dashboardViewProvider.notifier).state =
                                DashboardView.waiters,
                      ),
                    ],
                    _SidebarItem(
                      icon: Icons.calculate_outlined,
                      label: ref.t('navigation.charges'),
                      isActive:
                          ref.watch(dashboardViewProvider) ==
                          DashboardView.charges,
                      onTap: () =>
                          ref.read(dashboardViewProvider.notifier).state =
                              DashboardView.charges,
                    ),
                    _SidebarItem(
                      icon: Icons.bar_chart,
                      label: ref.t('navigation.reports'),
                      isActive:
                          ref.watch(dashboardViewProvider) ==
                          DashboardView.reports,
                      onTap: () =>
                          ref.read(dashboardViewProvider.notifier).state =
                              DashboardView.reports,
                    ),
                    if (isDirector) ...[
                      _SidebarItem(
                        icon: Icons.manage_accounts_outlined,
                        label: ref.t('navigation.users'),
                        isActive:
                            ref.watch(dashboardViewProvider) ==
                            DashboardView.users,
                        onTap: () =>
                            ref.read(dashboardViewProvider.notifier).state =
                                DashboardView.users,
                      ),
                      _SidebarItem(
                        icon: Icons.history_edu_outlined,
                        label: 'AUDIT',
                        isActive:
                            ref.watch(dashboardViewProvider) ==
                            DashboardView.auditLogs,
                        onTap: () =>
                            ref.read(dashboardViewProvider.notifier).state =
                                DashboardView.auditLogs,
                      ),
                      _SidebarItem(
                        icon: Icons.tune,
                        label: 'SETTINGS',
                        isActive:
                            ref.watch(dashboardViewProvider) ==
                                DashboardView.settings &&
                            isDirector,
                        onTap: () =>
                            ref.read(dashboardViewProvider.notifier).state =
                                DashboardView.settings,
                      ),
                    ],
                    const SizedBox(height: 40),
                    _SidebarItem(
                      icon: Icons.logout,
                      label: ref.t('navigation.logout'),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1A1A1A),
                            title: Text(ref.t('navigation.logout')),
                            content: Text(ref.t('auth.logoutConfirm')),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(ref.t('common.no')),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(ref.t('common.yes')),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          ref.read(authProvider.notifier).logout();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
                child: Consumer(
                  builder: (context, ref, _) {
                    final view = ref.watch(dashboardViewProvider);

                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.02, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                      child: _buildCurrentView(view, isDirector, ref),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentView(DashboardView view, bool isDirector, WidgetRef ref) {
    if (isDirector) {
      switch (view) {
        case DashboardView.tables:
          return const TableManagementScreen(key: ValueKey('tables'));
        case DashboardView.reports:
          return ReportsScreen(key: const ValueKey('reports'));
        case DashboardView.charges:
          return ChargeManagementScreen(key: const ValueKey('charges'));
        case DashboardView.users:
          return const UserManagementScreen(key: ValueKey('users'));
        case DashboardView.settings:
          return SettingsScreen(key: const ValueKey('settings'));
        case DashboardView.auditLogs:
          return const AuditLogsScreen(key: ValueKey('audit'));
        default:
          return const DashboardHomeScreen(key: ValueKey('home'));
      }
    }

    switch (view) {
      case DashboardView.home:
        return const DashboardHomeScreen(key: ValueKey('home'));
      case DashboardView.orders:
        return OrderHistoryScreen(key: const ValueKey('orders'));
      case DashboardView.heldOrders:
        return HeldOrdersScreen(key: const ValueKey('held_orders'));
      case DashboardView.menu:
        return MenuManagementScreen(key: const ValueKey('menu'));
      case DashboardView.waiters:
        return WaiterManagementScreen(key: const ValueKey('waiters'));
      case DashboardView.reports:
        return ReportsScreen(key: const ValueKey('reports'));
      case DashboardView.charges:
        return ChargeManagementScreen(key: const ValueKey('charges'));
      case DashboardView.pos:
        return const OrderScreen(key: ValueKey('pos'));
      case DashboardView.tables:
        return const TableManagementScreen(key: ValueKey('tables'));
      default:
        return const DashboardHomeScreen(key: ValueKey('home'));
    }
  }
}

class DashboardHomeScreen extends ConsumerWidget {
  const DashboardHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top Stats Row ──────────────────────────────────────────────────
        ordersAsync.when(
          data: (orders) {
            final today = DateTime.now();
            final todayOrders = orders
                .where(
                  (o) =>
                      o.createdAt.day == today.day &&
                      o.createdAt.month == today.month &&
                      o.createdAt.year == today.year,
                )
                .toList();

            final completedToday = todayOrders
                .where((o) => o.status == OrderStatus.completed)
                .toList();
            final revenueToday = completedToday.fold(
              0.0,
              (sum, o) => sum + o.grandTotal,
            );
            final pendingOrders = orders
                .where((o) => o.status == OrderStatus.pending)
                .toList();

            return Row(
              children: [
                _MiniStat(
                  label: 'REVENUE TODAY',
                  value:
                      '${revenueToday.toStringAsFixed(0)} ${ref.t('common.currency')}',
                  icon: Icons.payments,
                  color: const Color(0xFFD4AF37),
                ),
                const SizedBox(width: 24),
                _MiniStat(
                  label: 'COMPLETED',
                  value: '${completedToday.length}',
                  icon: Icons.task_alt,
                  color: const Color(0xFF22C55E),
                ),
                const SizedBox(width: 24),
                _MiniStat(
                  label: 'HELD ORDERS',
                  value: '${pendingOrders.length}',
                  icon: Icons.timer,
                  color: Colors.orangeAccent,
                ),
              ],
            );
          },
          loading: () => const SizedBox(height: 50),
          error: (e, _) => const SizedBox(),
        ),

        const SizedBox(height: 40),

        // ── Primary Action: New Order ────────────────────────────────────────
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: const Color(0xFFD4AF37).withOpacity(0.2),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 40,
                top: -20,
                child: Icon(
                  Icons.add_shopping_cart,
                  size: 220,
                  color: const Color(0xFFD4AF37).withOpacity(0.05),
                ),
              ),
              Positioned(
                right: 40,
                bottom: 60,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    elevation: 10,
                    shadowColor: const Color(0xFFD4AF37).withOpacity(0.5),
                  ),
                  icon: const Icon(Icons.add, size: 24, color: Colors.black),
                  label: const Text(
                    'START SERVICE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  onPressed: () {
                    ref.read(selectedTableProvider.notifier).set(null);
                    ref.read(dashboardViewProvider.notifier).state = DashboardView.pos;
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withOpacity(0.1),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Text(
                        'QUICK ACTION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFD4AF37),
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'START NEW ORDER',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    Text(
                      'Select a table and begin service',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white38,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 60),

        // ── Live Workspace: Held Orders ─────────────────────────────────────
        Row(
          children: [
            const Icon(
              Icons.layers_outlined,
              color: Color(0xFFD4AF37),
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text(
              'HELD ORDERS / PENDING BILLS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Colors.white70,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => ref.invalidate(ordersProvider),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('REFRESH', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: Colors.white24),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Expanded(
          child: ordersAsync.when(
            data: (orders) {
              final pending = orders
                  .where((o) => o.status == OrderStatus.pending)
                  .toList();
              if (pending.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 48,
                        color: Colors.white.withOpacity(0.05),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No pending orders at the moment.',
                        style: TextStyle(color: Colors.white12),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: pending.length,
                itemBuilder: (context, index) {
                  final order = pending[index];
                  return _HeldOrderDashboardListTile(order: order);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading orders: $e')),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white38,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _HeldOrderDashboardListTile extends ConsumerWidget {
  final OrderModel order;
  const _HeldOrderDashboardListTile({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diff = DateTime.now().difference(order.createdAt);
    final minutes = diff.inMinutes;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          final table = TableModel(
            id: order.tableId,
            name: order.tableName,
            status: TableStatus.occupied,
          );
          ref.read(selectedTableProvider.notifier).set(table);
          ref.read(dashboardViewProvider.notifier).state = DashboardView.pos;
        },
        child: GlassContainer(
          opacity: 0.05,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          child: Row(
            children: [
              // Icon & Table Info
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.1),
                  borderRadius: BorderRadius.zero,
                ),
                child: const Icon(Icons.table_bar, color: Color(0xFFD4AF37)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.tableName.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ref.t('bill.waiter')}: ${order.waiterName}  •  ${order.items.length} ITEMS',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),

              // Time Elapsed Flag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: minutes > 30 
                      ? Colors.redAccent.withOpacity(0.2) 
                      : minutes > 15 
                          ? Colors.orangeAccent.withOpacity(0.2)
                          : Colors.greenAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: minutes > 30 
                        ? Colors.redAccent 
                        : minutes > 15 
                            ? Colors.orangeAccent
                            : Colors.greenAccent.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 12,
                          color: minutes > 30 
                              ? Colors.redAccent 
                              : minutes > 15 
                                  ? Colors.orangeAccent
                                  : Colors.greenAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${minutes}M',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: minutes > 30 
                                ? Colors.redAccent 
                                : minutes > 15 
                                    ? Colors.orangeAccent
                                    : Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'WAITING',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: minutes > 30 
                            ? Colors.redAccent 
                            : minutes > 15 
                                ? Colors.orangeAccent
                                : Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // Total Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  const Text(
                    'ETB',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white38,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right, color: Colors.white12),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat Badge ────────────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF8B90A0)),
          ),
        ],
      ),
    );
  }
}

// ── Professional Table Card ───────────────────────────────────────────────

class _ProfessionalTableCard extends StatefulWidget {
  final TableModel table;
  final VoidCallback onTap;
  final String statusLabel;
  final String noZoneLabel;

  const _ProfessionalTableCard({
    required this.table,
    required this.onTap,
    required this.statusLabel,
    required this.noZoneLabel,
  });

  @override
  State<_ProfessionalTableCard> createState() => _ProfessionalTableCardState();
}

class _ProfessionalTableCardState extends State<_ProfessionalTableCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isOccupied = widget.table.status == TableStatus.occupied;
    final accentColor = isOccupied
        ? const Color(0xFFEF4444)
        : const Color(0xFF22C55E);
    final hoverColor = isOccupied
        ? const Color(0xFFEF4444).withOpacity(0.08)
        : const Color(0xFF22C55E).withOpacity(0.06);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: _hovered ? hoverColor : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hovered
                ? accentColor.withOpacity(0.5)
                : Colors.white.withOpacity(0.05),
            width: _hovered ? 1.5 : 1,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.12),
                    blurRadius: 16,
                  ),
                ]
              : [],
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: icon + status dot
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.table_restaurant,
                        size: 20,
                        color: accentColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.zero,
                        border: Border.all(color: accentColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            widget.statusLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Bottom: name + zone
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.table.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isOccupied ? Colors.white38 : Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.table.zoneName ?? widget.noZoneLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8B90A0),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sidebar Item ──────────────────────────────────────────────────────────

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            children: [
              Icon(
                icon,
                color: isActive ? const Color(0xFFD4AF37) : Colors.white54,
                size: 32,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? const Color(0xFFD4AF37) : Colors.white54,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
