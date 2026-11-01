import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_client.dart';
import '../widgets/product_review_dialog.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _isDownloading = false;

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
        return const Color(0xFF16A34A); // Green
      case 'SHIPPED':
        return const Color(0xFF0284C7); // Blue
      case 'CONFIRMED':
      case 'PROCESSING':
        return const Color(0xFFD97706); // Amber
      case 'CANCELLED':
        return const Color(0xFFDC2626); // Red
      default:
        return const Color(0xFF64748B); // Slate Gray
    }
  }

  Widget _buildCameraPlaceholder() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Icon(Icons.water_drop_outlined, size: 22, color: Colors.blue.shade300),
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

  Future<void> _downloadInvoice() async {
    final id = widget.order['id'];
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

    setState(() => _isDownloading = true);

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
            SnackBar(
              content: Text('Could not open bill: $invoiceUrl'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading invoice: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    final orderNumber = order['orderNumber'] ?? order['id'] ?? 'GA-ORD';
    final status = (order['status'] ?? 'PENDING').toString().toUpperCase();
    final createdAt = order['createdAt'] != null ? DateTime.tryParse(order['createdAt']) : null;
    final items = (order['items'] as List<dynamic>? ?? []);

    // Accurate calculation of amounts matching database schema
    final subtotal = (order['subtotal'] ?? 0.0).toDouble();
    final shippingCharges = (order['shippingCharges'] ?? 0.0).toDouble();
    final taxTotal = (order['taxTotal'] ?? 0.0).toDouble();
    final discountTotal = (order['discountTotal'] ?? 0.0).toDouble();
    final finalAmount = (order['finalAmount'] ?? order['totalAmount'] ?? (subtotal + shippingCharges)).toDouble();

    // Buyer / Consignee details
    final buyer = order['buyer'] as Map<String, dynamic>?;
    final buyerName = buyer?['businessName'] ?? buyer?['user']?['fullName'] ?? 'Valued Buyer';
    final buyerPhone = buyer?['user']?['phone'] ?? buyer?['user']?['mobileNumber'] ?? '';
    final buyerGstin = buyer?['gstin'] ?? '32BMTPC7034C1ZD';

    // Shipping address
    String addressStr = 'Palakkad, Kerala, India';
    String bookingStation = 'Palakkad';
    if (order['shippingAddress'] is Map) {
      final addr = order['shippingAddress'] as Map<String, dynamic>;
      final parts = [
        addr['addressLine'] ?? addr['address'],
        addr['city'] ?? addr['district'],
        addr['state'] ?? 'Kerala',
        (addr['pinCode'] ?? addr['pincode']) != null ? 'Pin: ${addr['pinCode'] ?? addr['pincode']}' : null,
      ].where((p) => p != null && p.toString().trim().isNotEmpty).toList();
      if (parts.isNotEmpty) addressStr = parts.join(', ');
      if (addr['district'] != null || addr['city'] != null) {
        bookingStation = (addr['district'] ?? addr['city']).toString();
      }
    }

    // Transport details
    String transportName = 'GATI Logistics';
    String transportContact = '7874416368';
    String specialComments = order['deliveryNotes'] ?? 'Standard Verified Packaging';
    if (order['deliveryNotes'] != null && order['deliveryNotes'].toString().contains('Carrier: ')) {
      transportName = order['deliveryNotes'].toString().split('Carrier: ')[1].split('.')[0].trim();
    }
    if (order['trackingNumber'] != null) {
      transportName = order['trackingNumber'].toString();
    }

    // Quotation reference
    final quoteRef = order['sourceQuotation']?['quotationNumber'] ??
        order['sourceQuotationId']?.toString().substring((order['sourceQuotationId']?.toString().length ?? 6) - 6) ??
        '1075';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(orderNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Download Bill',
            onPressed: _isDownloading ? null : _downloadInvoice,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Status & Timeline Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      status == 'DELIVERED'
                          ? Icons.check_circle_rounded
                          : status == 'SHIPPED'
                              ? Icons.local_shipping_rounded
                              : Icons.hourglass_top_rounded,
                      color: _getStatusColor(status),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              status,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: _getStatusColor(status),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Text(
                                'Ref: Quote #$quoteRef',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (createdAt != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            dateFormat.format(createdAt),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Buyer / Consignee Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_pin_rounded, size: 18, color: Color(0xFF0284C7)),
                      const SizedBox(width: 6),
                      Text(
                        'BUYER / CONSIGNEE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.cyan.shade800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  Text(
                    buyerName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    addressStr,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  if (buyerPhone.isNotEmpty)
                    Text(
                      'Mobile: $buyerPhone',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                    ),
                  Text(
                    'GSTIN: $buyerGstin | Place of Supply: Kerala',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Transport & Dispatch Information Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined, size: 16, color: Color(0xFF0284C7)),
                      const SizedBox(width: 6),
                      Text(
                        'TRANSPORT & DISPATCH DETAILS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.cyan.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TRANSPORT NAME', style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(transportName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TRANSPORT CONTACT', style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(transportContact, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('BOOKING STATION', style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(bookingStation, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('INSTRUCTIONS / COMMENT', style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(specialComments, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. Ordered Items Breakdown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF0284C7)),
                      const SizedBox(width: 6),
                      Text(
                        'ORDERED ITEMS (${items.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  ...items.map((item) {
                    final title = item['productName'] ?? item['product']?['name'] ?? item['title'] ?? 'Water Purifier';
                    final sku = item['sku'] ?? item['product']?['sku'] ?? '';
                    final quantity = item['quantity'] ?? 1;
                    final unitPrice = (item['unitPrice'] ?? 0.0).toDouble();
                    final lineTotal = (quantity * unitPrice).toDouble();

                    final mediaList = (item['product']?['media'] as List<dynamic>?) ?? [];
                    final imgObj = mediaList.firstWhere(
                      (m) => m['mediaType'] == 'IMAGE',
                      orElse: () => null,
                    );
                    String imgUrl = imgObj?['url'] ?? item['product']?['imageUrl'] ?? item['imageUrl'] ?? '';
                    if (imgUrl.startsWith('/uploads/')) {
                      final dio = ref.read(dioProvider);
                      final base = dio.options.baseUrl.replaceAll('/api/v1', '');
                      imgUrl = '$base$imgUrl';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.only(bottom: 12),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: imgUrl.isNotEmpty
                                  ? Image.network(
                                      imgUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => _buildCameraPlaceholder(),
                                    )
                                  : _buildCameraPlaceholder(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (sku.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Model: $sku',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  'Qty: ${quantity.toString()} PCS  ×  ${currencyFormat.format(unitPrice)}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () {
                                    final pId = item['productId'] ?? item['product']?['id'];
                                    if (pId != null) {
                                      ProductReviewDialog.show(
                                        context,
                                        productId: pId.toString(),
                                        productName: title,
                                        productImage: imgUrl,
                                        orderId: order['id']?.toString(),
                                        orderNumber: orderNumber,
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.amber.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.star_rate_rounded, size: 15, color: Colors.amber.shade800),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Rate & Review Product',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            currencyFormat.format(lineTotal),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 5. Financial Summary / Bill Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'BILL & PAYMENT BREAKDOWN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal (Taxable Value)', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                      Text(currencyFormat.format(subtotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (shippingCharges > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Shipping & Freight Charges', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                        Text(currencyFormat.format(shippingCharges), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                  if (taxTotal > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Taxes (GST Included)', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                        Text(currencyFormat.format(taxTotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                  if (discountTotal > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Discount / Concession', style: TextStyle(fontSize: 13, color: Colors.green)),
                        Text('-${currencyFormat.format(discountTotal)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Solid Dark Box for Total Amount Payable (matching PDF)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount Payable',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          currencyFormat.format(finalAmount),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 6. Prominent "Download Bill (PDF)" Action Button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isDownloading ? null : _downloadInvoice,
                icon: _isDownloading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded, size: 22),
                label: Text(
                  _isDownloading ? 'Opening Bill...' : 'Download Tax Invoice (PDF)',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
