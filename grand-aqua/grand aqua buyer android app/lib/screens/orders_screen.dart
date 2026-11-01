import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_client.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  bool _isLoading = true;
  List<dynamic> _orders = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      dynamic res;
      try {
        res = await dio.get('/orders/my-orders');
      } catch (_) {
        res = await dio.get('/orders');
      }

      final dynamic responseData = res.data;
      List<dynamic> list = [];
      if (responseData is List) {
        list = responseData;
      } else if (responseData is Map && responseData['data'] != null) {
        final inner = responseData['data'];
        if (inner is List) {
          list = inner;
        } else if (inner is Map && inner['orders'] is List) {
          list = inner['orders'];
        }
      } else if (responseData is Map && responseData['orders'] is List) {
        list = responseData['orders'];
      }

      if (mounted) {
        setState(() {
          _orders = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load orders: $e';
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
        return Colors.green;
      case 'SHIPPED':
        return Colors.blue;
      case 'PROCESSING':
      case 'CONFIRMED':
        return Colors.amber.shade800;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCameraPlaceholder() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.camera_alt_outlined, size: 20, color: Colors.grey.shade400),
          Transform.rotate(
            angle: -0.785, // -45 degrees
            child: Container(
              width: 24,
              height: 1.2,
              color: const Color(0xFFCBD5E1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateOptionTile({
    required BuildContext ctx,
    required String templateId,
    required String title,
    required String subtitle,
    required Color color,
    required String tag,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(ctx, templateId),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'T$templateId',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.download_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadInvoicePdf(Map<String, dynamic> order) async {
    final id = order['id'];
    if (id == null) return;

    final selectedTemplate = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.picture_as_pdf, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose GST Invoice Template',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'Select your preferred bill layout format',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTemplateOptionTile(
                ctx: ctx,
                templateId: '1',
                title: 'Template 1: Modern Corporate',
                subtitle: 'Navy banner, itemized images & dispatch badge',
                color: const Color(0xFF0369A1),
                tag: 'Modern',
              ),
              const SizedBox(height: 8),
              _buildTemplateOptionTile(
                ctx: ctx,
                templateId: '2',
                title: 'Template 2: Executive Clean Minimal',
                subtitle: 'Minimal emerald styling & NEFT remittance card',
                color: const Color(0xFF059669),
                tag: 'Clean Minimal',
              ),
              const SizedBox(height: 8),
              _buildTemplateOptionTile(
                ctx: ctx,
                templateId: '3',
                title: 'Template 3: GST Formal Wholesale',
                subtitle: 'Statutory double-border, HSN 84212190 & split tax',
                color: const Color(0xFF4338CA),
                tag: 'Statutory GST',
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedTemplate == null) return;

    try {
      final dio = ref.read(dioProvider);
      final baseUrl = dio.options.baseUrl.replaceAll('/api/v1', '');
      final invoiceUrl = '$baseUrl/api/v1/orders/$id/invoice-pdf?template=$selectedTemplate';
      final uri = Uri.parse(invoiceUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open invoice: $invoiceUrl')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading invoice: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Purchase Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadOrders,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No purchase orders placed yet',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          final status = (order['status'] ?? 'PENDING').toString().toUpperCase();
                          final orderNumber = order['orderNumber'] ?? order['id'] ?? 'GA-ORD';
                          final subtotal = (order['subtotal'] ?? 0.0).toDouble();
                          final shippingCharges = (order['shippingCharges'] ?? 0.0).toDouble();
                          final totalAmount = (order['finalAmount'] ?? order['totalAmount'] ?? (subtotal + shippingCharges)).toDouble();
                          final createdAt = order['createdAt'] != null
                              ? DateTime.tryParse(order['createdAt'])
                              : null;
                          final items = (order['items'] as List<dynamic>? ?? []);
                          final totalItems = items.fold<int>(0, (sum, it) => sum + ((it['quantity'] ?? 1) as num).toInt());

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 0,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrderDetailScreen(order: order),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(Icons.receipt_long, size: 18, color: Color(0xFF0284C7)),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              orderNumber,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(status).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: _getStatusColor(status).withValues(alpha: 0.5),
                                            ),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              color: _getStatusColor(status),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (createdAt != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        dateFormat.format(createdAt),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                    const Divider(height: 22),

                                    // Item summary row
                                    Row(
                                      children: [
                                        SizedBox(
                                          height: 38,
                                          child: Row(
                                            children: [
                                              for (int i = 0; i < (items.length > 3 ? 3 : items.length); i++) ...[
                                                Builder(
                                                  builder: (context) {
                                                    final it = items[i];
                                                    final mediaList = (it['product']?['media'] as List<dynamic>?) ?? [];
                                                    final imgObj = mediaList.firstWhere(
                                                      (m) => m['mediaType'] == 'IMAGE',
                                                      orElse: () => null,
                                                    );
                                                    String imgUrl = imgObj?['url'] ?? it['product']?['imageUrl'] ?? it['imageUrl'] ?? '';
                                                    if (imgUrl.startsWith('/uploads/')) {
                                                      final dio = ref.read(dioProvider);
                                                      final base = dio.options.baseUrl.replaceAll('/api/v1', '');
                                                      imgUrl = '$base$imgUrl';
                                                    }
                                                    return Container(
                                                      margin: const EdgeInsets.only(right: 6),
                                                      width: 38,
                                                      height: 38,
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey.shade100,
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: Colors.grey.shade200),
                                                      ),
                                                      clipBehavior: Clip.antiAlias,
                                                      child: imgUrl.isNotEmpty
                                                          ? Image.network(
                                                              imgUrl,
                                                              fit: BoxFit.cover,
                                                              errorBuilder: (context, error, stackTrace) => _buildCameraPlaceholder(),
                                                            )
                                                          : _buildCameraPlaceholder(),
                                                    );
                                                  },
                                                ),
                                              ],
                                              if (items.length > 3)
                                                Container(
                                                  width: 32,
                                                  height: 38,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade200,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    '+${items.length - 3}',
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '$totalItems Units (${items.length} ${items.length == 1 ? 'Product' : 'Products'})',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                items.isNotEmpty
                                                    ? (items[0]['productName'] ?? items[0]['product']?['name'] ?? items[0]['title'] ?? 'Water Purifier')
                                                    : 'Order placed',
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    const Divider(height: 22),

                                    // Payment Mode & Total Amount
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Mode: ${order['paymentMethod'] ?? 'ONLINE'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const Text(
                                              'Total: ',
                                              style: TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                            Text(
                                              currencyFormat.format(totalAmount),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF0284C7),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Action buttons
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Color(0xFF0284C7)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          icon: const Icon(Icons.picture_as_pdf, size: 16, color: Color(0xFF0284C7)),
                                          label: const Text(
                                            'Bill (PDF)',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                          ),
                                          onPressed: () => _downloadInvoicePdf(order),
                                        ),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0284C7),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          ),
                                          icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                                          label: const Text(
                                            'View Details',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => OrderDetailScreen(order: order),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,
        selectedItemColor: const Color(0xFF0284C7),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (idx) {
          if (idx == 0) context.go('/home');
          if (idx == 1) context.push('/cart');
          if (idx == 2) context.push('/quotations');
          if (idx == 3) context.push('/orders');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
          BottomNavigationBarItem(icon: Icon(Icons.request_quote_outlined), label: 'Quotes'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
        ],
      ),
    );
  }
}
