import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/models/category.dart';
import 'package:st_george_pos/models/product.dart';
import 'package:st_george_pos/models/waiter.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/providers/pos_providers.dart';
import 'package:st_george_pos/core/widgets/glass_container.dart';
import 'package:intl/intl.dart';

// --- Menu Management Screen ---
class MenuManagementScreen extends ConsumerStatefulWidget {
  const MenuManagementScreen({super.key});
  @override
  ConsumerState<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends ConsumerState<MenuManagementScreen> {
  int? selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(productsProvider(selectedCategoryId));

    return Row(
      children: [
        // Categories Column
        Expanded(
          flex: 1,
          child: GlassContainer(
            opacity: 0.05,
            child: Column(
              children: [
                _Header(
                  title: 'Categories', 
                  onAdd: () => _showAddCategoryDialog(context),
                ),
                Expanded(
                  child: categoriesAsync.when(
                    data: (categories) => ListView.builder(
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        return ListTile(
                          title: Text(cat.name, style: TextStyle(
                            color: selectedCategoryId == cat.id ? const Color(0xFFD4AF37) : Colors.white,
                            fontWeight: selectedCategoryId == cat.id ? FontWeight.bold : FontWeight.normal,
                          )),
                          selected: selectedCategoryId == cat.id,
                          onTap: () => setState(() => selectedCategoryId = cat.id),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => _deleteCategory(cat.id!),
                          ),
                        );
                      },
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Products Column
        Expanded(
          flex: 2,
          child: GlassContainer(
            opacity: 0.05,
            child: Column(
              children: [
                _Header(
                  title: 'Products', 
                  onAdd: selectedCategoryId == null ? null : () => _showAddProductDialog(context),
                ),
                Expanded(
                  child: productsAsync.when(
                    data: (products) => ListView.builder(
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final p = products[index];
                        return ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.fastfood, color: Color(0xFFD4AF37))),
                          title: Text(p.name),
                          subtitle: Text('${p.price.toStringAsFixed(2)} ETB'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => _deleteProduct(p.id!),
                          ),
                        );
                      },
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Category Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            if (controller.text.isNotEmpty) {
              await ref.read(posRepositoryProvider).addCategory(controller.text);
              ref.invalidate(categoriesProvider);
              Navigator.pop(context);
            }
          }, child: const Text('Add')),
        ],
      ),
    );
  }

  void _showAddProductDialog(BuildContext context) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(hintText: 'Product Name')),
            TextField(controller: priceController, decoration: const InputDecoration(hintText: 'Price'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            final price = double.tryParse(priceController.text);
            if (nameController.text.isNotEmpty && price != null) {
              await ref.read(posRepositoryProvider).addProduct(Product(
                categoryId: selectedCategoryId!,
                name: nameController.text,
                price: price,
              ));
              ref.invalidate(productsProvider(selectedCategoryId));
              ref.invalidate(productsProvider(null));
              Navigator.pop(context);
            }
          }, child: const Text('Add')),
        ],
      ),
    );
  }

  void _deleteCategory(int id) async {
    await ref.read(posRepositoryProvider).deleteCategory(id);
    ref.invalidate(categoriesProvider);
    ref.invalidate(productsProvider(null));
    if (selectedCategoryId == id) setState(() => selectedCategoryId = null);
  }

  void _deleteProduct(int id) async {
    await ref.read(posRepositoryProvider).deleteProduct(id);
    ref.invalidate(productsProvider(selectedCategoryId));
    ref.invalidate(productsProvider(null));
  }
}

// --- Waiter Management Screen ---
class WaiterManagementScreen extends ConsumerWidget {
  const WaiterManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waitersAsync = ref.watch(waitersProvider);

    return GlassContainer(
      opacity: 0.05,
      child: Column(
        children: [
          _Header(title: 'Waiters', onAdd: () => _showAddWaiterDialog(context, ref)),
          Expanded(
            child: waitersAsync.when(
              data: (waiters) => ListView.builder(
                itemCount: waiters.length,
                itemBuilder: (context, index) {
                  final w = waiters[index];
                  return ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFFD4AF37), child: Icon(Icons.person, color: Colors.black)),
                    title: Text(w.name),
                    subtitle: Text('Code: ${w.code}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () async {
                        await ref.read(posRepositoryProvider).deleteWaiter(w.id!);
                        ref.refresh(waitersProvider);
                      },
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddWaiterDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Waiter'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Waiter Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            if (controller.text.isNotEmpty) {
              await ref.read(posRepositoryProvider).addWaiter(controller.text);
              ref.refresh(waitersProvider);
              Navigator.pop(context);
            }
          }, child: const Text('Add')),
        ],
      ),
    );
  }
}

// --- Order History Screen ---
class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);

    return GlassContainer(
      opacity: 0.05,
      child: Column(
        children: [
          const _Header(title: 'Order History'),
          Expanded(
            child: orders.when(
              data: (orderList) => ListView.builder(
                itemCount: orderList.length,
                itemBuilder: (context, index) {
                  final o = orderList[index];
                  return ExpansionTile(
                    title: Text('Order #${o.id} - ${o.tableName}'),
                    subtitle: Text('Waiter: ${o.waiterName} | Total: ${o.totalAmount.toStringAsFixed(2)} ETB'),
                    children: [
                      ...o.items.map((item) => ListTile(
                        dense: true,
                        title: Text(item.productName),
                        trailing: Text('${item.quantity} x ${item.unitPrice}'),
                      )),
                    ],
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Reports Screen ---
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);

    return orders.when(
      data: (orderList) {
        final totalRevenue = orderList.fold(0.0, (sum, o) => sum + o.totalAmount);
        final totalVat = totalRevenue * 0.05;
        final totalWithVat = totalRevenue + totalVat;
        final totalItems = orderList.fold(0, (sum, o) => sum + o.items.fold(0, (s, i) => s + i.quantity));

        return GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          children: [
            _ReportCard(title: 'Total Sales', value: '${totalRevenue.toStringAsFixed(2)} ETB', icon: Icons.attach_money),
            _ReportCard(title: 'VAT Collected (5%)', value: '${totalVat.toStringAsFixed(2)} ETB', icon: Icons.account_balance_wallet),
            _ReportCard(title: 'Total Revenue', value: '${totalWithVat.toStringAsFixed(2)} ETB', icon: Icons.trending_up, color: const Color(0xFFD4AF37)),
            _ReportCard(title: 'Orders Processed', value: '${orderList.length}', icon: Icons.shopping_bag),
            _ReportCard(title: 'Items Sold', value: '$totalItems', icon: Icons.fastfood),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

// --- Common Components ---
class _Header extends StatelessWidget {
  final String title;
  final VoidCallback? onAdd;
  const _Header({required this.title, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          if (onAdd != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add New'),
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black),
            ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  const _ReportCard({required this.title, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.1,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color ?? Colors.white54),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color ?? Colors.white)),
          ],
        ),
      ),
    );
  }
}
