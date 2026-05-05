import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:st_george_pos/screens/order_screen.dart';
import 'package:st_george_pos/screens/management_screens.dart';
import 'package:st_george_pos/providers/pos_providers.dart';
import 'package:st_george_pos/models/table_model.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:st_george_pos/services/pos_repository.dart';
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!kIsWeb) {
    final isDesktop = defaultTargetPlatform == TargetPlatform.windows || 
                     defaultTargetPlatform == TargetPlatform.linux || 
                     defaultTargetPlatform == TargetPlatform.macOS;
    if (isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  final repo = PosRepository();
  await repo.init();

  runApp(ProviderScope(
    overrides: [
      posRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MyApp(),
  ));
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
          seedColor: const Color(0xFFD4AF37), // Gold
          brightness: Brightness.dark,
          primary: const Color(0xFFD4AF37), // Gold
          secondary: const Color(0xFF006B3C), // Emerald Green
          surface: const Color(0xFF1A1A1A), // Charcoal
          background: const Color(0xFF121212),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD4AF37)),
          titleLarge: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('ST GEORGE CAFE', style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w900, color: Color(0xFFD4AF37))),
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.refresh(tablesProvider)),
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
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
                  _SidebarItem(
                    icon: Icons.table_restaurant, 
                    label: 'Tables', 
                    isActive: ref.watch(dashboardViewProvider) == DashboardView.tables,
                    onTap: () => ref.read(dashboardViewProvider.notifier).state = DashboardView.tables,
                  ),
                  _SidebarItem(
                    icon: Icons.history, 
                    label: 'Orders',
                    isActive: ref.watch(dashboardViewProvider) == DashboardView.orders,
                    onTap: () => ref.read(dashboardViewProvider.notifier).state = DashboardView.orders,
                  ),
                  _SidebarItem(
                    icon: Icons.inventory, 
                    label: 'Menu',
                    isActive: ref.watch(dashboardViewProvider) == DashboardView.menu,
                    onTap: () => ref.read(dashboardViewProvider.notifier).state = DashboardView.menu,
                  ),
                  _SidebarItem(
                    icon: Icons.people, 
                    label: 'Waiters',
                    isActive: ref.watch(dashboardViewProvider) == DashboardView.waiters,
                    onTap: () => ref.read(dashboardViewProvider.notifier).state = DashboardView.waiters,
                  ),
                  _SidebarItem(
                    icon: Icons.bar_chart, 
                    label: 'Reports',
                    isActive: ref.watch(dashboardViewProvider) == DashboardView.reports,
                    onTap: () => ref.read(dashboardViewProvider.notifier).state = DashboardView.reports,
                  ),
                  const Spacer(),
                  _SidebarItem(
                    icon: Icons.logout, 
                    label: 'Exit',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
                child: Consumer(
                  builder: (context, ref, child) {
                    final currentView = ref.watch(dashboardViewProvider);
                    switch (currentView) {
                      case DashboardView.tables:
                        return const TableGrid();
                      case DashboardView.orders:
                        return const OrderHistoryScreen();
                      case DashboardView.menu:
                        return const MenuManagementScreen();
                      case DashboardView.waiters:
                        return const WaiterManagementScreen();
                      case DashboardView.reports:
                        return const ReportsScreen();
                      default:
                        return const SizedBox();
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

class TableGrid extends ConsumerWidget {
  const TableGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(tablesProvider);

    return tablesAsync.when(
      data: (tables) => GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          childAspectRatio: 1.2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
        itemCount: tables.length,
        itemBuilder: (context, index) {
          final table = tables[index];
          final isOccupied = table.status == TableStatus.occupied;
          
          return GlassContainer(
            opacity: isOccupied ? 0.2 : 0.05,
            border: Border.all(
              color: isOccupied ? const Color(0xFF006B3C).withOpacity(0.5) : Colors.white10,
              width: isOccupied ? 2 : 1,
            ),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => OrderScreen(table: table)),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.table_bar, 
                        size: 40, 
                        color: isOccupied ? const Color(0xFFD4AF37) : Colors.white24
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
                        color: isOccupied ? Colors.white : Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOccupied ? const Color(0xFF006B3C).withOpacity(0.2) : Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      table.status.toString().split('.').last.toUpperCase(), 
                      style: TextStyle(
                        fontSize: 8, 
                        fontWeight: FontWeight.bold,
                        color: isOccupied ? const Color(0xFF006B3C) : Colors.white38,
                        letterSpacing: 1.2
                      )
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

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
                size: 32
              ),
              const SizedBox(height: 4),
              Text(
                label, 
                style: TextStyle(
                  fontSize: 10, 
                  color: isActive ? const Color(0xFFD4AF37) : Colors.white54,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}
