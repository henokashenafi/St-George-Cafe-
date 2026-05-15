import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'package:st_george_pos/models/app_user.dart';
import 'package:st_george_pos/models/table_model.dart';
import 'package:st_george_pos/providers/pos_providers.dart';
import 'package:st_george_pos/screens/login_screen.dart';
import 'package:st_george_pos/screens/management_screens.dart' hide SettingsScreen;
import 'package:st_george_pos/screens/order_screen.dart';
import 'package:st_george_pos/screens/settings_screen.dart';
import 'package:st_george_pos/screens/table_management_screen.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/services/pos_repository.dart';
import 'package:st_george_pos/locales/app_localizations.dart';
import 'package:st_george_pos/widgets/language_switcher.dart';
import 'package:st_george_pos/screens/audit_logs_screen.dart';
import 'package:st_george_pos/screens/system_logs_screen.dart';
import 'package:intl/intl.dart';
import 'package:st_george_pos/core/widgets/top_toaster.dart';


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

      // Windows Window Management
      if (defaultTargetPlatform == TargetPlatform.windows) {
        await windowManager.ensureInitialized();
        WindowOptions windowOptions = const WindowOptions(
          size: Size(1280, 800),
          center: true,
          backgroundColor: Colors.transparent,
          skipTaskbar: false,
          title: "Lda Cafe POS",
          titleBarStyle: TitleBarStyle.normal,
        );
        windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.show();
          await windowManager.focus();
        });
      }
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
      title: 'Lda Cafe POS',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: 'NotoSansEthiopic',
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
        fontFamily: 'NotoSansEthiopic',
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
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.zero),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Colors.white10)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Color(0xFFD4AF37))),
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
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
            ),
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
            tooltip: ref.t('common.refresh'),
            onPressed: () {
              ref.invalidate(tablesProvider);
              ref.invalidate(waitersProvider);
              ref.invalidate(categoriesProvider);
              ref.invalidate(productsProvider(null));
              ref.invalidate(currentShiftProvider);
              ref.invalidate(ordersProvider);
              ref.invalidate(zReportsProvider);
              ref.invalidate(chargesProvider);
              ref.invalidate(chargesListProvider);
              ref.invalidate(appSettingsProvider);
              ref.invalidate(cafeSettingsProvider);
              
              TopToaster.show(context, ref.t('common.refreshing'), isError: false);
            },
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
                        icon: Icons.groups_outlined,
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
                        icon: Icons.groups_outlined,
                        label: ref.t('navigation.waiters'),
                        isActive:
                            ref.watch(dashboardViewProvider) ==
                            DashboardView.waiters,
                        onTap: () =>
                            ref.read(dashboardViewProvider.notifier).state =
                                DashboardView.waiters,
                      ),
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
                        label: ref.t('navigation.audit'),
                        isActive:
                            ref.watch(dashboardViewProvider) ==
                            DashboardView.auditLogs,
                        onTap: () =>
                            ref.read(dashboardViewProvider.notifier).state =
                                DashboardView.auditLogs,
                      ),
                      _SidebarItem(
                        icon: Icons.bug_report_outlined,
                        label: ref.t('systemLogs.title'),
                        isActive:
                            ref.watch(dashboardViewProvider) ==
                            DashboardView.systemLogs,
                        onTap: () =>
                            ref.read(dashboardViewProvider.notifier).state =
                                DashboardView.systemLogs,
                      ),
                      _SidebarItem(
                        icon: Icons.tune,
                        label: ref.t('navigation.settings'),
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
        case DashboardView.waiters:
        case DashboardView.tables:
          return const WaiterManagementScreen(key: ValueKey('waiters_and_tables'));
        case DashboardView.orders:
          return OrderHistoryScreen(key: const ValueKey('orders'));
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
        case DashboardView.systemLogs:
          return const SystemLogsScreen(key: ValueKey('system_logs'));
        default:
          return const OrderScreen(key: ValueKey('home'));
      }
    }

    switch (view) {
      case DashboardView.home:
      case DashboardView.pos:
        return const OrderScreen(key: ValueKey('home'));
      case DashboardView.orders:
        return OrderHistoryScreen(key: const ValueKey('orders'));
      case DashboardView.heldOrders:
        return HeldOrdersScreen(key: const ValueKey('held_orders'));
      case DashboardView.menu:
        return MenuManagementScreen(key: const ValueKey('menu'));
      case DashboardView.waiters:
        return const WaiterManagementScreen(key: ValueKey('waiters_and_tables'));
      case DashboardView.reports:
        return ReportsScreen(key: const ValueKey('reports'));
      case DashboardView.charges:
        return ChargeManagementScreen(key: const ValueKey('charges'));
      case DashboardView.tables:
        return const WaiterManagementScreen(key: ValueKey('waiters_and_tables'));
      default:
        return const OrderScreen(key: ValueKey('home'));
    }
  }
}

// ── Dashboard Sidebar Item ──────────────────────────────────────────────────

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
