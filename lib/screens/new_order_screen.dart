import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/models/table_model.dart';
import 'package:st_george_pos/models/product.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/models/category.dart';
import 'package:st_george_pos/providers/pos_providers.dart';
import 'package:st_george_pos/providers/order_workflow_provider.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:st_george_pos/models/waiter.dart';
import 'package:st_george_pos/services/bill_service.dart';
import 'package:st_george_pos/services/enhanced_print_service.dart';
import 'package:st_george_pos/services/enhanced_bill_service.dart';
import 'package:st_george_pos/services/order_workflow_service.dart';
import 'package:st_george_pos/locales/app_localizations.dart';

class NewOrderScreen extends ConsumerStatefulWidget {
  const NewOrderScreen({super.key});

  @override
  ConsumerState<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends ConsumerState<NewOrderScreen> 
    with TickerProviderStateMixin {
  int? selectedCategoryId;
  List<OrderItem> localItems = [];
  String searchQuery = '';
  String tableSearchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _tableSearchController = TextEditingController();
  double _discountAmount = 0;
  TableModel? selectedTable;
  late TabController _categoryTabController;

  // Menu categories for fixed tabs
  final List<MenuCategory> _menuCategories = [
    MenuCategory(id: 1, name: 'Appetizers', icon: Icons.restaurant_menu),
    MenuCategory(id: 2, name: 'Main Course', icon: Icons.lunch_dining),
    MenuCategory(id: 3, name: 'Desserts', icon: Icons.cake),
    MenuCategory(id: 4, name: 'Soft Drinks', icon: Icons.local_drink),
    MenuCategory(id: 5, name: 'Alcohol', icon: Icons.wine_bar),
    MenuCategory(id: 6, name: 'Hot Beverages', icon: Icons.coffee),
  ];

  @override
  void initState() {
    super.initState();
    _categoryTabController = TabController(length: _menuCategories.length, vsync: this);
    _categoryTabController.addListener(() {
      setState(() {
        selectedCategoryId = _menuCategories[_categoryTabController.index].id;
      });
    });
    
    // Initialize with first category
    selectedCategoryId = _menuCategories.first.id;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableSearchController.dispose();
    _categoryTabController.dispose();
    super.dispose();
  }

  void _addItem(Product product) {
    setState(() {
      final index = localItems.indexWhere(
        (item) => item.productId == product.id && !item.isPrintedToKitchen,
      );
      if (index != -1) {
        final e = localItems[index];
        localItems[index] = e.copyWith(
          quantity: e.quantity + 1,
          subtotal: (e.quantity + 1) * e.unitPrice,
        );
      } else {
        localItems.add(
          OrderItem(
            productId: product.id!,
            productName: product.name,
            quantity: 1,
            unitPrice: product.price,
            subtotal: product.price,
          ),
        );
      }
    });
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final item = localItems[index];
      final newQty = (item.quantity + delta).clamp(1, 999);
      localItems[index] = item.copyWith(
        quantity: newQty,
        subtotal: newQty * item.unitPrice,
      );
    });
  }

  void _removeItem(int index) {
    setState(() => localItems.removeAt(index));
  }

  void _addNoteToItem(int index) {
    final TextEditingController noteController = TextEditingController();
    noteController.text = localItems[index].notes ?? '';
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(ref.t('order.addNote')),
        content: TextField(
          controller: noteController,
          decoration: InputDecoration(
            hintText: ref.t('order.notes'),
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.t('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                localItems[index] = localItems[index].copyWith(
                  notes: noteController.text.trim(),
                );
              });
              Navigator.pop(ctx);
            },
            child: Text(ref.t('common.save')),
          ),
        ],
      ),
    );
  }

  double get _localTotal => localItems.fold(0, (sum, item) => sum + item.subtotal);

  List<TableModel> get _filteredTables {
    final workflowState = ref.read(orderWorkflowProvider);
    final allTables = workflowState.selectedTable != null 
        ? [workflowState.selectedTable!]
        : [];
    
    if (tableSearchQuery.isEmpty) return allTables;
    
    return allTables.where((table) =>
        table.name.toLowerCase().contains(tableSearchQuery.toLowerCase())
    ).toList();
  }

  Widget _buildLeftSidebar() {
    final workflowState = ref.watch(orderWorkflowProvider);
    
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          // Table Selection Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.t('order.selectTable'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                // Table Search
                TextField(
                  controller: _tableSearchController,
                  decoration: InputDecoration(
                    hintText: ref.t('tableSelector.searchHint'),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                    ),
                    hintStyle: const TextStyle(color: Colors.white38),
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    setState(() => tableSearchQuery = value);
                  },
                ),
                const SizedBox(height: 12),
                // Table Dropdown/List
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: _filteredTables.isEmpty
                      ? Center(
                          child: Text(
                            ref.t('tableSelector.noTablesFound'),
                            style: const TextStyle(color: Colors.white38),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredTables.length,
                          itemBuilder: (context, index) {
                            final table = _filteredTables[index];
                            final isSelected = selectedTable?.id == table.id;
                            
                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: Color(0xFFD4AF37).withOpacity(0.2),
                              title: Text(
                                table.name,
                                style: TextStyle(
                                  color: isSelected ? Color(0xFFD4AF37) : Colors.white,
                                  fontWeight: isSelected ? FontWeight.bold : null,
                                ),
                              ),
                              subtitle: Text(
                                'Zone ${table.zoneId ?? 'N/A'}',
                                style: TextStyle(
                                  color: isSelected ? Color(0xFFD4AF37).withOpacity(0.8) : Colors.white54,
                                ),
                              ),
                              onTap: () {
                                setState(() => selectedTable = table);
                                ref.read(orderWorkflowProvider.notifier).initializeForTable(table.id!);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          
          const Divider(color: Colors.white10, height: 1),
          
          // Assigned Waiter Display
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.t('order.waiter'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: workflowState.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : workflowState.error != null
                          ? Text(
                              workflowState.error!,
                              style: const TextStyle(color: Colors.red),
                            )
                          : Row(
                              children: [
                                const Icon(
                                  Icons.person,
                                  color: Color(0xFFD4AF37),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    workflowState.assignedWaiter?.name ?? 'No waiter assigned',
                                    style: TextStyle(
                                      color: workflowState.assignedWaiter != null 
                                          ? Colors.white 
                                          : Colors.white54,
                                      fontWeight: workflowState.assignedWaiter != null 
                                          ? FontWeight.w500 
                                          : null,
                                    ),
                                  ),
                                ),
                                if (workflowState.assignedWaiter != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFD4AF37).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'AUTO',
                                      style: TextStyle(
                                        color: Color(0xFFD4AF37),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                ),
              ],
            ),
          ),
          
          const Divider(color: Colors.white10, height: 1),
          
          // Session Info
          if (workflowState.existingOrders.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Sessions',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...workflowState.existingOrders.map((order) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.history, color: Colors.orange, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${order.items.length} items - ${ref.t('common.currency')}${order.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          Text(
                            order.status.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
          ],
          
          // Cart Section
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ref.t('order.currentOrder'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: localItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.shopping_basket_outlined,
                                  size: 48,
                                  color: Colors.white38,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  ref.t('order.cartEmpty'),
                                  style: const TextStyle(color: Colors.white38),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: localItems.length,
                            itemBuilder: (context, index) {
                              final item = localItems[index];
                              return _CartItemTile(
                                item: item,
                                onAdd: () => _updateQuantity(index, 1),
                                onRemove: () => _updateQuantity(index, -1),
                                onDelete: () => _removeItem(index),
                                onNote: () => _addNoteToItem(index),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  // Total
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFD4AF37).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFFD4AF37).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ref.t('order.total'),
                          style: const TextStyle(
                            color: Color(0xFFD4AF37),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${ref.t('common.currency')}${_localTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFFD4AF37),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: localItems.isEmpty ? null : () => _sendToKitchen(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFD4AF37),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(ref.t('order.sendToKitchen')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: localItems.isEmpty ? null : () => _printBill(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(ref.t('order.printBill')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(productsProvider(selectedCategoryId));
    
    return Column(
      children: [
        // Fixed Category Tabs
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: TabBar(
            controller: _categoryTabController,
            isScrollable: true,
            indicatorColor: const Color(0xFFD4AF37),
            labelColor: const Color(0xFFD4AF37),
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
            tabs: _menuCategories.map((category) => Tab(
              text: category.name,
              icon: Icon(category.icon, size: 20),
            )).toList(),
          ),
        ),
        
        // Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search menu items...',
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37)),
              ),
              hintStyle: const TextStyle(color: Colors.white38),
              style: const TextStyle(color: Colors.white),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (value) {
              setState(() => searchQuery = value);
            },
          ),
        ),
        
        // Products Grid
        Expanded(
          child: productsAsync.when(
            data: (products) {
              final filteredProducts = searchQuery.isEmpty
                  ? products
                  : products.where((product) =>
                      product.name.toLowerCase().contains(searchQuery.toLowerCase())
                  ).toList();
              
              if (filteredProducts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.white38,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No products found',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return _ProductCard(
                      product: product,
                      onTap: () => _addItem(product),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                'Error loading products: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sendToKitchen() async {
    if (selectedTable == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a table first')),
      );
      return;
    }

    if (localItems.isEmpty) return;

    try {
      final workflowState = ref.read(orderWorkflowProvider);
      final settingsAsync = ref.read(appSettingsProvider);
      
      if (workflowState.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(workflowState.error!)),
        );
        return;
      }

      // Create or get order session
      if (workflowState.currentOrder == null) {
        final currentUser = ref.read(authProvider)!;
        await ref.read(orderWorkflowProvider.notifier).createNewOrderSession(
          cashierId: currentUser.id!,
          cashierName: currentUser.username,
        );
      }

      final order = ref.read(orderWorkflowProvider).currentOrder;
      if (order == null) {
        throw Exception('Failed to create order session');
      }

      // Add items to order
      ref.read(orderWorkflowProvider.notifier).addItemsToOrder(localItems);
      
      // Print order list for kitchen
      final settings = await settingsAsync;
      await EnhancedPrintService.printOrderList(
        order: order,
        settings: settings,
        t: ref.t,
      );
      
      // Clear local items
      setState(() => localItems = []);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Items sent to kitchen and order list printed')),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _printBill() async {
    if (selectedTable == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a table first')),
      );
      return;
    }

    final workflowState = ref.read(orderWorkflowProvider);
    
    if (workflowState.existingOrders.isEmpty && localItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items to bill')),
      );
      return;
    }

    try {
      final settingsAsync = ref.read(appSettingsProvider);
      final settings = await settingsAsync;

      // Show print options dialog
      final printOption = await _showPrintOptionsDialog();
      if (printOption == null) return;

      switch (printOption) {
        case 'orderList':
          await _printOrderListOption(settings);
          break;
        case 'finalReceipt':
          await _printFinalReceiptOption(settings);
          break;
        case 'combined':
          await _printCombinedOrdersOption(settings);
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<String?> _showPrintOptionsDialog() async {
    final workflowState = ref.read(orderWorkflowProvider);
    final hasMultipleSessions = workflowState.existingOrders.length > 1;
    
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(ref.t('print.selectPrintOption')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(ref.t('print.printOrderList')),
              subtitle: Text(ref.t('print.printOrderListDesc')),
              leading: const Icon(Icons.list_alt, color: Color(0xFFD4AF37)),
              onTap: () => Navigator.pop(ctx, 'orderList'),
            ),
            ListTile(
              title: Text(ref.t('print.printFinalReceipt')),
              subtitle: Text(ref.t('print.printFinalReceiptDesc')),
              leading: const Icon(Icons.receipt, color: Color(0xFFD4AF37)),
              onTap: () => Navigator.pop(ctx, 'finalReceipt'),
            ),
            if (hasMultipleSessions) ...[
              ListTile(
                title: Text(ref.t('print.printCombined')),
                subtitle: Text(ref.t('print.printCombinedDesc')),
                leading: const Icon(Icons.merge_type, color: Color(0xFFD4AF37)),
                onTap: () => Navigator.pop(ctx, 'combined'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.t('common.cancel')),
          ),
        ],
      ),
    );
  }

  Future<void> _printOrderListOption(Map<String, String> settings) async {
    final workflowState = ref.read(orderWorkflowProvider);
    
    if (workflowState.currentOrder != null) {
      await EnhancedPrintService.printOrderList(
        order: workflowState.currentOrder!,
        settings: settings,
        t: ref.t,
      );
    } else if (workflowState.existingOrders.isNotEmpty) {
      await EnhancedPrintService.printOrderList(
        order: workflowState.existingOrders.last,
        settings: settings,
        t: ref.t,
      );
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order list printed')),
    );
  }

  Future<void> _printFinalReceiptOption(Map<String, String> settings) async {
    final workflowState = ref.read(orderWorkflowProvider);
    
    // Combine current items with existing orders
    List<OrderModel> allSessions = List.from(workflowState.existingOrders);
    
    if (localItems.isNotEmpty && workflowState.currentOrder != null) {
      allSessions.add(workflowState.currentOrder!);
    }
    
    if (allSessions.isEmpty) {
      throw Exception('No orders to print');
    }

    await EnhancedBillService.printFinalReceiptForTable(
      tableId: selectedTable!.id!,
      sessions: allSessions,
      settings: settings,
      t: ref.t,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Final receipt printed')),
    );
  }

  Future<void> _printCombinedOrdersOption(Map<String, String> settings) async {
    final workflowState = ref.read(orderWorkflowProvider);
    
    // Combine current items with existing orders
    List<OrderModel> allSessions = List.from(workflowState.existingOrders);
    
    if (localItems.isNotEmpty && workflowState.currentOrder != null) {
      allSessions.add(workflowState.currentOrder!);
    }
    
    if (allSessions.isEmpty) {
      throw Exception('No orders to combine');
    }

    // Print combined order list for kitchen
    await EnhancedPrintService.printCombinedOrderList(
      sessions: allSessions,
      settings: settings,
      t: ref.t,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Combined order list printed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: Row(
        children: [
          _buildLeftSidebar(),
          Expanded(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.restaurant_menu,
                        color: Color(0xFFD4AF37),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'MENU ORDERING',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      if (selectedTable != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Color(0xFFD4AF37).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Color(0xFFD4AF37)),
                          ),
                          child: Text(
                            selectedTable!.name,
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Main Content
                Expanded(child: _buildMainContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Supporting classes
class MenuCategory {
  final int id;
  final String name;
  final IconData icon;

  MenuCategory({required this.id, required this.name, required this.icon});
}

class _CartItemTile extends StatelessWidget {
  final OrderItem item;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onDelete;
  final VoidCallback onNote;

  const _CartItemTile({
    required this.item,
    required this.onAdd,
    required this.onRemove,
    required this.onDelete,
    required this.onNote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              ),
            ],
          ),
          if (item.notes != null && item.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Note: ${item.notes}',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.remove_circle_outline, color: Colors.white38, size: 20),
              ),
              Text(
                '${item.quantity}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFFD4AF37), size: 20),
              ),
              const Spacer(),
              Text(
                '${item.unitPrice.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(width: 8),
              Text(
                '${item.subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onNote,
                icon: const Icon(Icons.edit_note, color: Colors.white38, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color(0xFFD4AF37).withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  color: Color(0xFFD4AF37),
                  size: 48,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
