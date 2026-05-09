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
import 'package:st_george_pos/screens/table_management_screen.dart';
import 'package:st_george_pos/screens/zone_management_screen.dart';
import 'package:st_george_pos/screens/settings_screen.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/services/pos_repository.dart';
import 'package:st_george_pos/locales/app_localizations.dart';
import 'package:st_george_pos/providers/order_workflow_provider.dart';
import 'package:st_george_pos/widgets/language_switcher.dart';

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

  // Initialize calendar type setting
  await CalendarSettings.load();

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
      title: ref.t('app.title'),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
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
          // Calendar date display
          const CalendarDateDisplay(),
          // Calendar switcher
          const CalendarSwitcher(),
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
                    _SidebarItem(
                      icon: Icons.add_shopping_cart,
                      label: ref.t('navigation.newOrder'),
                      isActive:
                          ref.watch(dashboardViewProvider) ==
                          DashboardView.newOrder,
                      onTap: () =>
                          ref.read(dashboardViewProvider.notifier).state =
                              DashboardView.newOrder,
                    ),
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
                    if (isDirector) ...[
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
                    ],
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
                    _SidebarItem(
                      icon: Icons.map_outlined,
                      label: ref.t('navigation.zones'),
                      isActive:
                          ref.watch(dashboardViewProvider) ==
                          DashboardView.zones,
                      onTap: () =>
                          ref.read(dashboardViewProvider.notifier).state =
                              DashboardView.zones,
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
                    ],
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
                        icon: Icons.settings,
                        label: ref.t('navigation.settings'),
                        isActive:
                            ref.watch(dashboardViewProvider) ==
                            DashboardView.settings,
                        onTap: () =>
                            ref.read(dashboardViewProvider.notifier).state =
                                DashboardView.settings,
                      ),
                    ],
                    const SizedBox(height: 40),
                    _SidebarItem(
                      icon: Icons.logout,
                      label: ref.t('navigation.logout'),
                      onTap: () => ref.read(authProvider.notifier).logout(),
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
                    final user = ref.watch(authProvider)!;
                    final isDirector = user.role == UserRole.director;

                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
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
    switch (view) {
      case DashboardView.home:
        return const DashboardHomeScreen(key: ValueKey('home'));
      case DashboardView.newOrder:
        return const OrderScreen(key: ValueKey('newOrder'));
      case DashboardView.orders:
        return const OrderHistoryScreen(key: ValueKey('orders'));
      case DashboardView.heldOrders:
        return const HeldOrdersScreen(key: ValueKey('held_orders'));
      case DashboardView.menu:
        if (!isDirector)
          return const DashboardHomeScreen(key: ValueKey('home'));
        return const MenuManagementScreen(key: ValueKey('menu'));
      case DashboardView.waiters:
        return const WaiterManagementScreen(key: ValueKey('waiters'));
      case DashboardView.reports:
        return const ReportsScreen(key: ValueKey('reports'));
      case DashboardView.users:
        if (!isDirector)
          return const DashboardHomeScreen(key: ValueKey('home'));
        return const UserManagementScreen(key: ValueKey('users'));
      case DashboardView.settings:
        return const GlobalSettingsScreen(key: ValueKey('settings'));
      case DashboardView.zones:
        return const ZoneManagementScreen(key: ValueKey('zones'));
      default:
        return const DashboardHomeScreen(key: ValueKey('home'));
    }
  }
}

class DashboardHomeScreen extends ConsumerWidget {
  const DashboardHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(tablesProvider);
    final analytics = ref.watch(reportAnalyticsProvider);
    final user = ref.watch(authProvider)!;
    final isDirector = user.role == UserRole.director;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ref.t('main.title'),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 30),
        // Quick stats
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _DashboardCard(
                title: ref.t('main.activeTables'),
                child: ref
                    .watch(activeOrdersProvider)
                    .when(
                      data: (orders) {
                        if (orders.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.nightlife_outlined,
                                  size: 40,
                                  color: Colors.white24,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  ref.t('main.noActiveTables'),
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: orders.length,
                          itemBuilder: (ctx, i) => _ActiveTableTile(
                            order: orders[i],
                            currency: ref.t('common.currency'),
                            onTap: () {
                              if (isDirector) return;
                              ref
                                  .read(orderWorkflowProvider.notifier)
                                  .initializeForTable(orders[i].tableId);
                              ref
                                  .read(activeOrderServiceProvider)
                                  .refreshTableData(orders[i].tableId);
                              ref.read(dashboardViewProvider.notifier).state =
                                  DashboardView.newOrder;
                            },
                          ),
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('${ref.t('common.error')}: $e'),
                    ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 1,
              child: _DashboardCard(
                title: ref.t('main.todayOverview'),
                child: ref
                    .watch(todaysOrdersProvider)
                    .when(
                      data: (todayOrders) {
                        final totalRevenue = todayOrders.fold(
                          0.0,
                          (sum, order) => sum + order.grandTotal,
                        );
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _StatCard(
                              title: ref.t('main.ordersCompleted'),
                              value: '${todayOrders.length}',
                              icon: Icons.check_circle_outline,
                            ),
                            const SizedBox(height: 12),
                            _StatCard(
                              title: ref.t('main.totalRevenue'),
                              value:
                                  '${totalRevenue.toStringAsFixed(2)} ${ref.t('common.currency')}',
                              icon: Icons.payments_outlined,
                              color: const Color(0xFFD4AF37),
                            ),
                          ],
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('${ref.t('common.error')}: $e'),
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        // Reports Quick Review
        if (isDirector && analytics != null) ...[
          Text(
            ref.t('management.quickReview').toUpperCase(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GlassContainer(
                  opacity: 0.05,
                  borderRadius: 16,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 16,
                            color: Color(0xFFD4AF37),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            ref.t('management.topProducts'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...(analytics.topProducts.entries.toList()..sort(
                            (a, b) => b.value.qty.compareTo(a.value.qty),
                          ))
                          .take(3)
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    e.key,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  Text(
                                    '${e.value.qty}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: GlassContainer(
                  opacity: 0.05,
                  borderRadius: 16,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 16,
                            color: Color(0xFFD4AF37),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            ref.t('management.topWaiters'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...(analytics.waiterPerformance.entries.toList()..sort(
                            (a, b) =>
                                b.value.revenue.compareTo(a.value.revenue),
                          ))
                          .take(3)
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    e.key,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  Text(
                                    '${e.value.revenue.toStringAsFixed(0)} ${ref.t('common.currency')}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 30),
        // Mini stats bar
        ref
            .watch(tablesProvider)
            .when(
              data: (allTables) {
                final available = allTables
                    .where((t) => t.status == TableStatus.available)
                    .length;
                final occupied = allTables
                    .where((t) => t.status == TableStatus.occupied)
                    .length;
                return ref
                    .watch(waitersProvider)
                    .when(
                      data: (allWaiters) {
                        final totalTables = allTables.length;
                        final waitersOnDuty = allWaiters.length;
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _MiniStatCard(
                                icon: Icons.table_restaurant,
                                value: '$totalTables',
                                label: ref.t(
                                  'main.overviewTables',
                                  replacements: {'total': '$totalTables'},
                                ),
                              ),
                              const SizedBox(width: 16),
                              _MiniStatCard(
                                icon: Icons.check_circle_outline,
                                value: '$available',
                                label: ref.t(
                                  'main.overviewAvailable',
                                  replacements: {'count': '$available'},
                                ),
                                color: const Color(0xFF4CAF50),
                              ),
                              const SizedBox(width: 16),
                              _MiniStatCard(
                                icon: Icons.room_service,
                                value: '$occupied',
                                label: ref.t(
                                  'main.overviewOccupied',
                                  replacements: {'count': '$occupied'},
                                ),
                                color: const Color(0xFFD4AF37),
                              ),
                              const SizedBox(width: 16),
                              _MiniStatCard(
                                icon: Icons.person,
                                value: '$waitersOnDuty',
                                label: ref.t(
                                  'main.overviewWaiters',
                                  replacements: {'count': '$waitersOnDuty'},
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => const SizedBox(),
                      error: (e, _) => const SizedBox(),
                    );
              },
              loading: () => const SizedBox(),
              error: (e, _) => const SizedBox(),
            ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  const _MiniStatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.05,
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color ?? Colors.white54),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color ?? Colors.white,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveTableTile extends ConsumerWidget {
  final OrderModel order;
  final VoidCallback onTap;
  final String? currency;

  const _ActiveTableTile({
    required this.order,
    required this.onTap,
    this.currency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayCurrency = currency ?? ref.t('common.currency');
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 16),
      child: GlassContainer(
        opacity: 0.1,
        borderRadius: 16,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${order.id}',
                        style: const TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.receipt_long,
                      size: 16,
                      color: Colors.white24,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  order.tableName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  order.waiterName ?? '',
                  style: const TextStyle(fontSize: 13, color: Colors.white54),
                ),
                const Spacer(),
                Text(
                  '${order.totalAmount.toStringAsFixed(2)} $displayCurrency',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFD4AF37),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _DashboardCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(height: 220, child: child),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.05,
      borderRadius: 16,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (color ?? Colors.white).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color ?? Colors.white70, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, color: Colors.white54),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: color ?? Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableSelectorDialog extends ConsumerStatefulWidget {
  const _TableSelectorDialog();

  @override
  ConsumerState<_TableSelectorDialog> createState() =>
      _TableSelectorDialogState();
}

class _TableSelectorDialogState extends ConsumerState<_TableSelectorDialog> {
  int? _selectedZoneId;
  String _search = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tablesAsync = ref.watch(tablesProvider);
    final zonesAsync = ref.watch(tableZonesProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        opacity: 0.15,
        borderRadius: 24,
        child: Container(
          width: 900,
          height: 600,
          child: Row(
            children: [
              _buildZoneSidebar(zonesAsync),
              Expanded(
                child: Column(
                  children: [
                    _buildHeader(tablesAsync),
                    _buildSearchBar(),
                    const SizedBox(height: 4),
                    Expanded(child: _buildTableGrid(tablesAsync)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoneSidebar(AsyncValue zonesAsync) {
    return Container(
      width: 200,
      decoration: const BoxDecoration(
        color: Color(0xFF13161F),
        border: Border(right: BorderSide(color: Color(0xFF1E2130))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      ref.t('zones.title'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: Color(0xFF8B90A0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _ZoneTile(
            label: ref.t('zones.allTables'),
            icon: Icons.grid_view_rounded,
            isSelected: _selectedZoneId == null,
            onTap: () => setState(() => _selectedZoneId = null),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: zonesAsync.maybeWhen(
              data: (zones) => ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: (zones as List).length,
                itemBuilder: (_, i) {
                  final z = zones[i];
                  return _ZoneTile(
                    label: z.name,
                    icon: Icons.map_outlined,
                    isSelected: _selectedZoneId == z.id,
                    onTap: () => setState(() => _selectedZoneId = z.id),
                  );
                },
              ),
              orElse: () => const SizedBox(),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 16),
              label: Text(ref.t('common.cancel')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AsyncValue tablesAsync) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E2130))),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ref.t('tableSelector.title'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
              Text(
                _selectedZoneId == null
                    ? ref.t('zones.allTables')
                    : ref.t('zones.filteredByZone'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF8B90A0)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 6),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D27),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2C3044)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search, color: Color(0xFF8B90A0), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: ref.t('tableSelector.searchHint'),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableGrid(AsyncValue tablesAsync) {
    return tablesAsync.when(
      data: (tables) {
        var filtered = (tables as List<TableModel>);
        if (_selectedZoneId != null)
          filtered = filtered
              .where((t) => t.zoneId == _selectedZoneId)
              .toList();
        if (_search.isNotEmpty)
          filtered = filtered
              .where((t) => t.name.toLowerCase().contains(_search))
              .toList();

        return GridView.builder(
          padding: const EdgeInsets.all(28),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _ProfessionalTableCard(
            table: filtered[i],
            statusLabel: filtered[i].status == TableStatus.occupied
                ? ref.t('tableSelector.busy')
                : ref.t('tableSelector.free'),
            noZoneLabel: ref.t('tableSelector.noZone'),
            onTap: () => Navigator.pop(context, filtered[i]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

// ── Zone Tile (sidebar item) ──────────────────────────────────────────────

class _ZoneTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ZoneTile({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected
            ? const Color(0xFFD4AF37).withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? const Color(0xFFD4AF37)
                      : const Color(0xFF8B90A0),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isSelected
                          ? const Color(0xFFD4AF37)
                          : const Color(0xFF8B90A0),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD4AF37),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
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
      cursor: isOccupied
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: _hovered ? hoverColor : const Color(0xFF1A1D27),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hovered
                ? accentColor.withOpacity(0.5)
                : const Color(0xFF2C3044),
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
          onTap: isOccupied ? null : widget.onTap,
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

IconData _getCategoryIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('drink') || n.contains('beverage')) return Icons.local_cafe;
  if (n.contains('food')) return Icons.restaurant;
  if (n.contains('fasting')) return Icons.eco;
  if (n.contains('non')) return Icons.kebab_dining;
  return Icons.fastfood;
}
