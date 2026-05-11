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
import 'package:st_george_pos/core/widgets/top_toaster.dart';
import '../models/charge.dart';

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

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _waiterSearchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _waiterSearchFocusNode = FocusNode();

  // Track latest visible filtered products for Enter-to-add
  List<Product> _lastFilteredProducts = [];

  String _sortOption = 'alpha';
  Waiter? selectedWaiter;
  double _discountAmount = 0;
  TableModel? get selectedTable => ref.watch(selectedTableProvider);

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
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

  void _addFirstFilteredItem() {
    if (_lastFilteredProducts.isNotEmpty) {
      _addItem(_lastFilteredProducts.first);
      // Clear search after adding so cashier sees full menu again
      _searchController.clear();
    }
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
    final confirm = await _showDeleteConfirmation(localItems[index].productName);
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
            content: Text(ref.t('order.removeConfirmMessage',
                replacements: {'product': productName})),
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

  Future<void> _sendToKitchen(
    OrderModel? existingOrder,
    Map<String, String> settings,
  ) async {
    if (localItems.isEmpty) return;

    if (selectedTable == null) {
      TopToaster.show(context, ref.t('dashboard.selectTable'), isError: true);
      return;
    }

    OrderModel? order = existingOrder;
    if (order == null) {
      if (selectedWaiter == null) {
        TopToaster.show(context, ref.t('order.selectWaiter'), isError: true);
        return;
      }
      final currentUser = ref.read(authProvider)!;
      order = await ref
          .read(activeOrderServiceProvider)
          .createNewOrder(
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
    }
    if (order != null) {
      final itemsToPrint = localItems
          .map((e) => e.copyWith(isPrintedToKitchen: true))
          .toList();

      final roundNumber = await ref
          .read(activeOrderServiceProvider)
          .addItems(order.id!, itemsToPrint, selectedTable!.id!);

      // Kitchen Printing PDF
      await BillService.generateKitchenSlip(
        order: order,
        items: localItems,
        roundNumber: roundNumber,
        t: (key, {replacements}) =>
            AppLocalizations.getEnglish(key, replacements: replacements),
      );

      await ref.read(auditServiceProvider).log(
            'Sent to Kitchen',
            details: 'Table: ${selectedTable!.name}, Items: ${localItems.length}, Round: $roundNumber',
          );

      if (roundNumber != null) {
        TopToaster.show(context, ref.t('order.sentToKitchen'));
      }
    }
    setState(() => localItems = []);
  }

  Future<void> _printBill(
    OrderModel order,
    Map<String, String> settings,
  ) async {
    final serviceChargePercent =
        double.tryParse(settings['service_charge_percent'] ?? '5') ?? 5;
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

    if (order.items.isEmpty) return;

    final subtotal = order.totalAmount;
    double discount = _discountAmount;
    final charges = (await ref.read(chargesProvider.future)).where((c) => c.isActive).toList();

    // Show bill confirmation dialog with discount input
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _BillConfirmDialog(
        order: order,
        subtotal: subtotal,
        charges: charges,
        discountEnabled: discountEnabled,
        initialDiscount: discount,
        initialPaymentMethod: order.paymentMethod,
        onDiscountChanged: (v) => discount = v,
        onPaymentMethodChanged: (v) => order = order.copyWith(paymentMethod: v),
      ),
    );

    if (confirmed == true) {
      final settings = await ref.read(cafeSettingsProvider.future);
      final charges = (await ref.read(chargesProvider.future)).where((c) => c.isActive).toList();
      
      await BillService.generateAndDownloadBill(
        order: order.copyWith(
          discountAmount: discount,
        ), // Ensure order has the discount
        items: order.items,
        settings: settings,
        cashierName: order.cashierName,
        activeCharges: charges,
        t: (key, {replacements}) =>
            AppLocalizations.getEnglish(key, replacements: replacements),
      );
      double totalAdditions = 0;
      double totalDeductions = 0;
      for (final c in charges) {
        final amount = order.totalAmount * (c.value / 100);
        if (c.type == 'addition') totalAdditions += amount;
        else totalDeductions += amount;
      }

      await ref
          .read(posRepositoryProvider)
          .completeOrder(
            order.id!,
            order.tableId,
            cashierId: ref.read(authProvider)?.id,
            serviceCharge: totalAdditions,
            discountAmount: discount + totalDeductions,
            paymentMethod: order.paymentMethod,
          );
      
      await ref.read(auditServiceProvider).log(
            'Order Completed',
            details: 'ID: ${order.id}, Total: ${subtotal.toStringAsFixed(2)}, Table: ${order.tableName}',
          );

      ref.refresh(tablesProvider);
      ref.read(selectedTableProvider.notifier).set(null);
      ref.read(dashboardViewProvider.notifier).state = DashboardView.home;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTable = ref.watch(selectedTableProvider);
    final activeOrderAsync = ref.watch(activeOrderProvider(selectedTable?.id));
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(productsProvider(selectedCategoryId));
    final waitersAsync = ref.watch(waitersProvider);
    final settingsAsync = ref.watch(appSettingsProvider);

    // Top-level Focus captures ALL key presses when nothing else has focus.
    // Any printable char → auto-routes to item search field.
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        // Only react on key-down, ignore if any text field is already focused
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (_searchFocusNode.hasFocus || _waiterSearchFocusNode.hasFocus) {
          return KeyEventResult.ignored;
        }
        final logical = event.logicalKey;
        // Escape → clear search
        if (logical == LogicalKeyboardKey.escape) {
          _searchController.clear();
          node.requestFocus(); // return focus to the screen
          return KeyEventResult.handled;
        }
        // Ctrl+F → focus search
        if (logical == LogicalKeyboardKey.keyF &&
            HardwareKeyboard.instance.isControlPressed) {
          _focusItemSearch();
          return KeyEventResult.handled;
        }
        // Ctrl+W → focus waiter
        if (logical == LogicalKeyboardKey.keyW &&
            HardwareKeyboard.instance.isControlPressed) {
          _focusWaiterSearch();
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
        // Printable single character → route to item search
        final label = logical.keyLabel;
        if (label.length == 1 && !HardwareKeyboard.instance.isControlPressed) {
          _searchFocusNode.requestFocus();
          // Append the typed character
          final current = _searchController.text;
          final char = HardwareKeyboard.instance.isShiftPressed
              ? label.toUpperCase()
              : label.toLowerCase();
          _searchController.value = TextEditingValue(
            text: current + char,
            selection: TextSelection.collapsed(offset: current.length + 1),
          );
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF): const SearchIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyW): const WaiterSearchIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter): const SendToKitchenIntent(),
          LogicalKeySet(LogicalKeyboardKey.f9): const SendToKitchenIntent(),
        },
        child: Actions(
          actions: {
            SearchIntent: CallbackAction<SearchIntent>(onInvoke: (_) {
              _focusItemSearch();
              return null;
            }),
            WaiterSearchIntent: CallbackAction<WaiterSearchIntent>(onInvoke: (_) {
              _focusWaiterSearch();
              return null;
            }),
            SendToKitchenIntent: CallbackAction<SendToKitchenIntent>(onInvoke: (_) {
              settingsAsync.maybeWhen(
                data: (s) => _sendToKitchen(activeOrderAsync.value, s),
                orElse: () => null,
              );
              return null;
            }),
          },
          child: Column(
            children: [
        // Header matching dashboard style
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              Text(
                '${selectedTable?.name ?? 'NEW'} — ORDER',
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
                    ref.read(dashboardViewProvider.notifier).state =
                        DashboardView.home;
                  },
                  tooltip: 'Close Order View',
                ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              // ── Left Sidebar (Categories) ──────────────────────────────
              SizedBox(
                width: 140,
                child: GlassContainer(
                  opacity: 0.03,
                  borderRadius: 0,
                  border: const Border(right: BorderSide(color: Colors.white10)),
                  child: categoriesAsync.when(
                    data: (cats) => ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: cats.length + 1,
                      itemBuilder: (_, i) {
                        final isSelected = i == 0 ? selectedCategoryId == null : selectedCategoryId == cats[i - 1].id;
                        final name = i == 0 ? ref.t('common.all') : cats[i - 1].name;
                        final icon = i == 0 ? Icons.grid_view : Icons.restaurant_menu;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: InkWell(
                            onTap: () => setState(() => selectedCategoryId = i == 0 ? null : cats[i - 1].id),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.5) : Colors.transparent,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    icon,
                                    size: 20,
                                    color: isSelected ? const Color(0xFFD4AF37) : Colors.white38,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    name,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? Colors.white : Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (e, _) => Center(child: Text('$e', style: const TextStyle(fontSize: 10))),
                  ),
                ),
              ),
            // ── Menu panel ──────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: _searchFocusNode.hasFocus
                                    ? const Color(0xFFD4AF37).withOpacity(0.7)
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: GlassContainer(
                              opacity: 0.05,
                              borderRadius: 30,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                decoration: InputDecoration(
                                  hintText: 'Search items... (Ctrl+F)',
                                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                                  border: InputBorder.none,
                                  icon: const Icon(Icons.search, color: Colors.white38, size: 18),
                                  suffixIcon: searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.close, size: 16, color: Colors.white38),
                                          onPressed: () => _searchController.clear(),
                                        )
                                      : null,
                                ),
                                onChanged: (v) => setState(() => searchQuery = v),
                                onSubmitted: (_) => _addFirstFilteredItem(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GlassContainer(
                          opacity: 0.05,
                          borderRadius: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sortOption,
                              dropdownColor: const Color(0xFF121212),
                              icon: const Icon(Icons.sort, color: Color(0xFFD4AF37)),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              items: const [
                                DropdownMenuItem(value: 'alpha', child: Text('A - Z')),
                                DropdownMenuItem(value: 'priceAsc', child: Text('Price \u2191')),
                                DropdownMenuItem(value: 'priceDesc', child: Text('Price \u2193')),
                              ],
                              onChanged: (v) => setState(() => _sortOption = v!),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                          child: productsAsync.when(
                            data: (products) {
                              final filtered = products
                                  .where((p) => p.name.toLowerCase().contains(searchQuery.toLowerCase()))
                                  .toList();
                              if (_sortOption == 'alpha') {
                                filtered.sort((a, b) => a.name.compareTo(b.name));
                              } else if (_sortOption == 'priceAsc') {
                                filtered.sort((a, b) => a.price.compareTo(b.price));
                              } else if (_sortOption == 'priceDesc') {
                                filtered.sort((a, b) => b.price.compareTo(a.price));
                              }
                              // Store for Enter-to-add
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) _lastFilteredProducts = filtered;
                              });

                              return GridView.builder(
                                  padding: EdgeInsets.zero,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 3.2,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (_, i) {
                                    final p = filtered[i];
                                    final isFirstMatch = i == 0 && searchQuery.isNotEmpty;
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: isFirstMatch
                                            ? Border.all(color: const Color(0xFFD4AF37), width: 1.5)
                                            : null,
                                      ),
                                      child: GlassContainer(
                                        opacity: isFirstMatch ? 0.12 : 0.05,
                                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                                        child: InkWell(
                                          onTap: () => _addItem(p),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.restaurant_menu,
                                                  size: 16,
                                                  color: isFirstMatch ? const Color(0xFFD4AF37) : const Color(0xFFD4AF37).withOpacity(0.6),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        p.name,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 13,
                                                          color: isFirstMatch ? Colors.white : Colors.white70,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      Text(
                                                        '${p.price.toStringAsFixed(2)} ${ref.t('common.currency')}',
                                                        style: const TextStyle(
                                                          color: Color(0xFFD4AF37),
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (isFirstMatch)
                                                  const Icon(Icons.keyboard_return, size: 14, color: Color(0xFFD4AF37)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                              );
                            },
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, _) => Text('$e'),
                          ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Cart panel ──────────────────────────────────────────────
            Container(
              width: 460,
              margin: const EdgeInsets.only(bottom: 16, right: 16),
              child: GlassContainer(
                opacity: 0.15,
                borderRadius: 24,
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
                          const Spacer(),
                          SizedBox(
                            width: 150,
                            child: Consumer(
                              builder: (context, ref, _) {
                                final tablesAsync = ref.watch(tablesProvider);
                                return tablesAsync.when(
                                  data: (tables) => DropdownButtonHideUnderline(
                                    child: DropdownButton<TableModel>(
                                      value: tables.where((t) => t.id == selectedTable?.id).firstOrNull,
                                      dropdownColor: const Color(0xFF1A1A1A),
                                      isExpanded: true,
                                      hint: const Text('SELECT TABLE', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 12)),
                                      items: tables.map((t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(t.name, style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.bold)),
                                      )).toList(),
                                      onChanged: (t) {
                                        if (t != null) ref.read(selectedTableProvider.notifier).set(t);
                                      },
                                    ),
                                  ),
                                  loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                  error: (_, __) => const Text('Error', style: TextStyle(fontSize: 10)),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Waiter inline search
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Consumer(
                        builder: (context, ref, _) {
                          final waitersAsync = ref.watch(waitersProvider);
                          final activeOrder = activeOrderAsync.value;
                          final isLocked = activeOrder != null;

                          return waitersAsync.when(
                            data: (allWaiters) {
                              final filteredWaiters = allWaiters
                                  .where((w) => w.name.toLowerCase().contains(waiterSearchQuery.toLowerCase()))
                                  .toList();
                              final currentWaiter = allWaiters
                                  .where((w) => w.id == (activeOrder?.waiterId ?? selectedWaiter?.id))
                                  .firstOrNull;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Waiter search field
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _waiterSearchFocusNode.hasFocus
                                            ? const Color(0xFFD4AF37).withOpacity(0.7)
                                            : Colors.white.withOpacity(0.1),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.person,
                                          size: 18,
                                          color: currentWaiter != null
                                              ? const Color(0xFFD4AF37)
                                              : Colors.white38,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: isLocked
                                              ? Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                  child: Text(
                                                    currentWaiter?.name ?? '—',
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                )
                                              : TextField(
                                                  controller: _waiterSearchController,
                                                  focusNode: _waiterSearchFocusNode,
                                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                                  decoration: InputDecoration(
                                                    hintText: currentWaiter != null
                                                        ? currentWaiter.name
                                                        : 'Waiter... (Ctrl+W)',
                                                    hintStyle: TextStyle(
                                                      color: currentWaiter != null
                                                          ? const Color(0xFFD4AF37)
                                                          : Colors.white38,
                                                      fontSize: 14,
                                                    ),
                                                    border: InputBorder.none,
                                                    isDense: true,
                                                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                                  ),
                                                  onChanged: (_) => setState(() {}),
                                                  onSubmitted: (_) {
                                                    if (filteredWaiters.isNotEmpty) {
                                                      setState(() {
                                                        selectedWaiter = filteredWaiters.first;
                                                        _waiterSearchController.clear();
                                                        _waiterSearchActive = false;
                                                      });
                                                      _waiterSearchFocusNode.unfocus();
                                                    }
                                                  },
                                                ),
                                        ),
                                        if (!isLocked && currentWaiter != null)
                                          IconButton(
                                            icon: const Icon(Icons.close, size: 14, color: Colors.white38),
                                            onPressed: () => setState(() {
                                              selectedWaiter = null;
                                              _waiterSearchController.clear();
                                            }),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Filtered waiter list (shown when searching)
                                  if (!isLocked && _waiterSearchFocusNode.hasFocus && filteredWaiters.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A1A1A),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.white10),
                                      ),
                                      constraints: const BoxConstraints(maxHeight: 180),
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: filteredWaiters.length,
                                        itemBuilder: (_, i) {
                                          final w = filteredWaiters[i];
                                          final isHighlighted = i == 0;
                                          return InkWell(
                                            onTap: () {
                                              setState(() {
                                                selectedWaiter = w;
                                                _waiterSearchController.clear();
                                                _waiterSearchActive = false;
                                              });
                                              _waiterSearchFocusNode.unfocus();
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: isHighlighted
                                                    ? const Color(0xFFD4AF37).withOpacity(0.12)
                                                    : Colors.transparent,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.person_outline,
                                                    size: 16,
                                                    color: isHighlighted
                                                        ? const Color(0xFFD4AF37)
                                                        : Colors.white38,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      w.name,
                                                      style: TextStyle(
                                                        color: isHighlighted ? Colors.white : Colors.white70,
                                                        fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isHighlighted)
                                                    const Icon(Icons.keyboard_return, size: 13, color: Color(0xFFD4AF37)),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              );
                            },
                            loading: () => const SizedBox(height: 44, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                            error: (_, __) => const Text('Error', style: TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    // Items list
                    Expanded(
                      child: activeOrderAsync.when(
                        data: (order) {
                          final savedItems = order?.items ?? [];
                          return ListView(
                            padding: const EdgeInsets.all(14),
                            children: [
                              if (savedItems.isNotEmpty) ...[
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
                                      final confirm = await _showDeleteConfirmation(item.productName);
                                      if (!confirm) return;
                                      
                                      await ref
                                          .read(posRepositoryProvider)
                                          .voidOrderItem(item.id!, order!.id!);
                                      if (selectedTable != null) {
                                        await ref
                                            .read(activeOrderServiceProvider)
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
                                    onAdd: () => _updateQuantity(e.key, 1),
                                    onRemove: () => _updateQuantity(e.key, -1),
                                    onDelete: () => _removeItem(e.key),
                                    onNote: () => _addNoteToItem(e.key),
                                  ),
                                ),
                              ],
                              if (savedItems.isEmpty && localItems.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 80),
                                  child: Center(
                                    child: Opacity(
                                      opacity: 0.3,
                                      child: Column(
                                        children: [
                                          const Icon(
                                            Icons.shopping_basket_outlined,
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
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('$e'),
                      ),
                    ),
                    // Summary & actions
                    Consumer(
                      builder: (context, cRef, _) {
                        final chargesAsync = cRef.watch(chargesListProvider);
                        final appSettingsAsync = cRef.watch(appSettingsProvider);

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
                                      final subtotal = (order?.totalAmount ?? 0) + _localTotal;
                                      double totalAdditions = 0;
                                      double totalDeductions = 0;
                                      final chargeWidgets = <Widget>[];

                                      for (final c in charges.where((c) => c.isActive)) {
                                        final amount = subtotal * (c.value / 100);
                                        if (c.type == 'addition') {
                                          totalAdditions += amount;
                                        } else {
                                          totalDeductions += amount;
                                        }
                                        chargeWidgets.add(
                                          _SummaryRow(
                                            '${c.name} (${c.value}%)',
                                            '${c.type == 'addition' ? '' : '- '}${amount.toStringAsFixed(2)} ${ref.t('common.currency')}',
                                            color: c.type == 'addition' ? null : Colors.redAccent,
                                          ),
                                        );
                                      }

                                      final total = subtotal + totalAdditions - totalDeductions - _discountAmount;

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
                                          const Divider(color: Colors.white10, height: 16),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                ref.t('order.total'),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              Text(
                                                '${total.toStringAsFixed(2)} ${ref.t('common.currency')}',
                                                style: const TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFFD4AF37),
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
                                            backgroundColor: Colors.orange.withOpacity(0.85),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 18),
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.zero,
                                            ),
                                          ),
                                          onPressed: (localItems.isEmpty || selectedTable == null || (activeOrderAsync.value == null && selectedWaiter == null))
                                              ? null
                                              : () => appSettingsAsync.maybeWhen(
                                                    data: (s) => _sendToKitchen(activeOrderAsync.value, s),
                                                    orElse: () => null,
                                                  ),
                                          child: Text(
                                            ref.t('order.sendToKitchen'),
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF006B3C),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 18),
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.zero,
                                            ),
                                          ),
                                          onPressed: (activeOrderAsync.value == null || selectedTable == null)
                                              ? null
                                              : () => appSettingsAsync.maybeWhen(
                                                    data: (s) => _printBill(activeOrderAsync.value!, s),
                                                    orElse: () => null,
                                                  ),
                                          child: Text(
                                            ref.t('order.printBill'),
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ],
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
            ),
          ],       // Row.children
        ),         // Row
      ),           // Expanded
    ],             // Column.children
  ),               // Column
),                 // Actions
),                 // Shortcuts
);                 // Focus
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
            _Row(ref.t('order.subtotal'), '${widget.subtotal.toStringAsFixed(2)} ${ref.t('common.currency')}'),
            ...widget.charges.map((c) {
              final amount = widget.subtotal * (c.value / 100);
              return _Row(
                '${c.name} (${c.value}%)',
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
                  labelText: 'Payment Method',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.payments_outlined, color: Colors.white38),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 'cash', child: Text('CASH', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'card', child: Text('CREDIT CARD', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'mobile', child: Text('MOBILE MONEY', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'other', child: Text('OTHER', style: TextStyle(color: Colors.white))),
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
                  if (c.type == 'addition') totalAdditions += amount;
                  else totalDeductions += amount;
                }
                final total = widget.subtotal + totalAdditions - totalDeductions - _discount;
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
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${item.unitPrice.toStringAsFixed(2)} × ${item.quantity}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
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
