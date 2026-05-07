import 'dart:ui';
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
import 'package:st_george_pos/screens/settings_screen.dart';
import 'package:st_george_pos/screens/table_management_screen.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
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
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
              borderRadius: BorderRadius.circular(20),
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
          if (!isDirector)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: ref.t('common.refresh'),
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
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  if (!isDirector) ...[
                    _SidebarItem(
                      icon: Icons.point_of_sale,
                      label: ref.t('navigation.posMenu'),
                      isActive:
                          ref.watch(dashboardViewProvider) ==
                          DashboardView.tables,
                      onTap: () =>
                          ref.read(dashboardViewProvider.notifier).state =
                              DashboardView.tables,
                    ),
                    _SidebarItem(
                      icon: Icons.history,
                      label: ref.t('navigation.orders'),
                      isActive:
                          ref.watch(dashboardViewProvider) ==
                          DashboardView.orders,
                      onTap: () =>
                          ref.read(dashboardViewProvider.notifier).state =
                              DashboardView.orders,
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
                    _SidebarItem(
                      icon: Icons.table_chart_outlined,
                      label: ref.t('navigation.manage'),
                      isActive:
                          ref.watch(dashboardViewProvider) ==
                          DashboardView.settings,
                      onTap: () =>
                          ref.read(dashboardViewProvider.notifier).state =
                              DashboardView.settings,
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
                  // Director-only: settings & users
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
                      icon: Icons.tune,
                      label: ref.t('navigation.settings'),
                      isActive:
                          ref.watch(dashboardViewProvider) ==
                          DashboardView.settings,
                      onTap: () =>
                          ref.read(dashboardViewProvider.notifier).state =
                              DashboardView.settings,
                    ),
                  ],
                  const Spacer(),
                  _SidebarItem(
                    icon: Icons.logout,
                    label: ref.t('navigation.logout'),
                    onTap: () => ref.read(authProvider.notifier).logout(),
                  ),
                ],
              ),
            ),
            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
                child: Consumer(
                  builder: (context, ref, _) {
                    final view = ref.watch(dashboardViewProvider);
                    // Director can only see reports, users, settings
                    if (isDirector) {
                      switch (view) {
                        case DashboardView.reports:
                          return const ReportsScreen();
                        case DashboardView.users:
                          return const UserManagementScreen();
                        case DashboardView.settings:
                          return const SettingsScreen();
                        default:
                          // Default director view is reports
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            ref.read(dashboardViewProvider.notifier).state =
                                DashboardView.reports;
                          });
                          return const ReportsScreen();
                      }
                    }
                    // Cashier views
                    switch (view) {
                      case DashboardView.tables:
                        return const OrderHistoryScreen(); // Temporary fallback
                      case DashboardView.orders:
                        return const OrderHistoryScreen();
                      case DashboardView.menu:
                        return const MenuManagementScreen();
                      case DashboardView.waiters:
                        return const WaiterManagementScreen();
                      case DashboardView.settings:
                        return const TableManagementScreen();
                      case DashboardView.reports:
                        return const ReportsScreen();
                      default:
                        return const OrderHistoryScreen();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Table Grid with Zone Filter ───────────────────────────────────────────

class _TableGridWithZoneFilter extends ConsumerWidget {
  const _TableGridWithZoneFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final zonesAsync = ref.watch(tableZonesProvider);
    final selectedZone = ref.watch(selectedZoneFilterProvider);
    final tablesAsync = ref.watch(tablesProvider);
    final searchController = TextEditingController();

    return Column(
      children: [
        // Search + Zone filter row
        Row(
          children: [
            // Search by table name
            Expanded(
              child: GlassContainer(
                opacity: 0.05,
                borderRadius: 30,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: ref.t('tables.searchTable'),
                    border: InputBorder.none,
                    icon: const Icon(Icons.search, color: Colors.white54),
                  ),
                  onChanged: (_) => (context as Element).markNeedsBuild(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Zone filter chips
            zonesAsync.when(
              data: (zones) => zones.isEmpty
                  ? const SizedBox()
                  : SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        shrinkWrap: true,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(ref.t('common.all')),
                              selected: selectedZone == null,
                              selectedColor: const Color(0xFFD4AF37),
                              onSelected: (_) => ref
                                  .read(selectedZoneFilterProvider.notifier)
                                  .set(null),
                            ),
                          ),
                          ...zones.map(
                            (z) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(z.name),
                                selected: selectedZone == z.id,
                                selectedColor: const Color(0xFFD4AF37),
                                onSelected: (_) => ref
                                    .read(selectedZoneFilterProvider.notifier)
                                    .set(selectedZone == z.id ? null : z.id),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Table grid
        Expanded(
          child: tablesAsync.when(
            data: (tables) {
              final query = searchController.text.toLowerCase();
              final filtered = query.isEmpty
                  ? tables
                  : tables
                        .where((t) => t.name.toLowerCase().contains(query))
                        .toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Opacity(
                    opacity: 0.4,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.table_bar, size: 56),
                        const SizedBox(height: 12),
                        Text(ref.t('tables.noTablesFound')),
                      ],
                    ),
                  ),
                );
              }

              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final table = filtered[index];
                  final isOccupied = table.status == TableStatus.occupied;

                  return GlassContainer(
                    opacity: isOccupied ? 0.2 : 0.05,
                    border: Border.all(
                      color: isOccupied
                          ? const Color(0xFF006B3C).withOpacity(0.5)
                          : Colors.white10,
                      width: isOccupied ? 2 : 1,
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
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.table_bar,
                                size: 40,
                                color: isOccupied
                                    ? const Color(0xFFD4AF37)
                                    : Colors.white24,
                              ),
                              if (isOccupied)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF006B3C),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Flexible(
                            child: Text(
                              table.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isOccupied
                                    ? Colors.white
                                    : Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (table.zoneName != null)
                            Text(
                              table.zoneName!,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white38,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isOccupied
                                  ? const Color(0xFF006B3C).withOpacity(0.2)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              table.status == TableStatus.available
                                  ? ref.t('tables.statusAvailable')
                                  : table.status == TableStatus.occupied
                                  ? ref.t('tables.statusOccupied')
                                  : ref.t('tables.statusReserved'),
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: isOccupied
                                    ? const Color(0xFF006B3C)
                                    : Colors.white38,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('${ref.t('common.error')}: $e')),
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(12),
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
