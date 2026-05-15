import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/models/table_model.dart';
import 'package:st_george_pos/models/product.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/providers/pos_providers.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:st_george_pos/models/waiter.dart';
import 'package:st_george_pos/services/bill_service.dart';
import 'package:st_george_pos/locales/app_localizations.dart';
import 'package:st_george_pos/services/audit_service.dart';
import 'package:st_george_pos/services/system_log_service.dart';
import 'package:st_george_pos/core/widgets/top_toaster.dart';
import 'package:st_george_pos/models/station.dart';
import '../models/charge.dart';

enum OrderAssistantStep { waiter, table, product }

class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({super.key});

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  int? selectedCategoryId;
  List<OrderItem> localItems = [];
  String searchQuery = '';
  String waiterSearchQuery = '';
  bool _waiterSearchActive = false;
  OrderAssistantStep currentStep = OrderAssistantStep.waiter;
  final TextEditingController _assistantController = TextEditingController();
  final FocusNode _assistantFocusNode = FocusNode();

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _waiterSearchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _waiterSearchFocusNode = FocusNode();

  // Track latest visible filtered items for Enter-to-select
  List<Product> _lastFilteredProducts = [];
  List<Waiter> _lastFilteredWaiters = [];
  List<TableModel> _lastFilteredTables = [];
  int _suggestionIndex = 0;

  String _sortOption = 'alpha';
  Waiter? selectedWaiter;
  double _discountAmount = 0;
  String _paymentMethod = 'cash';
  bool _isProcessing = false;
  
  // Track print state for current order
  bool _kitchenPrinted = false;
  bool _billPrinted = false;
  bool _bothPrinted = false;
  TableModel? get selectedTable => ref.watch(selectedTableProvider);

  @override
  void initState() {
    super.initState();
    _assistantController.addListener(() {
      final query = _assistantController.text;
      setState(() {
        if (currentStep == OrderAssistantStep.waiter)
          waiterSearchQuery = query;
        else if (currentStep == OrderAssistantStep.product)
          searchQuery = query;
        _suggestionIndex = 0; // Reset index on type
      });
      // Auto-select when exactly 1 match and query is long enough
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (currentStep == OrderAssistantStep.waiter &&
            _lastFilteredWaiters.length == 1 &&
            query.length >= 2) {
          _onWaiterSelected(_lastFilteredWaiters.first);
        } else if (currentStep == OrderAssistantStep.table &&
            _lastFilteredTables.length == 1 &&
            query.length >= 1) {
          _onTableSelected(_lastFilteredTables.first);
        }
      });
    });

    // Auto-focus assistant bar
    _assistantFocusNode.requestFocus();

    _searchController.addListener(() {
      setState(() => searchQuery = _searchController.text);
    });
    _waiterSearchController.addListener(() {
      setState(() => waiterSearchQuery = _waiterSearchController.text);
    });
    _searchFocusNode.addListener(() => setState(() {}));
    _waiterSearchFocusNode.addListener(() {
      setState(() => _waiterSearchActive = _waiterSearchFocusNode.hasFocus);
    });

    // Check if table already selected (e.g. from dashboard)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (selectedTable != null) {
        setState(() => currentStep = OrderAssistantStep.product);
      }
    });
  }

  @override
  void dispose() {
    _assistantController.dispose();
    _assistantFocusNode.dispose();
    _searchController.dispose();
    _waiterSearchController.dispose();
    _searchFocusNode.dispose();
    _waiterSearchFocusNode.dispose();
    super.dispose();
  }

  void _focusItemSearch() {
    _searchFocusNode.requestFocus();
  }

  void _focusWaiterSearch() {
    setState(() => _waiterSearchActive = true);
    Future.delayed(const Duration(milliseconds: 50), () {
      _waiterSearchFocusNode.requestFocus();
    });
  }

  void _onWaiterSelected(Waiter waiter) {
    setState(() {
      selectedWaiter = waiter;
      currentStep = OrderAssistantStep.table;
      _assistantController.clear();
      waiterSearchQuery = '';
    });
  }

  void _onTableSelected(TableModel table) {
    ref.read(selectedTableProvider.notifier).set(table);
    setState(() {
      currentStep = OrderAssistantStep.product;
      _assistantController.clear();
      // Reset print state for new order
      _kitchenPrinted = false;
      _billPrinted = false;
      _bothPrinted = false;
    });
  }

  void _onProductSelected(Product product) {
    if (selectedTable == null ||
        (ref.read(activeOrderProvider(selectedTable?.id)).value == null &&
            selectedWaiter == null)) {
      TopToaster.show(
        context,
        'Please select a waiter and table first',
        isError: true,
      );
      return;
    }
    _showQuickQuantityPicker(product);
  }

  Future<void> _showQuickQuantityPicker(Product product) async {
    final qty = await showDialog<int>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) => _QuickQtyDialog(product: product),
    );
    if (qty != null && qty > 0) {
      _addItemWithQty(product, qty);
      setState(() => searchQuery = '');
      _assistantController.clear();
      Future.microtask(() => _assistantFocusNode.requestFocus());
    } else {
      Future.microtask(() => _assistantFocusNode.requestFocus());
    }
  }

  void _handleAssistantSubmit(String value) {
    if (currentStep == OrderAssistantStep.waiter) {
      if (_lastFilteredWaiters.isNotEmpty) {
        final index = _suggestionIndex.clamp(
          0,
          _lastFilteredWaiters.length - 1,
        );
        _onWaiterSelected(_lastFilteredWaiters[index]);
      }
    } else if (currentStep == OrderAssistantStep.table) {
      if (_lastFilteredTables.isNotEmpty) {
        final index = _suggestionIndex.clamp(0, _lastFilteredTables.length - 1);
        _onTableSelected(_lastFilteredTables[index]);
      }
    } else if (currentStep == OrderAssistantStep.product) {
      if (value.isEmpty) {
        final settings = ref.read(appSettingsProvider).value;
        final activeOrder = ref
            .read(activeOrderProvider(selectedTable?.id))
            .value;
        if (settings != null) _sendToKitchen(activeOrder, settings);
      } else if (_lastFilteredProducts.isNotEmpty) {
        final index = _suggestionIndex.clamp(
          0,
          _lastFilteredProducts.length - 1,
        );
        _onProductSelected(_lastFilteredProducts[index]);
      }
    }
  }

  void _addItemWithQty(Product product, int qty) {
    setState(() {
      final index = localItems.indexWhere(
        (item) => item.productId == product.id && !item.isPrintedToKitchen,
      );
      if (index != -1) {
        final e = localItems[index];
        localItems[index] = e.copyWith(
          quantity: e.quantity + qty,
          subtotal: (e.quantity + qty) * e.unitPrice,
        );
      } else {
        final station = ref.read(stationsProvider).value?.firstWhere((s) => s.id == product.stationId, orElse: () => Station(name: 'Kitchen'));
        localItems.add(
          OrderItem(
            productId: product.id!,
            productName: product.name,
            productNameAmharic: product.nameAmharic,
            quantity: qty,
            unitPrice: product.price,
            subtotal: product.price * qty,
            stationId: product.stationId,
            stationName: station?.name,
          ),
        );
      }
    });
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
        final station = ref.read(stationsProvider).value?.firstWhere((s) => s.id == product.stationId, orElse: () => Station(name: 'Kitchen'));
        localItems.add(
          OrderItem(
            productId: product.id!,
            productName: product.name,
            productNameAmharic: product.nameAmharic,
            quantity: 1,
            unitPrice: product.price,
            subtotal: product.price,
            stationId: product.stationId,
            stationName: station?.name,
          ),
        );
      }
    });
  }

  void _updateQuantity(int index, int delta) async {
    final item = localItems[index];
    final newQty = item.quantity + delta;
    if (newQty > 0) {
      setState(() {
        localItems[index] = item.copyWith(
          quantity: newQty,
          subtotal: newQty * item.unitPrice,
        );
      });
    } else {
      final confirm = await _showDeleteConfirmation(item.productName);
      if (confirm) {
        setState(() => localItems.removeAt(index));
      }
    }
  }

  void _removeItem(int index) async {
    final confirm = await _showDeleteConfirmation(
      localItems[index].productName,
    );
    if (confirm) {
      setState(() => localItems.removeAt(index));
    }
  }

  Future<bool> _showDeleteConfirmation(String productName) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: Text(ref.t('order.removeConfirm')),
            content: Text(
              ref.t(
                'order.removeConfirmMessage',
                replacements: {'product': productName},
              ),
            ),
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
        ) ??
        false;
  }

  void _addNoteToItem(int index) async {
    final controller = TextEditingController(
      text: localItems[index].notes ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          ref.t(
            'order.noteFor',
            replacements: {'product': localItems[index].productName},
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: ref.t('order.noteHint'),
            hintStyle: const TextStyle(color: Colors.white38),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.t('common.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(ref.t('common.save')),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() {
        localItems[index] = localItems[index].copyWith(notes: result);
      });
    }
  }

  double get _localTotal =>
      localItems.fold(0, (sum, item) => sum + item.subtotal);

  Future<OrderModel?> _sendToKitchen(
    OrderModel? existingOrder,
    Map<String, String> settings, {
    bool skipPrint = false,
  }) async {
    if (_isProcessing) return existingOrder;
    if (localItems.isEmpty) return null;
    
    setState(() => _isProcessing = true);
    SystemLogService.log('Starting _sendToKitchen for Table: ${selectedTable?.name}');
    try {
      TopToaster.show(context, ref.t('reports.processing'), isError: false);

      if (selectedTable == null) {
        TopToaster.show(context, ref.t('dashboard.selectTable'), isError: true);
        return null;
      }

      OrderModel? order = existingOrder;
      SystemLogService.log('Validation passed. Order exists: ${order != null}');
      if (order == null) {
        if (selectedWaiter == null) {
          TopToaster.show(context, ref.t('order.selectWaiter'), isError: true);
          return null;
        }
        SystemLogService.log('Fetching current user...');
        final currentUser = ref.read(authProvider)!;
        SystemLogService.log('User found: ${currentUser.username}. Creating new order...');
        SystemLogService.log('Creating new order for table ${selectedTable?.id}...');
        order = await ref
            .read(activeOrderServiceProvider)
            .createNewOrder(
              OrderModel(
                tableId: selectedTable!.id!,
                waiterId: selectedWaiter!.id!,
                cashierId: currentUser.id,
                tableName: selectedTable!.name,
                tableNameAmharic: selectedTable!.nameAmharic,
                waiterName: selectedWaiter!.name,
                waiterNameAmharic: selectedWaiter!.nameAmharic,
                cashierName: currentUser.username,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
        SystemLogService.log('Order created: ID #${order?.id}');
      }
      if (order != null) {
        final itemsToPrint = localItems
            .map((e) => e.copyWith(isPrintedToKitchen: true))
            .toList();

        TopToaster.show(context, ref.t('reports.saving'), isError: false);
        SystemLogService.log('Adding items to order #${order.id}...');
        final roundNumber = await ref
            .read(activeOrderServiceProvider)
            .addItems(order.id!, itemsToPrint, selectedTable!.id!);
        SystemLogService.log('Items added. Round: $roundNumber');

        bool printed = true;
        if (!skipPrint) {
          TopToaster.show(context, ref.t('reports.sendingToPrinter'), isError: false);
          
          // ── Print as a combined continuous slip ─────────────────────────
          final cafeSettings = await ref.read(cafeSettingsProvider.future);
          final charges = (await ref.read(chargesProvider.future)).where((c) => c.isActive).toList();
          
          final result = await BillService.generateCombinedSlipAndBill(
            order: order!,
            kitchenItems: localItems,
            receiptItems: [], // Empty receipt list skips the customer receipt
            roundNumber: roundNumber ?? 1,
            settings: cafeSettings,
            cashierName: order.cashierName,
            activeCharges: charges,
            printerName: settings['default_printer_name'],
          );
          if (!result) printed = false;
        }

        final uniqueStationsCount = localItems.map((e) => e.stationId).toSet().length;

        await ref
            .read(auditServiceProvider)
            .log(
              'Sent to Kitchen',
              details:
                  'Table: ${selectedTable!.name}, Items: ${localItems.length}, Stations: $uniqueStationsCount, Round: $roundNumber',
            );
        
        // Fetch the updated order with the newly added items so subsequent prints work correctly
        order = await ref.read(posRepositoryProvider).getActiveOrderForTable(selectedTable!.id!);

        if (mounted && !skipPrint) {
          if (printed) {
            TopToaster.show(
              context,
              roundNumber != null
                  ? 'Kitchen slip printed — Round $roundNumber ✓'
                  : ref.t('order.sentToKitchen'),
            );
          } else {
            TopToaster.show(
              context,
              'Order saved but no printer found. Check Settings → Default Printer.',
              isError: true,
            );
          }
        }
      }
      setState(() {
        localItems = [];
        _kitchenPrinted = true;
      });
      return order;
    } catch (e, st) {
      SystemLogService.log('ERROR in _sendToKitchen: $e\n$st');
      TopToaster.show(context, 'Critical Error: $e', isError: true);
      return null;
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _printBill(
    OrderModel order,
    Map<String, String> settings,
  ) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      TopToaster.show(context, ref.t('reports.generatingPdf'), isError: false);
      final discountEnabled = (settings['discount_enabled'] ?? 'true') == 'true';

      // If there are unsent local items, warn
      if (localItems.isNotEmpty) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: Text(ref.t('order.unsentItems')),
            content: Text(ref.t('order.unsentItemsMessage')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ref.t('order.goBack')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ref.t('order.discardAndBill')),
              ),
            ],
          ),
        );
        if (proceed != true) return;
        setState(() => localItems = []);
      }

      if (order.items.isEmpty) {
        TopToaster.show(context, ref.t('reports.noItemsInOrder'), isError: true);
        return;
      }

      final subtotal = order.totalAmount;
      final charges = (await ref.read(chargesProvider.future)).where((c) => c.isActive).toList();
      if (!mounted) return;

      // Show bill confirmation dialog with discount input
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => _BillConfirmDialog(
          order: order,
          subtotal: subtotal,
          charges: charges,
          discountEnabled: discountEnabled,
          initialDiscount: _discountAmount,
          initialPaymentMethod: _paymentMethod,
          onDiscountChanged: (v) => _discountAmount = v,
          onPaymentMethodChanged: (v) => _paymentMethod = v,
        ),
      );

      if (confirmed == true && mounted) {
        final printerName = settings['default_printer_name'];
        final cafeSettings = await ref.read(cafeSettingsProvider.future);
        
        final printed = await BillService.generateAndDownloadBill(
          order: order.copyWith(discountAmount: _discountAmount),
          items: order.items,
          settings: cafeSettings,
          cashierName: order.cashierName,
          activeCharges: charges,
          printerName: printerName,
        );

        double totalAdditions = 0;
        double totalDeductions = 0;
        for (final c in charges) {
          final amount = order.totalAmount * (c.value / 100);
          if (c.type == 'addition') totalAdditions += amount;
          else totalDeductions += amount;
        }

        await ref.read(posRepositoryProvider).completeOrder(
          order.id!,
          order.tableId,
          cashierId: ref.read(authProvider)?.id,
          serviceCharge: totalAdditions,
          discountAmount: _discountAmount + totalDeductions,
          paymentMethod: _paymentMethod,
        );

        // Invalidate active order immediately so buttons disable
        ref.invalidate(activeOrderProvider(order.tableId));

        await ref.read(auditServiceProvider).log(
          'Order Completed',
          details: 'ID: ${order.id}, Total: ${subtotal.toStringAsFixed(2)}, Table: ${order.tableName}',
        );

        if (mounted && !printed) {
          TopToaster.show(
            context,
            'Bill saved but no printer found. Check Settings → Default Printer.',
            isError: true,
          );
        } else if (mounted) {
          TopToaster.show(context, ref.t('reports.receiptGenerated'));
        }

        // Mark bill as printed and disable other print options
        setState(() {
          _billPrinted = true;
          _bothPrinted = true; // If bill is printed, both is effectively printed
        });

        ref.refresh(tablesProvider);
        ref.read(selectedTableProvider.notifier).set(null);
        ref.read(dashboardViewProvider.notifier).state = DashboardView.home;
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _printBoth(OrderModel? activeOrder, Map<String, String> settings) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      OrderModel? order = activeOrder;

      // Combine items in-memory for the dialog
      List<OrderItem> combinedItems = order != null ? List.from(order.items) : [];
      combinedItems.addAll(localItems);

      if (combinedItems.isEmpty) {
        TopToaster.show(context, ref.t('reports.noItemsInOrder'), isError: true);
        return;
      }

      if (selectedTable == null) {
        TopToaster.show(context, ref.t('dashboard.selectTable'), isError: true);
        return;
      }

      if (order == null && selectedWaiter == null) {
        TopToaster.show(context, ref.t('order.selectWaiter'), isError: true);
        return;
      }

      double combinedTotal = combinedItems.fold(0, (s, i) => s + i.subtotal);

      // Create a temporary order for the confirmation dialog
      final dummyOrder = order ?? OrderModel(
        id: 0,
        tableId: selectedTable!.id!,
        waiterId: selectedWaiter?.id ?? 0,
        cashierId: ref.read(authProvider)?.id ?? 0,
        tableName: selectedTable!.name,
        waiterName: selectedWaiter?.name ?? '',
        cashierName: ref.read(authProvider)?.username ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: combinedItems,
        totalAmount: combinedTotal,
      );

      final charges = (await ref.read(chargesProvider.future)).where((c) => c.isActive).toList();
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => _BillConfirmDialog(
          order: dummyOrder.copyWith(items: combinedItems, totalAmount: combinedTotal),
          subtotal: combinedTotal,
          charges: charges,
          discountEnabled: (settings['discount_enabled'] ?? 'true') == 'true',
          initialDiscount: _discountAmount,
          initialPaymentMethod: _paymentMethod,
          onDiscountChanged: (v) => _discountAmount = v,
          onPaymentMethodChanged: (v) => _paymentMethod = v,
        ),
      );

      if (confirmed == true && mounted) {
        // --- NOW WE PERMANENTLY SAVE TO THE DATABASE ---
        if (order == null) {
          final currentUser = ref.read(authProvider)!;
          order = await ref.read(activeOrderServiceProvider).createNewOrder(
            OrderModel(
              tableId: selectedTable!.id!,
              waiterId: selectedWaiter!.id!,
              cashierId: currentUser.id,
              tableName: selectedTable!.name,
              waiterName: selectedWaiter!.name,
              cashierName: currentUser.username,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          if (order == null) {
            TopToaster.show(context, ref.t('reports.failedToCreateOrder'), isError: true);
            return;
          }
        }

        if (localItems.isNotEmpty) {
          final itemsToSave = localItems.map((e) => e.copyWith(isPrintedToKitchen: true)).toList();
          await ref.read(activeOrderServiceProvider).addItems(order.id!, itemsToSave, selectedTable!.id!);
          setState(() => localItems = []);
          
          order = await ref.read(posRepositoryProvider).getActiveOrderForTable(selectedTable!.id!);
        }

        final finalOrder = order!;
        final printerName = settings['default_printer_name'];
        final cafeSettings = await ref.read(cafeSettingsProvider.future);
        
        int maxRound = 1;
        if (finalOrder.items.isNotEmpty) {
          maxRound = finalOrder.items.map((e) => e.kitchenRound ?? 1).reduce((a, b) => a > b ? a : b);
        }

        TopToaster.show(context, ref.t('reports.generatingPdf'), isError: false);

        final printed = await BillService.generateCombinedSlipAndBill(
          order: finalOrder.copyWith(discountAmount: _discountAmount),
          kitchenItems: finalOrder.items,
          receiptItems: finalOrder.items,
          roundNumber: maxRound,
          settings: cafeSettings,
          cashierName: finalOrder.cashierName,
          activeCharges: charges,
          printerName: printerName,
        );
        
        double totalAdditions = 0;
        double totalDeductions = 0;
        for (final c in charges) {
          final amount = finalOrder.totalAmount * (c.value / 100);
          if (c.type == 'addition') totalAdditions += amount;
          else totalDeductions += amount;
        }

        await ref.read(posRepositoryProvider).completeOrder(
          finalOrder.id!,
          finalOrder.tableId,
          cashierId: ref.read(authProvider)?.id,
          serviceCharge: totalAdditions,
          discountAmount: _discountAmount + totalDeductions,
          paymentMethod: _paymentMethod,
        );

        // Invalidate active order immediately so buttons disable
        ref.invalidate(activeOrderProvider(finalOrder.tableId));

        if (mounted && !printed) {
          TopToaster.show(
            context,
            'Bill saved but no printer found. Check Settings → Default Printer.',
            isError: true,
          );
        } else if (mounted) {
          TopToaster.show(context, ref.t('reports.combinedPrintGenerated'));
        }

        // Mark all as printed since we printed both
        setState(() {
          _kitchenPrinted = true;
          _billPrinted = true;
          _bothPrinted = true;
        });

        ref.refresh(tablesProvider);
        ref.read(selectedTableProvider.notifier).set(null);
        ref.read(dashboardViewProvider.notifier).state = DashboardView.home;
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTable = ref.watch(selectedTableProvider);
    final activeOrderAsync = ref.watch(activeOrderProvider(selectedTable?.id));
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(productsProvider(selectedCategoryId));
    final waitersAsync = ref.watch(waitersProvider);
    final tablesAsync = ref.watch(tablesProvider);
    final settingsAsync = ref.watch(appSettingsProvider);
    ref.watch(languageProvider);

    // Sync currentStep when selectedTable changes (e.g. from held orders)
    ref.listen(selectedTableProvider, (prev, next) {
      // Only reset print state when switching TO a new table (not when clearing)
      if (next != null && next.id != prev?.id) {
        setState(() {
          currentStep = OrderAssistantStep.product;
          _kitchenPrinted = false;
          _billPrinted = false;
          _bothPrinted = false;
        });
      } else if (next != null && currentStep == OrderAssistantStep.waiter) {
        setState(() {
          currentStep = OrderAssistantStep.product;
        });
      }
    });

    // Top-level Focus captures ALL key presses when nothing else has focus.
    // Any printable char → auto-routes to item search field.
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        // Only react on key-down, ignore if any text field is already focused
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final logical = event.logicalKey;

        // Escape → clear assistant bar
        if (logical == LogicalKeyboardKey.escape) {
          _assistantController.clear();
          _assistantFocusNode.requestFocus();
          return KeyEventResult.handled;
        }

        // Arrow Key Navigation for Suggestions
        if (logical == LogicalKeyboardKey.arrowDown) {
          setState(() {
            int max = 0;
            if (currentStep == OrderAssistantStep.waiter)
              max = _lastFilteredWaiters.length;
            if (currentStep == OrderAssistantStep.table)
              max = _lastFilteredTables.length;
            if (currentStep == OrderAssistantStep.product)
              max = _lastFilteredProducts.length;
            if (max > 0) _suggestionIndex = (_suggestionIndex + 1) % max;
          });
          return KeyEventResult.handled;
        }
        if (logical == LogicalKeyboardKey.arrowUp) {
          setState(() {
            int max = 0;
            if (currentStep == OrderAssistantStep.waiter)
              max = _lastFilteredWaiters.length;
            if (currentStep == OrderAssistantStep.table)
              max = _lastFilteredTables.length;
            if (currentStep == OrderAssistantStep.product)
              max = _lastFilteredProducts.length;
            if (max > 0) _suggestionIndex = (_suggestionIndex - 1 + max) % max;
          });
          return KeyEventResult.handled;
        }

        if (_assistantFocusNode.hasFocus) {
          return KeyEventResult.ignored;
        }
        // Ctrl+F / Ctrl+W → focus assistant bar
        if ((logical == LogicalKeyboardKey.keyF ||
                logical == LogicalKeyboardKey.keyW) &&
            HardwareKeyboard.instance.isControlPressed) {
          _assistantFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        // Ctrl+Enter / F9 → send to kitchen
        if ((logical == LogicalKeyboardKey.enter &&
                HardwareKeyboard.instance.isControlPressed) ||
            logical == LogicalKeyboardKey.f9) {
          settingsAsync.maybeWhen(
            data: (s) => _sendToKitchen(activeOrderAsync.value, s),
            orElse: () => null,
          );
          return KeyEventResult.handled;
        }
        // Printable single character → route to assistant bar
        final label = logical.keyLabel;
        if (label.length == 1 && !HardwareKeyboard.instance.isControlPressed) {
          _assistantFocusNode.requestFocus();
          // Append the typed character
          final current = _assistantController.text;
          final char = HardwareKeyboard.instance.isShiftPressed
              ? label
              : label.toLowerCase();
          _assistantController.value = TextEditingValue(
            text: current + char,
            selection: TextSelection.collapsed(offset: current.length + 1),
          );
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF):
              const SearchIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyW):
              const WaiterSearchIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter):
              const SendToKitchenIntent(),
          LogicalKeySet(LogicalKeyboardKey.f9): const SendToKitchenIntent(),
        },
        child: Actions(
          actions: {
            SearchIntent: CallbackAction<SearchIntent>(
              onInvoke: (_) {
                _assistantFocusNode.requestFocus();
                return null;
              },
            ),
            WaiterSearchIntent: CallbackAction<WaiterSearchIntent>(
              onInvoke: (_) {
                _assistantFocusNode.requestFocus();
                return null;
              },
            ),
            SendToKitchenIntent: CallbackAction<SendToKitchenIntent>(
              onInvoke: (_) {
                settingsAsync.maybeWhen(
                  data: (s) => _sendToKitchen(activeOrderAsync.value, s),
                  orElse: () => null,
                );
                return null;
              },
            ),
          },
          child: Column(
            children: [
              // Header matching dashboard style
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    Text(
                      selectedTable != null
                          ? ref.t(
                              'order.title',
                              replacements: {
                                'table': ref.ln(
                                    selectedTable!.name, selectedTable!.nameAmharic)
                              },
                            )
                          : ref.t('main.newOrder'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    if (selectedTable != null)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          ref.read(selectedTableProvider.notifier).set(null);
                          setState(() {
                            localItems = [];
                            currentStep = OrderAssistantStep.waiter;
                            selectedWaiter = null;
                            _discountAmount = 0;
                            _assistantController.clear();
                            // Clear print state
                            _kitchenPrinted = false;
                            _billPrinted = false;
                            _bothPrinted = false;
                          });
                        },
                        tooltip: ref.t('order.clearNewOrder'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    // ── Main Menu Panel ──────────────────────────────────────────────
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Assistant Bar ──────────────────────────────────────────
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _assistantFocusNode.hasFocus
                                      ? const Color(0xFFD4AF37)
                                      : Colors.white10,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.zero,
                              ),
                              child: GlassContainer(
                                opacity: 0.08,
                                child: TextField(
                                  controller: _assistantController,
                                  focusNode: _assistantFocusNode,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(
                                      currentStep == OrderAssistantStep.waiter
                                          ? Icons.person_search
                                          : currentStep ==
                                                OrderAssistantStep.table
                                          ? Icons.table_bar
                                          : Icons.search,
                                      color: const Color(0xFFD4AF37),
                                      size: 20,
                                    ),
                                    hintText:
                                        currentStep == OrderAssistantStep.waiter
                                        ? ref.t('order.waiterHint')
                                        : currentStep ==
                                              OrderAssistantStep.table
                                        ? ref.t('order.tableHint')
                                        : ref.t('order.productHint'),
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.3),
                                      fontSize: 13,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    suffixIcon:
                                        _assistantController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.white30,
                                            ),
                                            onPressed: () {
                                              _assistantController.clear();
                                              _assistantFocusNode
                                                  .requestFocus();
                                            },
                                          )
                                        : null,
                                  ),
                                  onSubmitted: _handleAssistantSubmit,
                                ),
                              ),
                            ),

                            // ── Manual Selection Dropdowns (Added for Cashier convenience) ──
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  // Waiter Dropdown
                                  Expanded(
                                    child: waitersAsync.when(
                                      data: (ws) =>
                                          DropdownButtonFormField<int>(
                                            value:
                                                activeOrderAsync
                                                    .value
                                                    ?.waiterId ??
                                                selectedWaiter?.id,
                                            decoration: InputDecoration(
                                              labelText: ref
                                                  .t('bill.waiter')
                                                  ,
                                              labelStyle: const TextStyle(
                                                color: Color(0xFFD4AF37),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1,
                                              ),
                                              prefixIcon: const Icon(
                                                Icons.person,
                                                color: Color(0xFFD4AF37),
                                                size: 16,
                                              ),
                                              filled: true,
                                              fillColor: Colors.white
                                                  .withOpacity(0.05),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.zero,
                                                borderSide: BorderSide(
                                                  color: Colors.white
                                                      .withOpacity(0.1),
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.zero,
                                                borderSide: BorderSide(
                                                  color: Colors.white
                                                      .withOpacity(0.1),
                                                ),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                            ),
                                            dropdownColor: const Color(
                                              0xFF1A1A1A,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                            ),
                                            items: ws
                                                .map(
                                                  (w) => DropdownMenuItem(
                                                    value: w.id,
                                                    child: Text(
                                                        ref.ln(w.name, w.nameAmharic)),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged:
                                                activeOrderAsync.value != null
                                                ? null
                                                : (id) {
                                                    if (id != null) {
                                                      final waiter = ws
                                                          .firstWhere(
                                                            (w) => w.id == id,
                                                          );
                                                      _onWaiterSelected(waiter);
                                                    }
                                                  },
                                          ),
                                      loading: () =>
                                          const LinearProgressIndicator(),
                                      error: (_, __) =>
                                          Text(ref.t('common.error')),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Table Dropdown
                                  Expanded(
                                    child: tablesAsync.when(
                                      data: (ts) =>
                                          DropdownButtonFormField<int>(
                                            value: selectedTable?.id,
                                            decoration: InputDecoration(
                                              labelText: ref
                                                  .t('order.selectTable')
                                                  ,
                                              labelStyle: const TextStyle(
                                                color: Color(0xFFD4AF37),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1,
                                              ),
                                              prefixIcon: const Icon(
                                                Icons.table_bar,
                                                color: Color(0xFFD4AF37),
                                                size: 16,
                                              ),
                                              filled: true,
                                              fillColor: Colors.white
                                                  .withOpacity(0.05),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.zero,
                                                borderSide: BorderSide(
                                                  color: Colors.white
                                                      .withOpacity(0.1),
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.zero,
                                                borderSide: BorderSide(
                                                  color: Colors.white
                                                      .withOpacity(0.1),
                                                ),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                            ),
                                            dropdownColor: const Color(
                                              0xFF1A1A1A,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                            ),
                                            items: ts
                                                .map(
                                                  (t) => DropdownMenuItem(
                                                    value: t.id,
                                                    child: Text(
                                                        ref.ln(t.name, t.nameAmharic)),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged:
                                                activeOrderAsync.value != null
                                                ? null
                                                : (id) {
                                                    if (id != null) {
                                                      final table = ts
                                                          .firstWhere(
                                                            (t) => t.id == id,
                                                          );
                                                      _onTableSelected(table);
                                                    }
                                                  },
                                          ),
                                      loading: () =>
                                          const LinearProgressIndicator(),
                                      error: (_, __) =>
                                          Text(ref.t('common.error')),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ── Suggestion Dropdown (Waiter / Table / Product) ─────────
                            if (currentStep == OrderAssistantStep.waiter &&
                                _lastFilteredWaiters.isNotEmpty)
                              _SuggestionDropdown(
                                children: _lastFilteredWaiters
                                    .take(6)
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map(
                                      (e) => _SuggestionItem(
                                        icon: Icons.person,
                                        title: ref.ln(e.value.name, e.value.nameAmharic),
                                        subtitle: 'Code: ${e.value.code}',
                                        isHighlighted:
                                            e.key == _suggestionIndex,
                                        onTap: () => _onWaiterSelected(e.value),
                                      ),
                                    )
                                    .toList(),
                              )
                            else if (currentStep == OrderAssistantStep.table &&
                                _lastFilteredTables.isNotEmpty)
                              _SuggestionDropdown(
                                children: _lastFilteredTables
                                    .take(8)
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map(
                                      (e) => _SuggestionItem(
                                        icon: Icons.table_bar,
                                        title: ref.ln(e.value.name, e.value.nameAmharic),
                                        subtitle:
                                            '${e.value.status == TableStatus.occupied ? ref.t('tables.statusOccupied') : ref.t('tables.statusAvailable')} • ${e.value.zoneName ?? ref.t('tables.noZoneAssigned')}',
                                        accentColor:
                                            e.value.status ==
                                                TableStatus.occupied
                                            ? Colors.redAccent
                                            : Colors.greenAccent,
                                        isHighlighted:
                                            e.key == _suggestionIndex,
                                        onTap: () => _onTableSelected(e.value),
                                      ),
                                    )
                                    .toList(),
                              )
                            else if (currentStep ==
                                    OrderAssistantStep.product &&
                                searchQuery.isNotEmpty &&
                                _lastFilteredProducts.isNotEmpty)
                              _SuggestionDropdown(
                                children: _lastFilteredProducts
                                    .take(6)
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map(
                                      (e) => _SuggestionItem(
                                        icon: Icons.restaurant_menu,
                                        title: ref.ln(e.value.name,
                                            e.value.nameAmharic),
                                        subtitle:
                                            '${e.value.price.toStringAsFixed(2)} ETB',
                                        isHighlighted:
                                            e.key == _suggestionIndex,
                                        onTap: () =>
                                            _onProductSelected(e.value),
                                      ),
                                    )
                                    .toList(),
                              ),
                            const SizedBox(height: 8),

                            // ── Horizontal Categories ──────────────────────────────────
                            categoriesAsync.when(
                              data: (cats) => Container(
                                height: 40,
                                margin: const EdgeInsets.only(bottom: 16),
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: cats.length + 1,
                                  itemBuilder: (ctx, i) {
                                    final isSelected = i == 0
                                        ? selectedCategoryId == null
                                        : selectedCategoryId == cats[i - 1].id;
                                    final name = i == 0
                                        ? ref.t('common.all')
                                        : ref.ln(cats[i - 1].name, cats[i - 1].nameAmharic);
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: InkWell(
                                        onTap: () => setState(
                                          () => selectedCategoryId = i == 0
                                              ? null
                                              : cats[i - 1].id,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFFD4AF37)
                                                : Colors.white.withOpacity(
                                                    0.05,
                                                  ),
                                            borderRadius: BorderRadius.zero,
                                            border: Border.all(
                                              color: isSelected
                                                  ? Colors.transparent
                                                  : Colors.white10,
                                            ),
                                          ),
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.black
                                                  : Colors.white70,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                            ),

                            // ── Product Grid ──────────────────────────────────────────
                            Expanded(
                              child: productsAsync.when(
                                data: (products) {
                                  final filtered = products
                                      .where(
                                        (p) => p.name.toLowerCase().contains(searchQuery.toLowerCase()) || (p.nameAmharic?.contains(searchQuery) ?? false),
                                      )
                                      .toList();
                                  if (_sortOption == 'alpha') {
                                    filtered.sort(
                                      (a, b) => a.name.compareTo(b.name),
                                    );
                                  } else if (_sortOption == 'priceAsc') {
                                    filtered.sort(
                                      (a, b) => a.price.compareTo(b.price),
                                    );
                                  } else if (_sortOption == 'priceDesc') {
                                    filtered.sort(
                                      (a, b) => b.price.compareTo(a.price),
                                    );
                                  }

                                  // Track for assistant bar
                                  _lastFilteredProducts = filtered;

                                  return GridView.builder(
                                    padding: EdgeInsets.zero,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 4,
                                          childAspectRatio: 2.8,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                        ),
                                    itemCount: filtered.length,
                                    itemBuilder: (_, i) {
                                      final p = filtered[i];
                                      final isFirstMatch =
                                          i == 0 &&
                                          searchQuery.isNotEmpty &&
                                          currentStep ==
                                              OrderAssistantStep.product;
                                      return AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.zero,
                                          border: isFirstMatch
                                              ? Border.all(
                                                  color: const Color(
                                                    0xFFD4AF37,
                                                  ),
                                                  width: 1.5,
                                                )
                                              : null,
                                        ),
                                        child: GlassContainer(
                                          opacity: isFirstMatch ? 0.12 : 0.05,
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.08,
                                            ),
                                          ),
                                          child: InkWell(
                                            onTap: () => _onProductSelected(p),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.restaurant_menu,
                                                    size: 16,
                                                    color: isFirstMatch
                                                        ? const Color(
                                                            0xFFD4AF37,
                                                          )
                                                        : const Color(
                                                            0xFFD4AF37,
                                                          ).withOpacity(0.6),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          ref.ln(p.name, p.nameAmharic),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13,
                                                            color: isFirstMatch
                                                                ? Colors.white
                                                                : Colors
                                                                      .white70,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        Text(
                                                          '${p.price.toStringAsFixed(2)} ${ref.t('common.currency')}',
                                                          style:
                                                              const TextStyle(
                                                                color: Color(
                                                                  0xFFD4AF37,
                                                                ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontSize: 11,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (e, _) => Text('$e'),
                              ),
                            ),

                            // ── Held Orders Panel (shown when no table selected) ──────
                            if (selectedTable == null)
                              const Flexible(child: _HeldOrdersInlinePanel()),
                          ],
                        ),
                      ),
                    ),
                    // ── Cart panel ──────────────────────────────────────────────
                    Container(
                      width: 460,
                      margin: const EdgeInsets.only(bottom: 16, right: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.shopping_cart,
                                  color: Color(0xFFD4AF37),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  ref.t('order.currentOrder'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Consumer(
                              builder: (context, ref, _) {
                                final waitersAsync = ref.watch(waitersProvider);
                                final tablesAsync = ref.watch(tablesProvider);
                                final activeOrderAsync = ref.watch(activeOrderProvider(selectedTable?.id));

                                // Populate filtering for assistant bar
                                waitersAsync.whenData((ws) {
                                  _lastFilteredWaiters = ws
                                      .where((w) => w.name.toLowerCase().contains(waiterSearchQuery.toLowerCase()) || (w.nameAmharic?.contains(waiterSearchQuery) ?? false))
                                      .toList();
                                });
                                tablesAsync.whenData((ts) {
                                  _lastFilteredTables = ts
                                      .where((t) => t.name.toLowerCase().contains(_assistantController.text.toLowerCase()) || (t.nameAmharic?.contains(_assistantController.text) ?? false))
                                      .toList();
                                });

                                final activeOrder = activeOrderAsync.value;
                                final isLocked = activeOrder != null;

                                return waitersAsync.when(
                                  data: (allWaiters) => Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Waiter Dropdown
                                      DropdownButtonFormField<int>(
                                        value:
                                            activeOrder?.waiterId ??
                                            selectedWaiter?.id,
                                        decoration: InputDecoration(
                                          prefixIcon: const Icon(
                                            Icons.person,
                                            color: Color(0xFFD4AF37),
                                            size: 18,
                                          ),
                                          labelText: ref.t('bill.waiter'),
                                          labelStyle: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                          border: const OutlineInputBorder(
                                            borderRadius: BorderRadius.zero,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                        ),
                                        dropdownColor: const Color(0xFF1A1A1A),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                        items: allWaiters
                                            .map(
                                              (w) => DropdownMenuItem(
                                                value: w.id,
                                                child: Text(
                                                    ref.ln(w.name, w.nameAmharic)),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: isLocked
                                            ? null
                                            : (id) {
                                                final waiter = allWaiters
                                                    .firstWhere(
                                                      (w) => w.id == id,
                                                    );
                                                _onWaiterSelected(waiter);
                                              },
                                      ),
                                      const SizedBox(height: 12),
                                      // Table Dropdown
                                      tablesAsync.when(
                                        data: (allTables) => DropdownButtonFormField<int>(
                                          value: selectedTable?.id,
                                          decoration: InputDecoration(
                                            prefixIcon: const Icon(
                                              Icons.table_bar,
                                              color: Color(0xFFD4AF37),
                                              size: 18,
                                            ),
                                            labelText: ref.t(
                                              'management.tables',
                                            ),
                                            labelStyle: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                            border: const OutlineInputBorder(
                                              borderRadius: BorderRadius.zero,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                          ),
                                          dropdownColor: const Color(
                                            0xFF1A1A1A,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                          items: allTables
                                              .map(
                                                (t) => DropdownMenuItem(
                                                  value: t.id,
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          ref.ln(t.name,
                                                              t.nameAmharic),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          maxLines: 1,
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 14,
                                                              ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              (t.status ==
                                                                          TableStatus
                                                                              .occupied
                                                                      ? Colors
                                                                            .redAccent
                                                                      : Colors
                                                                            .greenAccent)
                                                                  .withOpacity(
                                                                    0.15,
                                                                  ),
                                                          borderRadius:
                                                              BorderRadius.zero,
                                                        ),
                                                        child: Text(
                                                          t.status ==
                                                                  TableStatus
                                                                      .occupied
                                                              ? 'OCC'
                                                              : 'FREE',
                                                          style: TextStyle(
                                                            color:
                                                                t.status ==
                                                                    TableStatus
                                                                        .occupied
                                                                ? Colors
                                                                      .redAccent
                                                                : Colors
                                                                      .greenAccent,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: isLocked
                                              ? null
                                              : (id) {
                                                  final table = allTables
                                                      .firstWhere(
                                                        (t) => t.id == id,
                                                      );
                                                  _onTableSelected(table);
                                                },
                                        ),
                                        loading: () =>
                                            const LinearProgressIndicator(),
                                        error: (_, __) => Text(
                                          ref.t('order.errorLoadingTables'),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                  ),
                                  loading: () =>
                                      const LinearProgressIndicator(),
                                  error: (_, __) =>
                                      Text(ref.t('order.errorLoadingWaiters')),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Divider(color: Colors.white10, height: 1),
                          const SizedBox(height: 10),
                          // Items list
                          Expanded(
                            child: activeOrderAsync.when(
                              data: (order) {
                                final savedItems = order?.items ?? [];
                                return ListView(
                                  padding: const EdgeInsets.all(14),
                                  children: [
                                    if (savedItems.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        ref.t('order.sentToKitchen'),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white38,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ...savedItems.map(
                                        (item) => _CartItemTile(
                                          item: item,
                                          isSaved: true,
                                          onVoid: () async {
                                            final confirm =
                                                await _showDeleteConfirmation(
                                                  item.productName,
                                                );
                                            if (!confirm) return;

                                            await ref
                                                .read(posRepositoryProvider)
                                                .voidOrderItem(
                                                  item.id!,
                                                  order!.id!,
                                                );
                                            if (selectedTable != null) {
                                              await ref
                                                  .read(
                                                    activeOrderServiceProvider,
                                                  )
                                                  .refreshTableData(
                                                    selectedTable!.id!,
                                                  );
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    if (localItems.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        ref.t('order.newItems'),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFD4AF37),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ...localItems.asMap().entries.map(
                                        (e) => _CartItemTile(
                                          item: e.value,
                                          isSaved: false,
                                          onAdd: () =>
                                              _updateQuantity(e.key, 1),
                                          onRemove: () =>
                                              _updateQuantity(e.key, -1),
                                          onDelete: () => _removeItem(e.key),
                                          onNote: () => _addNoteToItem(e.key),
                                        ),
                                      ),
                                    ],
                                    if (savedItems.isEmpty &&
                                        localItems.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 80),
                                        child: Center(
                                          child: Opacity(
                                            opacity: 0.3,
                                            child: Column(
                                              children: [
                                                const Icon(
                                                  Icons
                                                      .shopping_basket_outlined,
                                                  size: 56,
                                                ),
                                                const SizedBox(height: 12),
                                                Text(ref.t('order.cartEmpty')),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (e, _) => Text('$e'),
                            ),
                          ),
                          // Summary & actions
                          Consumer(
                            builder: (context, cRef, _) {
                              final chargesAsync = cRef.watch(
                                chargesListProvider,
                              );
                              final appSettingsAsync = cRef.watch(
                                appSettingsProvider,
                              );

                              return chargesAsync.maybeWhen(
                                data: (charges) {
                                  return Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(24),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        activeOrderAsync.maybeWhen(
                                          data: (order) {
                                            final subtotal =
                                                (order?.totalAmount ?? 0) +
                                                _localTotal;
                                            double totalAdditions = 0;
                                            double totalDeductions = 0;
                                            final chargeWidgets = <Widget>[];

                                            for (final c in charges.where(
                                              (c) => c.isActive,
                                            )) {
                                              final amount =
                                                  subtotal * (c.value / 100);
                                              if (c.type == 'addition') {
                                                totalAdditions += amount;
                                              } else {
                                                totalDeductions += amount;
                                              }
                                              chargeWidgets.add(
                                                _SummaryRow(
                                                  '${ref.ln(c.name, c.nameAmharic)} (${c.value}%)',
                                                  '${c.type == 'addition' ? '' : '- '}${amount.toStringAsFixed(2)} ${ref.t('common.currency')}',
                                                  color: c.type == 'addition'
                                                      ? null
                                                      : Colors.redAccent,
                                                ),
                                              );
                                            }

                                            final total =
                                                subtotal +
                                                totalAdditions -
                                                totalDeductions -
                                                _discountAmount;

                                            return Column(
                                              children: [
                                                _SummaryRow(
                                                  ref.t('order.subtotal'),
                                                  '${subtotal.toStringAsFixed(2)} ${ref.t('common.currency')}',
                                                ),
                                                ...chargeWidgets,
                                                if (_discountAmount > 0)
                                                  _SummaryRow(
                                                    ref.t('order.discount'),
                                                    '- ${_discountAmount.toStringAsFixed(2)} ${ref.t('common.currency')}',
                                                    color: Colors.greenAccent,
                                                  ),
                                                const Divider(
                                                  color: Colors.white10,
                                                  height: 16,
                                                ),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      ref.t('order.total'),
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${total.toStringAsFixed(2)} ${ref.t('common.currency')}',
                                                      style: const TextStyle(
                                                        fontSize: 24,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color: Color(
                                                          0xFFD4AF37,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            );
                                          },
                                          orElse: () => const SizedBox(),
                                        ),
                                        const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.orange
                                                        .withOpacity(0.85),
                                                    foregroundColor: Colors.white,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 18,
                                                        ),
                                                    shape:
                                                        const RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.zero,
                                                        ),
                                                  ),
                                                  onPressed:
                                                      (_isProcessing || localItems.isEmpty ||
                                                          selectedTable == null)
                                                      ? null
                                                      : () async {
                                                        final settings = ref.read(appSettingsProvider).value ?? {};
                                                        final activeOrder = ref.read(activeOrderProvider(selectedTable!.id!)).value;
                                                        await _sendToKitchen(activeOrder, settings);
                                                      },
                                                  child: Text(
                                                    ref.t('order.sendToKitchen'),
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: (_billPrinted || _bothPrinted)
                                                        ? Colors.white12
                                                        : const Color(0xFF006B3C),
                                                    foregroundColor: (_billPrinted || _bothPrinted)
                                                        ? Colors.white30
                                                        : Colors.white,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 18,
                                                        ),
                                                    shape:
                                                        const RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.zero,
                                                        ),
                                                  ),
                                                  onPressed:
                                                      (_isProcessing || activeOrderAsync.value == null ||
                                                          selectedTable == null || _billPrinted || _bothPrinted)
                                                      ? null
                                                      : () async {
                                                        final settings = ref.read(appSettingsProvider).value ?? {};
                                                        final activeOrder = ref.read(activeOrderProvider(selectedTable!.id!)).value;
                                                        if (activeOrder != null) {
                                                          await _printBill(activeOrder, settings);
                                                        }
                                                      },
                                                  child: Text(
                                                    ref.t('order.printBill'),
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          // ── Combined Print Order + Bill ──
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              icon: Icon(
                                                _bothPrinted ? Icons.check_circle_outline : Icons.print_outlined,
                                                size: 18,
                                              ),
                                              label: Text(
                                                _bothPrinted
                                                    ? ref.t('reports.combinedPrintGenerated')
                                                    : ref.t('order.printBoth'),
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _bothPrinted
                                                    ? Colors.white12
                                                    : const Color(0xFF1A3A5C),
                                                foregroundColor: _bothPrinted
                                                    ? Colors.white30
                                                    : Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 14),
                                                shape: const RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.zero,
                                                ),
                                              ),
                                              onPressed: (_isProcessing || _bothPrinted || _kitchenPrinted || _billPrinted || selectedTable == null || (activeOrderAsync.value == null && localItems.isEmpty))
                                                  ? null
                                                  : () async {
                                                      final settings = ref.read(appSettingsProvider).value ?? {};
                                                      final activeOrder = ref.read(activeOrderProvider(selectedTable!.id!)).value;
                                                      await _printBoth(activeOrder, settings);
                                                    },
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                                orElse: () => const SizedBox(height: 80),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Summary row helper ────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _SummaryRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: color ?? Colors.white54, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(color: color ?? Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Bill confirm dialog ───────────────────────────────────────────────────

class _BillConfirmDialog extends ConsumerStatefulWidget {
  final OrderModel order;
  final double subtotal;
  final List<ChargeModel> charges;
  final bool discountEnabled;
  final double initialDiscount;
  final String initialPaymentMethod;
  final ValueChanged<double> onDiscountChanged;
  final ValueChanged<String> onPaymentMethodChanged;

  const _BillConfirmDialog({
    required this.order,
    required this.subtotal,
    required this.charges,
    required this.discountEnabled,
    required this.initialDiscount,
    this.initialPaymentMethod = 'cash',
    required this.onDiscountChanged,
    required this.onPaymentMethodChanged,
  });

  @override
  ConsumerState<_BillConfirmDialog> createState() => _BillConfirmDialogState();
}

class _BillConfirmDialogState extends ConsumerState<_BillConfirmDialog> {
  late TextEditingController _discountCtrl;
  double _discount = 0;
  String _paymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    _discount = widget.initialDiscount;
    _paymentMethod = widget.initialPaymentMethod;
    _discountCtrl = TextEditingController(
      text: _discount > 0 ? _discount.toString() : '',
    );
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Text(ref.t('order.confirmBill')),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Row(ref.t('order.items'), '${widget.order.items.length}'),
            _Row(
              ref.t('order.subtotal'),
              '${widget.subtotal.toStringAsFixed(2)} ${ref.t('common.currency')}',
            ),
            ...widget.charges.map((c) {
              final amount = widget.subtotal * (c.value / 100);
              return _Row(
                '${ref.ln(c.name, c.nameAmharic)} (${c.value}%)',
                '${(c.type == 'addition' ? '' : '- ')}${amount.toStringAsFixed(2)} ${ref.t('common.currency')}',
              );
            }),
            if (widget.discountEnabled) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _discountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: ref.t('common.discountLabel'),
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(
                    Icons.discount_outlined,
                    color: Colors.white38,
                  ),
                ),
                onChanged: (v) {
                  setState(() {
                    _discount = double.tryParse(v) ?? 0;
                    widget.onDiscountChanged(_discount);
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                dropdownColor: const Color(0xFF1A1A1A),
                decoration: InputDecoration(
                  labelText: ref.t('order.paymentMethod'),
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(
                    Icons.payments_outlined,
                    color: Colors.white38,
                  ),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'cash',
                    child: Text(ref.t('order.paymentCash'), style: const TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem(
                    value: 'card',
                    child: Text(
                      ref.t('order.paymentCard'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'mobile',
                    child: Text(
                      ref.t('order.paymentMobile'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'other',
                    child: Text(ref.t('order.paymentOther'), style: const TextStyle(color: Colors.white)),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _paymentMethod = v);
                    widget.onPaymentMethodChanged(v);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
            const Divider(color: Colors.white10),
            Builder(
              builder: (context) {
                double totalAdditions = 0;
                double totalDeductions = 0;
                for (final c in widget.charges) {
                  final amount = widget.subtotal * (c.value / 100);
                  if (c.type == 'addition')
                    totalAdditions += amount;
                  else
                    totalDeductions += amount;
                }
                final total =
                    widget.subtotal +
                    totalAdditions -
                    totalDeductions -
                    _discount;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ref.t('order.total'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${total.toStringAsFixed(2)} ${ref.t('common.currency')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(ref.t('common.cancel')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF006B3C),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(ref.t('order.confirmAndPrint')),
        ),
      ],
    );
  }

  Widget _Row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54)),
        Text(value, style: const TextStyle(color: Colors.white70)),
      ],
    ),
  );
}

// ── Cart item tile ────────────────────────────────────────────────────────

class _CartItemTile extends ConsumerWidget {
  final OrderItem item;
  final bool isSaved;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  final VoidCallback? onDelete;
  final VoidCallback? onNote;
  final VoidCallback? onVoid;

  const _CartItemTile({
    required this.item,
    required this.isSaved,
    this.onAdd,
    this.onRemove,
    this.onDelete,
    this.onNote,
    this.onVoid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSaved
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFD4AF37).withOpacity(0.05),
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: isSaved
              ? Colors.white10
              : const Color(0xFFD4AF37).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '${ref.t('bill.unitAmount')}: ${item.unitPrice.toStringAsFixed(2)}  |  ${ref.t('bill.qty')}: ${item.quantity}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty)
                      Text(
                        '${ref.t('common.notes')}: ${item.notes}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white38,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                item.subtotal.toStringAsFixed(2),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSaved ? Colors.white70 : const Color(0xFFD4AF37),
                ),
              ),
              const SizedBox(width: 8),
              if (!isSaved) ...[
                _IconBtn(Icons.note_alt_outlined, onNote, Colors.white38),
                _IconBtn(Icons.remove_circle_outline, onRemove, Colors.white54),
                _IconBtn(Icons.add_circle_outline, onAdd, Colors.white54),
                _IconBtn(Icons.delete_outline, onDelete, Colors.redAccent),
              ] else ...[
                _IconBtn(
                  Icons.remove_circle_outline,
                  onVoid,
                  Colors.redAccent,
                  tooltip: ref.t('order.voidItem'),
                ),
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF006B3C),
                  size: 18,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final String? tooltip;
  const _IconBtn(this.icon, this.onPressed, this.color, {this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: IconButton(
        icon: Icon(icon, size: 18, color: color),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      ),
    );
  }
}

class SearchIntent extends Intent {
  const SearchIntent();
}

class WaiterSearchIntent extends Intent {
  const WaiterSearchIntent();
}

class SendToKitchenIntent extends Intent {
  const SendToKitchenIntent();
}

// ── Held Orders Inline Panel ──────────────────────────────────────────────

class _HeldOrdersInlinePanel extends ConsumerWidget {
  const _HeldOrdersInlinePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 160),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.2)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.layers_outlined,
                    color: Color(0xFFD4AF37),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ref.t('order.heldOrders'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.white54,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(ordersProvider),
                    icon: const Icon(Icons.refresh, size: 13),
                    label: Text(
                      ref.t('order.refresh'),
                      style: const TextStyle(fontSize: 10),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white24,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: ordersAsync.when(
                data: (orders) {
                  final pending = orders
                      .where((o) => o.status == OrderStatus.pending)
                      .toList();

                  if (pending.isEmpty) {
                    return Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 18,
                            color: Colors.white.withOpacity(0.08),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            ref.t('order.noPendingOrders'),
                            style: const TextStyle(
                              color: Colors.white12,
                              fontSize: 12,
                            ),
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
                      final diff = DateTime.now().difference(order.createdAt);
                      final timerColor = diff.inMinutes > 30
                          ? Colors.redAccent
                          : diff.inMinutes > 15
                          ? Colors.orangeAccent
                          : Colors.greenAccent;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          onTap: () {
                            final table = TableModel(
                              id: order.tableId,
                              name: order.tableName,
                              status: TableStatus.occupied,
                            );
                            ref.read(selectedTableProvider.notifier).set(table);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.07),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: timerColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.zero,
                                  ),
                                  child: Icon(
                                    Icons.table_bar,
                                    color: timerColor,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.tableName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      Text(
                                        '${order.waiterName}  •  ${order.items.length} items',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white38,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${diff.inMinutes}m',
                                      style: TextStyle(
                                        color: timerColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${order.totalAmount.toStringAsFixed(2)} ETB',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFD4AF37),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white12,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: LinearProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ── Quick Quantity Picker Dialog ──────────────────────────────────────────

class _QuickQtyDialog extends ConsumerStatefulWidget {
  final Product product;
  const _QuickQtyDialog({required this.product});

  @override
  ConsumerState<_QuickQtyDialog> createState() => _QuickQtyDialogState();
}

class _QuickQtyDialogState extends ConsumerState<_QuickQtyDialog> {
  int qty = 1;
  late TextEditingController _ctrl;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '1');
    _ctrl.addListener(() {
      final v = int.tryParse(_ctrl.text);
      if (v != null && v > 0 && v != qty) {
        setState(() => qty = v);
      }
    });
    Future.microtask(() {
      _ctrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _ctrl.text.length,
      );
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setQty(int q) {
    setState(() => qty = q);
    _ctrl.text = '$q';
    _ctrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _ctrl.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.product.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.product.price.toStringAsFixed(2)} ETB',
              style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _ctrl,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: ref.t('order.enterQuantity'),
                hintStyle: const TextStyle(color: Colors.white10, fontSize: 16),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white10),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFD4AF37)),
                ),
              ),
              onSubmitted: (v) {
                final n = int.tryParse(v) ?? 1;
                if (n > 0) Navigator.pop(context, n);
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: () {
                  final n = int.tryParse(_ctrl.text) ?? 1;
                  if (n > 0) Navigator.pop(context, n);
                },
                child: const Text(
                  'CONFIRM',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Suggestion Dropdown ───────────────────────────────────────────────────

class _SuggestionDropdown extends StatelessWidget {
  final List<Widget> children;
  const _SuggestionDropdown({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

// ── Suggestion Item ───────────────────────────────────────────────────────

class _SuggestionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isHighlighted;
  final Color? accentColor;
  final VoidCallback onTap;

  const _SuggestionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isHighlighted,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? const Color(0xFFD4AF37);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: isHighlighted ? accent.withOpacity(0.07) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isHighlighted ? accent : Colors.transparent,
              width: 3,
            ),
            bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isHighlighted ? accent : Colors.white38,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isHighlighted ? Colors.white : Colors.white70,
                      fontWeight: isHighlighted
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isHighlighted
                          ? accent.withOpacity(0.8)
                          : Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isHighlighted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: accent.withOpacity(0.4)),
                ),
                child: Text(
                  '↵ Enter',
                  style: TextStyle(color: accent, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
