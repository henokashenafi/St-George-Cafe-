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
import 'package:st_george_pos/screens/table_management_screen.dart';
import 'package:st_george_pos/screens/zone_management_screen.dart';
import 'package:st_george_pos/screens/new_order_screen.dart';
import 'package:st_george_pos/screens/settings_screen.dart' hide SettingsScreen;
import 'package:st_george_pos/screens/table_management_screen.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/services/pos_repository.dart';
import 'package:st_george_pos/locales/app_localizations.dart';
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

  runApp(
    ProviderScope(
      overrides: [posRepositoryProvider.overrideWithValue(repo)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'St George Cafe POS',
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
                    if (!isDirector) _SidebarItem(
                      icon: Icons.add_shopping_cart,
                      label: ref.t('navigation.newOrder'),
                      isActive:
                          ref.watch(dashboardViewProvider) ==
                          DashboardView.newOrder,
                      onTap: () =>
                          ref.read(dashboardViewProvider.notifier).state =
                              DashboardView.newOrder,
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
                      if (isDirector) _SidebarItem(
                        icon: Icons.dashboard_outlined,
                        label: ref.t('navigation.zones'),
                        isActive:
                            ref.watch(dashboardViewProvider) ==
                            DashboardView.zones,
                        onTap: () =>
                            ref.read(dashboardViewProvider.notifier).state =
                                DashboardView.zones,
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
                      icon: Icons.tune,
                      label: ref.t('navigation.settings'),
                      isActive:
                          ref.watch(dashboardViewProvider) ==
                          DashboardView.settings,
                      onTap: () =>
                          ref.read(dashboardViewProvider.notifier).state =
                              DashboardView.settings,
                    ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startNewOrderFlowFromDashboard(context, ref),
        backgroundColor: const Color(0xFFD4AF37),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: Text(
          ref.t('dashboard.newOrder'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView(DashboardView view, bool isDirector, WidgetRef ref) {
    if (isDirector) {
      switch (view) {
        case DashboardView.reports:
          return const ReportsScreen(key: ValueKey('reports'));
        case DashboardView.users:
          return const UserManagementScreen(key: ValueKey('users'));
        case DashboardView.settings:
          return const SettingsScreen(key: ValueKey('settings'));
        case DashboardView.zones:
          return const ZoneManagementScreen(key: ValueKey('zones'));
        default:
          return const DashboardHomeScreen(key: ValueKey('home'));
      }
    }

    switch (view) {
      case DashboardView.home:
        return const DashboardHomeScreen(key: ValueKey('home'));
      case DashboardView.orders:
        return const OrderHistoryScreen(key: ValueKey('orders'));
      case DashboardView.heldOrders:
        return const HeldOrdersScreen(key: ValueKey('held_orders'));
      case DashboardView.menu:
        return const MenuManagementScreen(key: ValueKey('menu'));
      case DashboardView.waiters:
        return const WaiterManagementScreen(key: ValueKey('waiters'));
      case DashboardView.reports:
        return const ReportsScreen(key: ValueKey('reports'));
      case DashboardView.settings:
        return const TableManagementScreen(key: ValueKey('settings'));
      case DashboardView.zones:
        return const ZoneManagementScreen(key: ValueKey('zones'));
      case DashboardView.newOrder:
        return const NewOrderScreen(key: ValueKey('newOrder'));
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
    final ordersAsync = ref.watch(ordersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ref.t('dashboard.title'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 24),

        InkWell(
          onTap: () => _startNewOrderFlowFromDashboard(context, ref),
          child: SizedBox(
            height: 160,
            width: double.infinity,
            child: GlassContainer(
              opacity: 0.1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_shopping_cart,
                      size: 48,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  const SizedBox(width: 32),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.t('dashboard.startNewOrder'),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: Color(0xFFD4AF37),
                        ),
                      ),
                      Text(
                        ref.t('dashboard.startNewOrderSubtitle'),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ref.t('dashboard.activeTables'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 12),
                  tablesAsync.when(
                    data: (tables) {
                      final occupied = tables
                          .where((t) => t.status == TableStatus.occupied)
                          .toList();
                      if (occupied.isEmpty) {
                        return SizedBox(
                          height: 200,
                          child: GlassContainer(
                            opacity: 0.05,
                            child: Center(
                              child: Text(
                                ref.t('dashboard.noActiveTables'),
                                style: const TextStyle(color: Colors.white24),
                              ),
                            ),
                          ),
                        );
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              childAspectRatio: 1.2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: occupied.length,
                        itemBuilder: (context, index) {
                          final table = occupied[index];
                          return GlassContainer(
                            opacity: 0.2,
                            border: Border.all(
                              color: const Color(0xFF006B3C).withOpacity(0.5),
                              width: 2,
                            ),
                            child: InkWell(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => OrderScreen(table: table),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.table_bar,
                                    size: 32,
                                    color: Color(0xFFD4AF37),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    table.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    table.zoneName ?? '',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('${ref.t('errors.error')}: $e'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 32),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ref.t('dashboard.todayOverview'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ordersAsync.when(
                    data: (orders) {
                      final today = DateTime.now();
                      final todayOrders = orders
                          .where(
                            (o) =>
                                o.createdAt.day == today.day &&
                                o.createdAt.month == today.month &&
                                o.createdAt.year == today.year &&
                                o.status == OrderStatus.completed,
                          )
                          .toList();

                      final totalRevenue = todayOrders.fold(
                        0.0,
                        (sum, o) => sum + o.grandTotal,
                      );

                      return Column(
                        children: [
                          _StatCard(
                            title: ref.t('dashboard.ordersCompleted'),
                            value: '${todayOrders.length}',
                            icon: Icons.check_circle_outline,
                          ),
                          const SizedBox(height: 16),
                          _StatCard(
                            title: ref.t('dashboard.totalRevenue'),
                            value: '${totalRevenue.toStringAsFixed(2)} ETB',
                            icon: Icons.payments_outlined,
                            color: const Color(0xFFD4AF37),
                          ),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('${ref.t('errors.error')}: $e'),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(20),
      opacity: 0.1,
      child: Row(
        children: [
          Icon(icon, size: 32, color: color ?? Colors.white38),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color ?? Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Professional Table Selector Dialog ────────────────────────────────────

void _startNewOrderFlowFromDashboard(
  BuildContext context,
  WidgetRef ref,
) async {
  final selectedTable = await showDialog<TableModel>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => const _TableSelectorDialog(),
  );

  if (selectedTable != null && context.mounted) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderScreen(table: selectedTable)),
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
  final _searchCtrl = TextEditingController();
  int? _selectedZoneId;
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tablesAsync = ref.watch(tablesProvider);
    final zonesAsync = ref.watch(tableZonesProvider);
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: screenSize.width * 0.88,
        height: screenSize.height * 0.88,
        decoration: BoxDecoration(
          color: const Color(0xFF0F1117),
          borderRadius: BorderRadius.zero,
          border: Border.all(color: Colors.white.withOpacity(0.07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 60,
              spreadRadius: 10,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: Row(
            children: [
              // ── Zone Sidebar ─────────────────────────────────────────
              _buildZoneSidebar(zonesAsync),

              // ── Main Content ─────────────────────────────────────────
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

  // ── Zone Sidebar ───────────────────────────────────────────────────────

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
                      ref.t('dashboard.zones'),
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
          // Close button
          Container(
            padding: const EdgeInsets.all(16),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white38,
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 16),
              label: Text(
                ref.t('dashboard.cancel'),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header with live stats ─────────────────────────────────────────────

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
                ref.t('dashboard.selectTable'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _selectedZoneId == null
                    ? ref.t('zones.allTables')
                    : ref.t('zones.filteredByZone'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF8B90A0)),
              ),
            ],
          ),
          const Spacer(),
          // Live stats
          tablesAsync.maybeWhen(
            data: (tables) {
              final all = tables as List;
              final available = all
                  .where((t) => t.status == TableStatus.available)
                  .length;
              final occupied = all
                  .where((t) => t.status == TableStatus.occupied)
                  .length;
              return Row(
                children: [
                  _StatBadge(
                    label: ref.t('dashboard.available'),
                    count: available,
                    color: const Color(0xFF22C55E),
                  ),
                  const SizedBox(width: 12),
                  _StatBadge(
                    label: ref.t('dashboard.occupied'),
                    count: occupied,
                    color: const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 12),
                  _StatBadge(
                    label: ref.t('dashboard.total'),
                    count: all.length,
                    color: const Color(0xFFD4AF37),
                  ),
                ],
              );
            },
            orElse: () => const SizedBox(),
          ),
        ],
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────

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
                autofocus: false,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search table name...',
                  hintStyle: TextStyle(color: Color(0xFF8B90A0), fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
              ),
            ),
            if (_search.isNotEmpty)
              IconButton(
                icon: const Icon(
                  Icons.close,
                  size: 16,
                  color: Color(0xFF8B90A0),
                ),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _search = '');
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── Table grid ─────────────────────────────────────────────────────────

  Widget _buildTableGrid(AsyncValue tablesAsync) {
    return tablesAsync.when(
      data: (tables) {
        var filtered = tables as List<TableModel>;
        if (_selectedZoneId != null) {
          filtered = filtered
              .where((t) => t.zoneId == _selectedZoneId)
              .toList();
        }
        if (_search.isNotEmpty) {
          filtered = filtered
              .where((t) => t.name.toLowerCase().contains(_search))
              .toList();
        }

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.table_bar_outlined,
                  size: 64,
                  color: Colors.white.withOpacity(0.1),
                ),
                const SizedBox(height: 16),
                Text(
                  ref.t('dashboard.noTablesFound'),
                  style: const TextStyle(color: Colors.white24),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 1.1,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            final tableOccupied = filtered[i].status == TableStatus.occupied;
            return _ProfessionalTableCard(
              table: filtered[i],
              statusLabel: tableOccupied
                  ? ref.t('tableSelector.busy')
                  : ref.t('tableSelector.free'),
              noZoneLabel: ref.t('tableSelector.noZone'),
              onTap: () => Navigator.pop(context, filtered[i]),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
      ),
      error: (e, _) => Center(
        child: Text(
          '${ref.t('errors.error')}: $e',
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
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
