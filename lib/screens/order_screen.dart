import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/models/table_model.dart';
import 'package:st_george_pos/models/product.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/providers/pos_providers.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:st_george_pos/services/bill_service.dart';
import 'package:st_george_pos/providers/order_workflow_provider.dart';
import 'package:st_george_pos/locales/app_localizations.dart';
import 'package:st_george_pos/models/category.dart';
import 'package:st_george_pos/services/enhanced_print_service.dart';

class OrderScreen extends ConsumerStatefulWidget {
  final TableModel? table;
  const OrderScreen({super.key, this.table});

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  List<OrderItem> localItems = [];
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  double _discountAmount = 0;
  TableModel? selectedTable;

  @override
  void initState() {
    super.initState();
    selectedTable = widget.table;
    Future.microtask(() {
      if (selectedTable != null) {
        // Initialize workflow for selected table
        ref
            .read(orderWorkflowProvider.notifier)
            .initializeForTable(selectedTable!.id!);
        ref
            .read(activeOrderServiceProvider)
            .refreshTableData(selectedTable!.id!);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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
      final newQty = item.quantity + delta;
      if (newQty > 0) {
        localItems[index] = item.copyWith(
          quantity: newQty,
          subtotal: newQty * item.unitPrice,
        );
      } else {
        localItems.removeAt(index);
      }
    });
  }

  void _removeItem(int index) => setState(() => localItems.removeAt(index));

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

    if (selectedTable == null) return;

    final workflowState = ref.read(orderWorkflowProvider);

    // Warn if no waiter but don't block
    if (workflowState.assignedWaiter == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.t('order.noWaiterAssigned'))),
        );
      }
    }

    OrderModel? order = existingOrder;
    if (order == null) {
      try {
        final currentUser = ref.read(authProvider)!;

        // Create new order session using workflow service
        await ref
            .read(orderWorkflowProvider.notifier)
            .createNewOrderSession(
              cashierId: currentUser.id!,
              cashierName: currentUser.username,
            );

        order = ref.read(orderWorkflowProvider).currentOrder;

        if (order == null) {
          throw Exception(ref.t('errors.orderCreationFailed'));
        }

        // Save to database
        order = await ref
            .read(activeOrderServiceProvider)
            .createNewOrder(order);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
        return;
      }
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
        t: ref.t,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ref.t('order.sentToKitchen'))));
      }
    }
    setState(() => localItems = []);
  }

  Future<void> _printBill(
    OrderModel order,
    Map<String, String> settings,
  ) async {
    try {
      // Show print options dialog
      final printOption = await _showPrintOptionsDialog();
      if (printOption == null) return;

      switch (printOption) {
        case 'orderList':
          await EnhancedPrintService.printOrderList(
            order: order,
            settings: settings,
            t: ref.t,
          );
          break;
        case 'finalReceipt':
          // Use current session for receipt
          await EnhancedPrintService.printFinalReceipt(
            combinedOrder: order,
            sessions: [order],
            settings: settings,
            t: ref.t,
          );

          // Complete the order if finalizing
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: Text(ref.t('order.confirmComplete')),
              content: Text(ref.t('order.confirmCompleteMessage')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(ref.t('order.later')),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006B3C),
                  ),
                  child: Text(ref.t('order.yesFinalize')),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            final serviceChargePercent =
                double.tryParse(settings['service_charge_percent'] ?? '5') ?? 5;
            final subtotal = order.totalAmount;
            final sc = subtotal * (serviceChargePercent / 100);

            await ref
                .read(posRepositoryProvider)
                .completeOrder(
                  order.id!,
                  order.tableId,
                  serviceCharge: sc,
                  discountAmount: _discountAmount,
                );

            ref.refresh(tablesProvider);
            if (selectedTable != null) {
              ref
                  .read(activeOrderServiceProvider)
                  .refreshTableData(selectedTable!.id!);
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(ref.t('order.completedAndFreed'))),
            );
          }
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${ref.t('common.error')}: $e')));
    }
  }

  Future<String?> _showPrintOptionsDialog() async {
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

  @override
  Widget build(BuildContext context) {
    final selectedCategoryId = ref.watch(selectedCategoryProvider);
    final activeOrderAsync = ref.watch(activeOrderProvider(selectedTable?.id));
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(productsProvider(selectedCategoryId));
    final settingsAsync = ref.watch(appSettingsProvider);

    return _buildInline(
      context,
      activeOrderAsync,
      categoriesAsync,
      productsAsync,
      settingsAsync,
      selectedCategoryId,
    );
  }

  Widget _buildInline(
    BuildContext context,
    AsyncValue<OrderModel?> activeOrderAsync,
    AsyncValue<List<Category>> categoriesAsync,
    AsyncValue<List<Product>> productsAsync,
    AsyncValue<Map<String, String>> settingsAsync,
    int? selectedCategoryId,
  ) {
    return Row(
      children: [
        // ── Menu panel ────────────────────────────────────────────────
        Expanded(
          flex: 3,
          child: Column(
            children: [
              GlassContainer(
                opacity: 0.05,
                borderRadius: 30,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: ref.t('common.search'),
                    border: InputBorder.none,
                    icon: const Icon(Icons.search, color: Colors.white54),
                  ),
                  onChanged: (v) => setState(() => searchQuery = v),
                ),
              ),
              const SizedBox(height: 12),
              // Category chips
              SizedBox(
                height: 44,
                child: categoriesAsync.when(
                  data: (cats) => ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: cats.length + 1,
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(ref.t('common.all')),
                            selected: selectedCategoryId == null,
                            selectedColor: const Color(0xFFD4AF37),
                            onSelected: (_) => ref
                                .read(selectedCategoryProvider.notifier)
                                .set(null),
                          ),
                        );
                      }
                      final cat = cats[i - 1];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat.name),
                          selected: selectedCategoryId == cat.id,
                          selectedColor: const Color(0xFFD4AF37),
                          onSelected: (s) => ref
                              .read(selectedCategoryProvider.notifier)
                              .set(s ? cat.id : null),
                        ),
                      );
                    },
                  ),
                  loading: () => const SizedBox(),
                  error: (e, _) => Text('$e'),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: productsAsync.when(
                  data: (products) {
                    final filtered = (products as List)
                        .where(
                          (p) => p.name.toLowerCase().contains(
                            searchQuery.toLowerCase(),
                          ),
                        )
                        .toList();
                    if (filtered.isEmpty) {
                      return Center(
                        child: Opacity(
                          opacity: 0.3,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.search_off, size: 48),
                              const SizedBox(height: 8),
                              Text(ref.t('common.noResults')),
                            ],
                          ),
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: EdgeInsets.zero,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _ProductCard(
                        product: filtered[i],
                        onTap: () => _addItem(filtered[i]),
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // ── Cart panel ────────────────────────────────────────────────
        SizedBox(
          width: 400,
          child: GlassContainer(
            opacity: 0.15,
            borderRadius: 24,
            child: Column(
              children: [
                // Table selector
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.t('order.selectTable'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: Colors.white38,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ref
                          .watch(tablesProvider)
                          .when(
                            data: (allTables) => _TableDropdown(
                              allTables: allTables,
                              selectedTable: selectedTable,
                              onSelected: (table) {
                                setState(() => selectedTable = table);
                                ref
                                    .read(orderWorkflowProvider.notifier)
                                    .initializeForTable(table.id!);
                                ref
                                    .read(activeOrderServiceProvider)
                                    .refreshTableData(table.id!);
                              },
                            ),
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => Text('$e'),
                          ),
                    ],
                  ),
                ),
                // Waiter + zone chip
                Consumer(
                  builder: (context, ref, _) {
                    final ws = ref.watch(orderWorkflowProvider);
                    if (ws.isLoading) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: LinearProgressIndicator(),
                      );
                    }
                    if (selectedTable == null) {
                      return const SizedBox.shrink();
                    }
                    final hasWaiter = ws.assignedWaiter != null;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: hasWaiter
                              ? Colors.white.withOpacity(0.04)
                              : Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: hasWaiter
                                ? Colors.white.withOpacity(0.08)
                                : Colors.orange.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: hasWaiter
                                  ? const Color(0xFFD4AF37)
                                  : Colors.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: hasWaiter
                                  ? Text(
                                      ws.assignedWaiter!.name,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    )
                                  : Text(
                                      ref.t('order.noWaiterAssigned'),
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 13,
                                      ),
                                    ),
                            ),
                            if (selectedTable?.zoneName != null)
                              Text(
                                selectedTable!.zoneName!,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Divider(color: Colors.white10, height: 1),
                // Items
                Expanded(
                  child: activeOrderAsync.when(
                    data: (order) {
                      final savedItems = order?.items ?? [];
                      return ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          if (savedItems.isNotEmpty) ...[
                            Text(
                              ref.t('order.savedItems'),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: Colors.white38,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...savedItems.map(
                              (item) => _CartItemTile(
                                item: item,
                                isSaved: true,
                                onVoid: () async {
                                  await ref
                                      .read(posRepositoryProvider)
                                      .voidOrderItem(item.id!, order!.id!);
                                  if (selectedTable != null) {
                                    await ref
                                        .read(activeOrderServiceProvider)
                                        .refreshTableData(selectedTable!.id!);
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
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
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
                              padding: const EdgeInsets.only(top: 60),
                              child: Center(
                                child: Opacity(
                                  opacity: 0.3,
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.shopping_basket_outlined,
                                        size: 48,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(ref.t('order.cartEmpty')),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('$e'),
                  ),
                ),
                // Summary + actions
                settingsAsync.when(
                  data: (settings) {
                    final scPercent =
                        double.tryParse(
                          (settings
                                  as Map<
                                    String,
                                    String
                                  >)['service_charge_percent'] ??
                              '5',
                        ) ??
                        5;
                    return Container(
                      padding: const EdgeInsets.all(16),
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
                                  (order?.totalAmount ?? 0) + _localTotal;
                              final sc = subtotal * (scPercent / 100);
                              final total = subtotal + sc - _discountAmount;
                              return Column(
                                children: [
                                  _SummaryRow(
                                    ref.t('order.subtotal'),
                                    '${subtotal.toStringAsFixed(2)} ${ref.t('common.currency')}',
                                  ),
                                  _SummaryRow(
                                    ref.t(
                                      'order.service',
                                      replacements: {
                                        'percent': scPercent.toStringAsFixed(0),
                                      },
                                    ),
                                    '${sc.toStringAsFixed(2)} ${ref.t('common.currency')}',
                                  ),
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
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        ref.t('order.total'),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        '${total.toStringAsFixed(2)} ${ref.t('common.currency')}',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFFD4AF37),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (scPercent > 0 || _discountAmount > 0)
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.discount_outlined, size: 16),
                                        label: Text(
                                          _discountAmount > 0
                                              ? '${ref.t('order.discount')}: ${_discountAmount.toStringAsFixed(2)}'
                                              : ref.t('order.addDiscount'),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFFD4AF37),
                                          side: const BorderSide(color: Color(0xFFD4AF37)),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        onPressed: () async {
                                          final result = await showDialog<double>(
                                            context: context,
                                            builder: (ctx) => _DiscountDialog(
                                              initialDiscount: _discountAmount,
                                              subtotal: subtotal,
                                            ),
                                          );
                                          if (result != null) {
                                            setState(() => _discountAmount = result);
                                          }
                                        },
                                      ),
                                    ),
                                ],
                              );
                            },
                            orElse: () => const SizedBox(),
                          ),
                          const SizedBox(height: 12),
                          if (localItems.isNotEmpty) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.withOpacity(
                                    0.85,
                                  ),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: () async {
                                  if (selectedTable == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          ref.t('order.selectTableFirst'),
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  await _sendToKitchen(
                                    activeOrderAsync.value,
                                    settings as Map<String, String>,
                                  );
                                  ref
                                      .read(selectedCategoryProvider.notifier)
                                      .set(null);
                                },
                                child: Text(
                                  ref.t('order.addToOrder'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF006B3C),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  onPressed: activeOrderAsync.value == null
                                      ? null
                                      : () => _printBill(
                                          activeOrderAsync.value!,
                                          settings as Map<String, String>,
                                        ),
                                  child: Text(
                                    ref.t('order.printBill'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent
                                        .withOpacity(0.8),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(dashboardViewProvider.notifier)
                                        .state = DashboardView
                                        .home;
                                  },
                                  child: Text(
                                    ref.t('common.close'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox(height: 80),
                  error: (e, _) => Text('$e'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Searchable table dropdown ─────────────────────────────────────────────

class _TableDropdown extends ConsumerStatefulWidget {
  final List<TableModel> allTables;
  final TableModel? selectedTable;
  final ValueChanged<TableModel> onSelected;

  const _TableDropdown({
    required this.allTables,
    required this.selectedTable,
    required this.onSelected,
  });

  @override
  ConsumerState<_TableDropdown> createState() => _TableDropdownState();
}

class _TableDropdownState extends ConsumerState<_TableDropdown> {
  final _searchCtrl = TextEditingController();
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _showOverlay(BuildContext context) {
    _removeOverlay();
    final filtered = _filtered();

    _overlay = OverlayEntry(
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeOverlay,
        child: Stack(
          children: [
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 48),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 420,
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.black54, blurRadius: 16),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: ref.t('tableSelector.searchHint'),
                            hintStyle: const TextStyle(color: Colors.white38),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.white38,
                              size: 18,
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (v) {
                            setState(() => _query = v);
                            _overlay?.markNeedsBuild();
                          },
                        ),
                      ),
                      Flexible(
                        child: StatefulBuilder(
                          builder: (ctx, setS) {
                            final items = widget.allTables.where((t) {
                              final query = _searchCtrl.text.toLowerCase();
                              final nameMatch = t.name.toLowerCase().contains(
                                query,
                              );
                              final zoneMatch = (t.zoneName ?? '')
                                  .toLowerCase()
                                  .contains(query);
                              final waiterMatch = (t.waiterName ?? '')
                                  .toLowerCase()
                                  .contains(query);
                              return nameMatch || zoneMatch || waiterMatch;
                            }).toList();
                            if (items.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  ref.t('tableSelector.noTablesFound'),
                                  style: const TextStyle(color: Colors.white38),
                                ),
                              );
                            }
                            return ListView.builder(
                              shrinkWrap: true,
                              itemCount: items.length,
                              itemBuilder: (_, i) {
                                final t = items[i];
                                final isOccupied =
                                    t.status == TableStatus.occupied;
                                final statusKey =
                                    'tableSelector.${t.status.name}';
                                final statusLabel = ref.t(statusKey);
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.table_bar,
                                    size: 18,
                                    color: isOccupied
                                        ? const Color(0xFFD4AF37)
                                        : Colors.white38,
                                  ),
                                  title: Text(
                                    t.name,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    t.zoneName != null
                                        ? '${t.zoneName} · $statusLabel'
                                        : statusLabel,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                  trailing: isOccupied
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF006B3C,
                                            ).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            ref
                                                .t('tableSelector.occupied')
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              color: Color(0xFF006B3C),
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : null,
                                  onTap: () {
                                    _removeOverlay();
                                    widget.onSelected(t);
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlay!);
  }

  List<TableModel> _filtered() => widget.allTables
      .where((t) => t.name.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: () => _showOverlay(context),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.selectedTable != null
                  ? const Color(0xFFD4AF37).withOpacity(0.5)
                  : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.table_bar,
                size: 18,
                color: widget.selectedTable != null
                    ? const Color(0xFFD4AF37)
                    : Colors.white38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.selectedTable?.name ?? ref.t('order.selectTable'),
                  style: TextStyle(
                    color: widget.selectedTable != null
                        ? Colors.white
                        : Colors.white38,
                    fontSize: 14,
                  ),
                ),
              ),
              if (widget.selectedTable?.zoneName != null)
                Text(
                  widget.selectedTable!.zoneName!,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_drop_down, color: Colors.white38),
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
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: color ?? Colors.white54, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
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
  final double serviceCharge;
  final double serviceChargePercent;
  final bool discountEnabled;
  final double initialDiscount;
  final ValueChanged<double> onDiscountChanged;

  const _BillConfirmDialog({
    required this.order,
    required this.subtotal,
    required this.serviceCharge,
    required this.serviceChargePercent,
    required this.discountEnabled,
    required this.initialDiscount,
    required this.onDiscountChanged,
  });

  @override
  ConsumerState<_BillConfirmDialog> createState() => _BillConfirmDialogState();
}

class _BillConfirmDialogState extends ConsumerState<_BillConfirmDialog> {
  late TextEditingController _discountCtrl;
  double _discount = 0;

  @override
  void initState() {
    super.initState();
    _discount = widget.initialDiscount;
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
    final total = widget.subtotal + widget.serviceCharge - _discount;
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
            _Row(
              ref.t(
                'order.service',
                replacements: {
                  'percent': widget.serviceChargePercent.toStringAsFixed(0),
                },
              ),
              '${widget.serviceCharge.toStringAsFixed(2)} ${ref.t('common.currency')}',
            ),
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
                  labelText: ref.t('order.discountLabel'),
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
              const SizedBox(height: 8),
            ],
            const Divider(color: Colors.white10),
            Row(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                _IconBtn(
                  Icons.note_alt_outlined,
                  onNote,
                  Colors.white38,
                  tooltip: ref.t('order.addNote'),
                ),
                _IconBtn(
                  Icons.remove_circle_outline,
                  onRemove,
                  Colors.white54,
                  tooltip: ref.t('order.decreaseQty'),
                ),
                _IconBtn(
                  Icons.add_circle_outline,
                  onAdd,
                  Colors.white54,
                  tooltip: ref.t('order.increaseQty'),
                ),
                _IconBtn(
                  Icons.delete_outline,
                  onDelete,
                  Colors.redAccent,
                  tooltip: ref.t('order.removeItem'),
                ),
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

class _ProductCard extends ConsumerWidget {
  final Product product;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.zero,
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fastfood_outlined,
                color: Color(0xFFD4AF37),
                size: 18,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                product.name,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${product.price.toStringAsFixed(2)} ${ref.t('common.currency')}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD4AF37),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
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
class _DiscountDialog extends ConsumerStatefulWidget {
  final double initialDiscount;
  final double subtotal;

  const _DiscountDialog({
    required this.initialDiscount,
    required this.subtotal,
  });

  @override
  ConsumerState<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends ConsumerState<_DiscountDialog> {
  late TextEditingController _ctrl;
  double _val = 0;

  @override
  void initState() {
    super.initState();
    _val = widget.initialDiscount;
    _ctrl = TextEditingController(text: _val > 0 ? _val.toString() : '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Text(ref.t('order.addDiscount')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: ref.t('order.discountLabel'),
              labelStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.discount_outlined, color: Colors.white38),
            ),
            onChanged: (v) => setState(() => _val = double.tryParse(v) ?? 0),
          ),
          const SizedBox(height: 12),
          Text(
            "${ref.t('order.total')}: ${(widget.subtotal - _val).toStringAsFixed(2)}",
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(ref.t('common.cancel')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.black,
          ),
          onPressed: () => Navigator.pop(context, _val),
          child: Text(ref.t('common.save')),
        ),
      ],
    );
  }
}
