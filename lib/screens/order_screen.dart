import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/models/table_model.dart';
import 'package:st_george_pos/models/product.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/providers/pos_providers.dart';
import 'package:intl/intl.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:st_george_pos/models/waiter.dart';
import 'package:st_george_pos/services/bill_service.dart';

class OrderScreen extends ConsumerStatefulWidget {
  final TableModel table;
  const OrderScreen({super.key, required this.table});

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  int? selectedCategoryId;
  List<OrderItem> localItems = [];
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  Waiter? selectedWaiter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(activeOrderServiceProvider).loadOrderForTable(widget.table.id!);
    });
  }

  void _addItem(Product product) {
    setState(() {
      final index = localItems.indexWhere((item) => item.productId == product.id && !item.isPrintedToKitchen);
      if (index != -1) {
        final existing = localItems[index];
        localItems[index] = existing.copyWith(
          quantity: existing.quantity + 1,
          subtotal: (existing.quantity + 1) * existing.unitPrice,
        );
      } else {
        localItems.add(OrderItem(
          productId: product.id!,
          productName: product.name,
          quantity: 1,
          unitPrice: product.price,
          subtotal: product.price,
        ));
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

  void _removeItem(int index) {
    setState(() {
      localItems.removeAt(index);
    });
  }

  double get _localTotal => localItems.fold(0, (sum, item) => sum + item.subtotal);

  @override
  Widget build(BuildContext context) {
    final activeOrderAsync = ref.watch(activeOrderProvider(widget.table.id!));
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(productsProvider(selectedCategoryId));
    final waitersAsync = ref.watch(waitersProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('${widget.table.name} - ORDER', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.print), onPressed: () {}),
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
            // Menu Section
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                child: Column(
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: GlassContainer(
                        opacity: 0.05,
                        borderRadius: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search products...',
                            border: InputBorder.none,
                            icon: Icon(Icons.search, color: Colors.white54),
                          ),
                          onChanged: (val) => setState(() => searchQuery = val),
                        ),
                      ),
                    ),
                    // Categories
                    SizedBox(
                      height: 50,
                      child: categoriesAsync.when(
                        data: (categories) => ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: const Text('All'),
                                  selected: selectedCategoryId == null,
                                  onSelected: (s) => setState(() => selectedCategoryId = null),
                                  selectedColor: const Color(0xFFD4AF37),
                                ),
                              );
                            }
                            final cat = categories[index - 1];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(cat.name),
                                selected: selectedCategoryId == cat.id,
                                onSelected: (s) => setState(() => selectedCategoryId = s ? cat.id : null),
                                selectedColor: const Color(0xFFD4AF37),
                              ),
                            );
                          },
                        ),
                        loading: () => const SizedBox(),
                        error: (e, _) => Text('Error: $e'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Products Grid
                    Expanded(
                      child: productsAsync.when(
                        data: (products) {
                          final filteredProducts = products.where((p) => 
                            p.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();
                          
                          return GridView.builder(
                            padding: EdgeInsets.zero,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.9,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];
                              return GlassContainer(
                                opacity: 0.1,
                                child: InkWell(
                                  onTap: () => _addItem(product),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.05),
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                          ),
                                          child: const Icon(Icons.fastfood, size: 48, color: Color(0xFFD4AF37)),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            Text('${product.price.toStringAsFixed(2)} ETB', 
                                              style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.w600)),
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
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Error: $e'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Cart Section
            Container(
              width: 450,
              margin: const EdgeInsets.fromLTRB(0, 100, 16, 16),
              child: GlassContainer(
                opacity: 0.15,
                borderRadius: 24,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_cart, color: Color(0xFFD4AF37)),
                          const SizedBox(width: 12),
                          const Text('CURRENT ORDER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          const Spacer(),
                          Text('${widget.table.name}', style: const TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                      child: waitersAsync.when(
                        data: (waiters) => Row(
                          children: [
                            const Icon(Icons.person, color: Colors.white54, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<Waiter>(
                                  hint: const Text('Select Waiter', style: TextStyle(color: Colors.white54)),
                                  value: selectedWaiter,
                                  dropdownColor: const Color(0xFF121212),
                                  style: const TextStyle(color: Colors.white),
                                  isExpanded: true,
                                  items: (waiters).map<DropdownMenuItem<Waiter>>((w) => DropdownMenuItem<Waiter>(
                                    value: w,
                                    child: Text(w.name),
                                  )).toList(),
                                  onChanged: (w) => setState(() => selectedWaiter = w),
                                ),
                              ),
                            ),
                          ],
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Error loading waiters'),
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    Expanded(
                      child: activeOrderAsync.when(
                        data: (order) {
                          final savedItems = order?.items ?? [];
                          return ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              if (savedItems.isNotEmpty) ...[
                                const Text('PRINTED ITEMS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white38)),
                                const SizedBox(height: 8),
                                ...savedItems.map((item) => _CartItemTile(item: item, isSaved: true)),
                                const SizedBox(height: 24),
                              ],
                              if (localItems.isNotEmpty) ...[
                                const Text('NEW ITEMS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
                                const SizedBox(height: 8),
                                ...localItems.asMap().entries.map((entry) => _CartItemTile(
                                  item: entry.value, 
                                  isSaved: false,
                                  onAdd: () => _updateQuantity(entry.key, 1),
                                  onRemove: () => _updateQuantity(entry.key, -1),
                                  onDelete: () => _removeItem(entry.key),
                                )),
                              ],
                              if (savedItems.isEmpty && localItems.isEmpty)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 100),
                                    child: Opacity(
                                      opacity: 0.3,
                                      child: Column(
                                        children: [
                                          Icon(Icons.shopping_basket_outlined, size: 64),
                                          SizedBox(height: 16),
                                          Text('Cart is empty'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Error: $e'),
                      ),
                    ),
                    // Summary & Actions
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Amount', style: TextStyle(fontSize: 18, color: Colors.white70)),
                              activeOrderAsync.maybeWhen(
                                data: (order) {
                                  final subtotal = (order?.totalAmount ?? 0) + _localTotal;
                                  final vat = subtotal * 0.05;
                                  final total = subtotal + vat;
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Subtotal: ${subtotal.toStringAsFixed(2)} ETB',
                                        style: const TextStyle(fontSize: 14, color: Colors.white54),
                                      ),
                                      Text(
                                        'VAT (5%): ${vat.toStringAsFixed(2)} ETB',
                                        style: const TextStyle(fontSize: 14, color: Colors.white54),
                                      ),
                                      Text(
                                        '${total.toStringAsFixed(2)} ETB',
                                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFD4AF37)),
                                      ),
                                    ],
                                  );
                                },
                                orElse: () => const Text('0.00 ETB'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.withOpacity(0.8),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onPressed: () async {
                                    if (localItems.isEmpty) return;
                                    
                                    OrderModel? order = activeOrderAsync.value;
                                    if (order == null) {
                                      if (selectedWaiter == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please select a waiter first')),
                                        );
                                        return;
                                      }
                                      // Create new order
                                      await ref.read(activeOrderServiceProvider).createNewOrder(OrderModel(
                                        tableId: widget.table.id!,
                                        waiterId: selectedWaiter!.id!, 
                                        tableName: widget.table.name,
                                        waiterName: selectedWaiter!.name,
                                        createdAt: DateTime.now(),
                                        updatedAt: DateTime.now(),
                                      ));
                                      order = ref.read(activeOrderProvider(widget.table.id!)).value;
                                    }

                                    if (order != null) {
                                      final itemsToPrint = localItems.map((e) => e.copyWith(isPrintedToKitchen: true)).toList();
                                      await ref.read(activeOrderServiceProvider).addItems(order.id!, itemsToPrint, widget.table.id!);
                                      
                                      // Kitchen Printing logic
                                      final printer = ref.read(printServiceProvider);
                                      await printer.generateKitchenReceipt(order, localItems);
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Order sent to Kitchen')),
                                      );
                                    }
                                    
                                    setState(() => localItems = []);
                                  },
                                  child: const Text('HOLD / KITCHEN', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF006B3C),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onPressed: () async {
                                    final order = activeOrderAsync.value;
                                    if (order == null || order.items.isEmpty) return;

                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Print Bill & Finalize?'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Items: ${order.items.length}'),
                                            Text('Total (incl. 5% VAT): ${(order.totalAmount * 1.05).toStringAsFixed(2)} ETB'),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(context, true), 
                                            child: const Text('Print PDF & Complete'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      // PDF Generation
                                      await BillService.generateAndDownloadBill(
                                        order: order,
                                        items: order.items,
                                        tableName: widget.table.name,
                                        waiterName: order.waiterName ?? 'N/A',
                                      );

                                      await ref.read(posRepositoryProvider).completeOrder(order.id!, order.tableId);
                                      ref.refresh(tablesProvider);
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: const Text('PRINT BILL', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
}

class _CartItemTile extends StatelessWidget {
  final OrderItem item;
  final bool isSaved;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  final VoidCallback? onDelete;

  const _CartItemTile({
    required this.item,
    required this.isSaved,
    this.onAdd,
    this.onRemove,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSaved ? Colors.white.withOpacity(0.05) : const Color(0xFFD4AF37).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSaved ? Colors.white10 : const Color(0xFFD4AF37).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${item.unitPrice.toStringAsFixed(2)} x ${item.quantity}', 
                  style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            ),
          ),
          Text(
            '${item.subtotal.toStringAsFixed(2)}', 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              color: isSaved ? Colors.white70 : const Color(0xFFD4AF37)
            )
          ),
          const SizedBox(width: 12),
          if (!isSaved) ...[
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: onAdd,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ] else
            const Icon(Icons.check_circle, color: Color(0xFF006B3C), size: 20),
        ],
      ),
    );
  }
}
