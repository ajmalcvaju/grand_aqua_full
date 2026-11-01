// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/auth_provider.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _notesCtrl = TextEditingController();
  bool _isCheckingOut = false;

  Future<void> _sendForApproval() async {
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) return;

    setState(() => _isCheckingOut = true);
    try {
      final api = ref.read(apiClientProvider);

      final payload = {
        'items': cart.items.map((i) => {
          'productId': i.product['id'],
          'quantity': i.quantity,
        }).toList(),
        'buyerNotes': _notesCtrl.text.trim().isNotEmpty
            ? _notesCtrl.text.trim()
            : 'Quotation sent for approval. Shipping charges pending calculation based on products, quantity, and km distance.',
        'paymentTerms': 'Payment on Delivery / Approved Trade Credit',
      };

      final res = await api.dio.post('/quotations', data: payload);
      final quo = res.data['data'] ?? res.data;

      ref.read(cartProvider.notifier).clear();
      _notesCtrl.clear();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.assignment_turned_in, color: Color(0xFF0284C7), size: 36),
            ),
            title: const Text(
              'Sent for Approval!',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quotation #${quo['quotationNumber'] ?? 'GA-QT-2026'} has been submitted successfully.',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🚚 Next Steps:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF166534)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '1. Quotation forwarded to your assigned sales staff & Super Admin.\n2. Shipping charges will be calculated based on your products, quantity, and distance (km).\n3. Once approved, the finalized quotation will appear in your "Quotes" section for your final confirmation.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF14532D), height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/home');
                },
                child: const Text('Back to Home'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/quotations');
                },
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                child: const Text('View in Quotes'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit for approval: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
      ),
      body: cart.items.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Your cart is empty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cart.items.length,
                    itemBuilder: (ctx, i) {
                      final item = cart.items[i];
                      final p = item.product;
                      final stock = (p['stock'] as num?)?.toInt() ?? 9999;
                      final imgUrl = (p['images'] as List?)?.isNotEmpty == true
                          ? (p['images'] as List).first.toString()
                          : (p['imageUrl'] ?? '').toString();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      color: const Color(0xFFF1F5F9),
                                      child: imgUrl.isNotEmpty
                                          ? Image.network(
                                              imgUrl,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, _, _) => const Icon(Icons.water_drop, color: Color(0xFF0284C7)),
                                            )
                                          : const Icon(Icons.water_drop, color: Color(0xFF0284C7)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p['name'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              '₹${item.unitPrice.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0284C7),
                                              ),
                                            ),
                                            const Text(
                                              ' / piece',
                                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                            ),
                                            if (item.quantity >= 5) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFECFDF5),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                                ),
                                                child: const Text(
                                                  'Bulk Rate',
                                                  style: TextStyle(
                                                    color: Color(0xFF047857),
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                    tooltip: 'Remove',
                                    onPressed: () => ref.read(cartProvider.notifier).removeItem(p['id']),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Item Total: ',
                                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                      Text(
                                        '₹${item.totalPrice.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // + and - quantity controls
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Minus Button
                                        InkWell(
                                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                                          onTap: () {
                                            ref.read(cartProvider.notifier).decrementQuantity(p['id']);
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            child: Icon(
                                              item.quantity == 1 ? Icons.delete_outline : Icons.remove,
                                              size: 18,
                                              color: item.quantity == 1 ? Colors.red : const Color(0xFF0284C7),
                                            ),
                                          ),
                                        ),
                                        // Quantity Display
                                        Container(
                                          constraints: const BoxConstraints(minWidth: 32),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${item.quantity}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        // Plus Button
                                        InkWell(
                                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                                          onTap: () {
                                            if (item.quantity < stock) {
                                              ref.read(cartProvider.notifier).incrementQuantity(p['id']);
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Maximum stock limit reached ($stock pcs)'),
                                                  duration: const Duration(seconds: 1),
                                                ),
                                              );
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            child: const Icon(
                                              Icons.add,
                                              size: 18,
                                              color: Color(0xFF0284C7),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Bill Breakdown
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Estimated Commercial Proposal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 10),
                          _buildBillRow('Subtotal (Products):', '₹${cart.subtotal.toStringAsFixed(2)}'),

                          // Variable GST Slab Row
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('GST Slab:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: const Text(
                                    'Applicable on Approval (5% – 18%)',
                                    style: TextStyle(color: Color(0xFF1D4ED8), fontSize: 10, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Unknown Shipping Charge Row
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Shipping Charges:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: const Text(
                                    'Unknown / TBD on Approval',
                                    style: TextStyle(color: Color(0xFF92400E), fontSize: 10, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (cart.discountAmount > 0)
                            _buildBillRow('Voucher Discount:', '- ₹${cart.discountAmount.toStringAsFixed(2)}', isGreen: true),
                          const Divider(height: 18),
                          _buildBillRow(
                            'Estimated Base Total (Excl. GST):',
                            '₹${(cart.subtotal - cart.discountAmount).toStringAsFixed(2)}',
                            isBold: true,
                          ),
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '+ GST (5%–18%) & Shipping added upon approval',
                              style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Shipping Charge Advisory Notice Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.local_shipping_outlined, color: Color(0xFF0284C7), size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Taxes & Shipping Advisory',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0369A1)),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'GST slab varies from 5% to 18% depending on equipment, purifier, or spares category. Super Admin will verify applicable GST rates and compute exact shipping charges based on distance and shipment volume upon review.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF0C4A6E), height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Buyer Notes / Delivery Instructions Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Delivery Instructions / Remarks (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _notesCtrl,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'e.g. Preferred delivery schedule, site landmark, or urgent dispatch request...',
                              hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.all(10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Send for Approval Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isCheckingOut ? null : _sendForApproval,
                      icon: _isCheckingOut
                          ? const SizedBox.shrink()
                          : const Icon(Icons.send_rounded, size: 20),
                      label: _isCheckingOut
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Send for Approval',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                            ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isBold = false, bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: isGreen ? Colors.green : (isBold ? const Color(0xFF0284C7) : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
