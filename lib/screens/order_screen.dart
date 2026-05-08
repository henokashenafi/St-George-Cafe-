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

class OrderScreen extends ConsumerStatefulWidget {
  final TableModel? table;
  const OrderScreen({super.key, this.table});

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  int? selectedCategoryId;
  List<OrderItem> localItems = [];
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Waiter? selectedWaiter;
  double _discountAmount = 0;
  TableModel? selectedTable;

  @override
  void initState() {
    super.initState();
    selectedTable = widget.table;
    Future.microtask(() {
      if (selectedTable != null) {
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

    if (selectedTable == null) {
      await _showTableSelectionDialog(context);
      if (selectedTable == null) return;
    }

    OrderModel? order = existingOrder;
    if (order == null) {
      if (selectedWaiter == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ref.t('order.selectWaiter'))));
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
    final serviceCharge = subtotal * (serviceChargePercent / 100);
    double discount = _discountAmount;

    // Show bill confirmation dialog with discount input
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _BillConfirmDialog(
        order: order,
        subtotal: subtotal,
        serviceCharge: serviceCharge,
        serviceChargePercent: serviceChargePercent,
        discountEnabled: discountEnabled,
        initialDiscount: discount,
        onDiscountChanged: (v) => discount = v,
      ),
    );

    if (confirmed == true) {
      final settings = await ref.read(cafeSettingsProvider.future);
      await BillService.generateAndDownloadBill(
        order: order.copyWith(
          discountAmount: discount,
        ), // Ensure order has the discount
        items: order.items,
        settings: settings,
        cashierName: order.cashierName,
        serviceChargePercent: serviceChargePercent,
        t: ref.t,
      );
      await ref
          .read(posRepositoryProvider)
          .completeOrder(
            order.id!,
            order.tableId,
            serviceCharge: serviceCharge,
            discountAmount: discount,
          );
      ref.refresh(tablesProvider);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeOrderAsync = ref.watch(activeOrderProvider(selectedTable?.id));
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(productsProvider(selectedCategoryId));
    final waitersAsync = ref.watch(waitersProvider);
    final settingsAsync = ref.watch(appSettingsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          '${selectedTable?.name ?? 'NEW'} — ORDER',
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
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
            // ── Menu panel ──────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
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
                                  onSelected: (_) =>
                                      setState(() => selectedCategoryId = null),
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
                                onSelected: (s) => setState(
                                  () => selectedCategoryId = s ? cat.id : null,
                                ),
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
                          final filtered = products
                              .where(
                                (p) => p.name.toLowerCase().contains(
                                  searchQuery.toLowerCase(),
                                ),
                              )
                              .toList();
                          return GridView.builder(
                            padding: EdgeInsets.zero,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 0.9,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final p = filtered[i];
                              return GlassContainer(
                                opacity: 0.1,
                                child: InkWell(
                                  onTap: () => _addItem(p),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.05,
                                            ),
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(16),
                                                ),
                                          ),
                                          child: const Icon(
                                            Icons.fastfood,
                                            size: 44,
                                            color: Color(0xFFD4AF37),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${p.price.toStringAsFixed(2)} ${ref.t('common.currency')}',
                                              style: const TextStyle(
                                                color: Color(0xFFD4AF37),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
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
              margin: const EdgeInsets.fromLTRB(0, 100, 16, 16),
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
                          if (selectedTable != null)
                            Text(
                              selectedTable!.name,
                              style: const TextStyle(
                                color: Color(0xFFD4AF37),
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            TextButton.icon(
                              onPressed: () =>
                                  _showTableSelectionDialog(context),
                              icon: const Icon(
                                Icons.table_restaurant,
                                size: 16,
                                color: Color(0xFFD4AF37),
                              ),
                              label: const Text(
                                'SELECT TABLE',
                                style: TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Waiter selector
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: waitersAsync.when(
                        data: (waiters) => DropdownButtonHideUnderline(
                          child: DropdownButton<Waiter>(
                            hint: Text(
                              ref.t('order.selectWaiter'),
                              style: TextStyle(color: Colors.white54),
                            ),
                            value: selectedWaiter,
                            dropdownColor: const Color(0xFF121212),
                            style: const TextStyle(color: Colors.white),
                            isExpanded: true,
                            icon: const Icon(
                              Icons.person,
                              color: Colors.white38,
                              size: 20,
                            ),
                            items: waiters
                                .map(
                                  (w) => DropdownMenuItem(
                                    value: w,
                                    child: Text(w.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (w) =>
                                setState(() => selectedWaiter = w),
                          ),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => Text(
                          '${ref.t('common.error')}: ${ref.t('order.loadingWaiters')}',
                        ),
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
                                  style: TextStyle(
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
                                  style: TextStyle(
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
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('$e'),
                      ),
                    ),
                    // Summary & actions
                    settingsAsync.when(
                      data: (settings) {
                        final scPercent =
                            double.tryParse(
                              settings['service_charge_percent'] ?? '5',
                            ) ??
                            5;
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
                                            'percent': scPercent
                                                .toStringAsFixed(0),
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
                                        backgroundColor: Colors.orange
                                            .withOpacity(0.85),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 18,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.zero,
                                        ),
                                      ),
                                      onPressed: () => _sendToKitchen(
                                        activeOrderAsync.value,
                                        settings,
                                      ),
                                      child: Text(
                                        ref.t('order.sendToKitchen'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF006B3C,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 18,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.zero,
                                        ),
                                      ),
                                      onPressed: activeOrderAsync.value == null
                                          ? null
                                          : () => _printBill(
                                              activeOrderAsync.value!,
                                              settings,
                                            ),
                                      child: Text(
                                        ref.t('order.printBill'),
                                        style: TextStyle(
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
                      error: (_, __) => const SizedBox(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTableSelectionDialog(BuildContext context) async {
    final tables = await ref.read(posRepositoryProvider).getTables();
    final availableTables = tables
        .where((t) => t.status == TableStatus.available)
        .toList();

    if (!mounted) return;

    final result = await showDialog<TableModel>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Select Table'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: availableTables.isEmpty
              ? const Center(child: Text('No available tables'))
              : ListView.builder(
                  itemCount: availableTables.length,
                  itemBuilder: (ctx, i) => ListTile(
                    title: Text(availableTables[i].name),
                    subtitle: Text(availableTables[i].zoneName ?? 'No Zone'),
                    onTap: () => Navigator.pop(ctx, availableTables[i]),
                  ),
                ),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        selectedTable = result;
      });
      ref.read(activeOrderServiceProvider).refreshTableData(result.id!);
    }
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
