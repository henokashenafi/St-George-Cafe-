import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/models/order_item.dart';
import 'package:st_george_pos/models/order.dart';
import 'package:st_george_pos/locales/app_localizations.dart';

// ── Color constants ────────────────────────────────────────────────────────
const kBg        = Color(0xFF0F1117);
const kSurface   = Color(0xFF1A1D27);
const kBorder    = Color(0xFF2C3044);
const kGold      = Color(0xFFD4AF37);
const kGreen     = Color(0xFF22C55E);
const kRed       = Color(0xFFEF4444);
const kTextSub   = Color(0xFF8B90A0);

// ── Section label ─────────────────────────────────────────────────────────

class SectionLabel extends ConsumerWidget {
  final String text;
  final Color? color;
  const SectionLabel(this.text, {this.color, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: color ?? kTextSub)),
      );
}

// ── Cart item tile ─────────────────────────────────────────────────────────

class CartItemTile extends ConsumerWidget {
  final OrderItem item;
  final bool isSaved;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  final VoidCallback? onDelete;
  final VoidCallback? onNote;
  final VoidCallback? onVoid;

  const CartItemTile({
    super.key,
    required this.item,
    this.isSaved = false,
    this.onAdd,
    this.onRemove,
    this.onDelete,
    this.onNote,
    this.onVoid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSaved ? kSurface.withOpacity(0.6) : kSurface,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Qty badge
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSaved ? kGreen.withOpacity(0.15) : kGold.withOpacity(0.15),
                  borderRadius: BorderRadius.zero,
                ),
                child: Text('${item.quantity}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isSaved ? kGreen : kGold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSaved ? Colors.white60 : Colors.white)),
                    if (item.notes != null && item.notes!.isNotEmpty)
                      Text('📝 ${item.notes}',
                          style: const TextStyle(fontSize: 10, color: kTextSub)),
                  ],
                ),
              ),
              Text('${item.subtotal.toStringAsFixed(2)} ${ref.t('common.currency')}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSaved ? Colors.white38 : Colors.white70)),
              const SizedBox(width: 4),
              if (!isSaved) ...[
                _IconBtn(Icons.remove, onRemove, color: kRed),
                _IconBtn(Icons.add, onAdd, color: kGreen),
                _IconBtn(Icons.notes_outlined, onNote, color: kTextSub),
                _IconBtn(Icons.close, onDelete, color: kRed),
              ] else
                _IconBtn(Icons.remove_circle_outline, onVoid, color: kRed),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  const _IconBtn(this.icon, this.onTap, {required this.color});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      );
}

// ── Summary row ────────────────────────────────────────────────────────────

class SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;
  const SummaryRow(this.label, this.value, {this.color, this.bold = false, super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: bold ? 15 : 12,
                    fontWeight: bold ? FontWeight.w900 : FontWeight.normal,
                    color: color ?? kTextSub)),
            Text(value,
                style: TextStyle(
                    fontSize: bold ? 22 : 13,
                    fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
                    color: color ?? Colors.white70)),
          ],
        ),
      );
}

// ── Bill confirm dialog ────────────────────────────────────────────────────

class BillConfirmDialog extends ConsumerStatefulWidget {
  final OrderModel order;
  final double subtotal;
  final double serviceCharge;
  final double serviceChargePercent;
  final bool discountEnabled;
  final double initialDiscount;
  final ValueChanged<double> onDiscountChanged;

  const BillConfirmDialog({
    super.key,
    required this.order,
    required this.subtotal,
    required this.serviceCharge,
    required this.serviceChargePercent,
    required this.discountEnabled,
    required this.initialDiscount,
    required this.onDiscountChanged,
  });

  @override
  ConsumerState<BillConfirmDialog> createState() => _BillConfirmDialogState();
}

class _BillConfirmDialogState extends ConsumerState<BillConfirmDialog> {
  late TextEditingController _discountCtrl;
  double _discount = 0;

  @override
  void initState() {
    super.initState();
    _discount = widget.initialDiscount;
    _discountCtrl = TextEditingController(
        text: _discount > 0 ? _discount.toString() : '');
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.subtotal + widget.serviceCharge - _discount;
    return AlertDialog(
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      title: Row(
        children: [
          const Icon(Icons.receipt_long, color: kGold),
          const SizedBox(width: 10),
          Text(ref.t('orderConfirm.title'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogRow(ref.t('orderConfirm.table'), widget.order.tableName),
            _DialogRow(ref.t('orderConfirm.waiter'), widget.order.waiterName),
            _DialogRow(ref.t('orderConfirm.items'), '${widget.order.items.length}'),
            const Divider(color: kBorder, height: 20),
            _DialogRow(ref.t('orderConfirm.subtotal'),
                '${widget.subtotal.toStringAsFixed(2)} ${ref.t('common.currency')}'),
            _DialogRow(
                ref.t('orderConfirm.service', replacements: {'percent': widget.serviceChargePercent.toStringAsFixed(0)}),
                '${widget.serviceCharge.toStringAsFixed(2)} ${ref.t('common.currency')}'),
            if (widget.discountEnabled) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _discountCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                ],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Discount (ETB)',
                  labelStyle: const TextStyle(color: kTextSub),
                  filled: true,
                  fillColor: kBg,
                  border: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: kBorder)),
                ),
                onChanged: (v) {
                  setState(() => _discount = double.tryParse(v) ?? 0);
                  widget.onDiscountChanged(_discount);
                },
                onSubmitted: (_) => Navigator.pop(context, true),
              ),
            ],
            const Divider(color: kBorder, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(ref.t('orderConfirm.totalToPay'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15)),
                Text('${total.toStringAsFixed(2)} ${ref.t('common.currency')}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        color: kGold)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(ref.t('orderConfirm.cancel'), style: const TextStyle(color: kTextSub))),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: kGreen, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.print),
          label: Text(ref.t('orderConfirm.printBill')),
        ),
      ],
    );
  }
}

class _DialogRow extends StatelessWidget {
  final String label;
  final String value;
  const _DialogRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: kTextSub, fontSize: 13)),
            Text(value,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      );
}

// ── Product card ───────────────────────────────────────────────────────────

class ProductCard extends ConsumerWidget {
  final String name;
  final double price;
  final VoidCallback onTap;
  const ProductCard(
      {super.key,
      required this.name,
      required this.price,
      required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: kBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kGold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fastfood_outlined,
                  color: kGold, size: 28),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
            const SizedBox(height: 4),
            Text('${price.toStringAsFixed(2)} ${ref.t('common.currency')}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: kGold)),
          ],
        ),
      ),
    );
  }
}
