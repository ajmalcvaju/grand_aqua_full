import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../core/auth_provider.dart';
import '../widgets/product_review_dialog.dart';
import '../widgets/product_whatsapp_share_sheet.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  ConsumerState<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  int _selectedQuantity = 1;
  bool _isLoadingReviews = true;
  List<dynamic> _reviews = [];
  bool _canReview = false;
  String? _orderId;
  String? _orderNumber;
  Map<String, dynamic>? _existingReview;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadReviewsAndEligibility();
  }

  Future<void> _loadReviewsAndEligibility() async {
    final productId = widget.product['id'];
    if (productId == null) return;

    try {
      final dio = ref.read(dioProvider);

      // 1. Approved reviews
      final reviewsRes = await dio.get('/reviews/product/$productId');
      final rawReviews = reviewsRes.data is Map ? reviewsRes.data['data'] : reviewsRes.data;
      final reviewsList = (rawReviews as List? ?? []);

      // 2. Review eligibility
      bool canReview = false;
      String? orderId;
      String? orderNumber;
      Map<String, dynamic>? existingReview;

      try {
        final eligRes = await dio.get('/reviews/eligibility/$productId');
        final eligData = eligRes.data['data'] ?? eligRes.data;
        canReview = eligData['canReview'] == true;
        orderId = eligData['orderId'];
        orderNumber = eligData['orderNumber'];
        existingReview = eligData['existingReview'];
      } catch (_) {}

      if (mounted) {
        setState(() {
          _reviews = reviewsList;
          _canReview = canReview;
          _orderId = orderId;
          _orderNumber = orderNumber;
          _existingReview = existingReview;
          _isLoadingReviews = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  double _getAverageRating() {
    if (_reviews.isEmpty) {
      return (widget.product['avgRating'] as num?)?.toDouble() ?? 0.0;
    }
    double sum = 0;
    for (var r in _reviews) {
      sum += (r['rating'] as num? ?? 5).toDouble();
    }
    return sum / _reviews.length;
  }

  List<Map<String, dynamic>> _getQuantitySlabs() {
    final rawSlabs = (widget.product['quantityPricingSlabs'] as List<dynamic>?) ?? [];
    final basePrice = (widget.product['applicablePrice'] as num?)?.toDouble() ?? 0.0;

    if (rawSlabs.isNotEmpty) {
      return rawSlabs.map((s) {
        final minQ = (s['minQuantity'] as num?)?.toInt() ?? 1;
        final maxQ = (s['maxQuantity'] as num?)?.toInt() ?? 999;
        final price = (s['price'] as num?)?.toDouble() ?? basePrice;
        final discountPct = (s['discountPct'] as num?)?.toDouble() ??
            (basePrice > 0 ? ((basePrice - price) / basePrice * 100).clamp(0, 100) : 0);
        final label = s['label'] ?? '';

        return {
          'minQuantity': minQ,
          'maxQuantity': maxQ,
          'price': price,
          'discountPct': discountPct.round(),
          'label': label,
        };
      }).toList();
    }

    // Default wholesale discount tier slabs if not populated
    return [
      {
        'minQuantity': 1,
        'maxQuantity': 4,
        'price': basePrice,
        'discountPct': 0,
        'label': 'Standard Piece Rate',
      },
      {
        'minQuantity': 5,
        'maxQuantity': 9,
        'price': (basePrice * 0.94).roundToDouble(),
        'discountPct': 6,
        'label': 'Starter Bulk Offer',
      },
      {
        'minQuantity': 10,
        'maxQuantity': 24,
        'price': (basePrice * 0.89).roundToDouble(),
        'discountPct': 11,
        'label': 'Trade Pack Savings',
      },
      {
        'minQuantity': 25,
        'maxQuantity': 49,
        'price': (basePrice * 0.84).roundToDouble(),
        'discountPct': 16,
        'label': 'Commercial Wholesale',
      },
      {
        'minQuantity': 50,
        'maxQuantity': 500,
        'price': (basePrice * 0.78).roundToDouble(),
        'discountPct': 22,
        'label': 'Master Bulk Deal',
      },
    ];
  }

  double _getEffectiveUnitPrice(int quantity) {
    final slabs = _getQuantitySlabs();
    for (final s in slabs) {
      final minQ = s['minQuantity'] as int;
      final maxQ = s['maxQuantity'] as int;
      if (quantity >= minQ && quantity <= maxQ) {
        return (s['price'] as num).toDouble();
      }
    }
    return (widget.product['applicablePrice'] as num?)?.toDouble() ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final basePrice = (p['applicablePrice'] as num?)?.toDouble() ?? 0.0;
    final name = p['name'] ?? 'Grand Aqua Water Purifier';
    final brand = p['brand'] ?? 'Grand Aqua';
    final modelNumber = p['modelNumber'] ?? p['sku'] ?? '';
    final stock = (p['stockQuantity'] as num?)?.toInt() ?? 50;
    final shortDesc = p['shortDescription'] ?? '';
    final fullDesc = p['fullDescription'] ?? 'Advanced multi-stage reverse osmosis water purifier engineered with high salt rejection membrane technology for superior TDS reduction and crystal-clear drinking water.';
    final warranty = p['warrantyDetails'] ?? '1 Year Comprehensive Manufacturer Warranty';
    final specs = p['technicalSpecifications'] as Map<String, dynamic>? ?? {
      'Flow Rate': '15 Litres / Hour',
      'Membrane': '75 / 100 GPD High-TDS Thin Film',
      'Purification Stages': 'RO + UV + UF + Alkaline Mineral TDS Infusion',
      'Storage Tank': '10 Litres Food Grade ABS Tank',
      'Input Voltage': '160V - 260V AC (50Hz)',
      'TDS Reduction': 'Up to 2500 ppm Inlet TDS',
    };

    final mediaList = (p['media'] as List<dynamic>?) ?? [];
    final imgObj = mediaList.firstWhere(
      (m) => m['mediaType'] == 'IMAGE',
      orElse: () => null,
    );
    String imgUrl = imgObj?['url'] ?? p['imageUrl'] ?? '';
    if (imgUrl.startsWith('/uploads/')) {
      final api = ref.read(apiClientProvider);
      final base = api.dio.options.baseUrl.replaceAll('/api/v1', '');
      imgUrl = '$base$imgUrl';
    }

    final avgRating = _getAverageRating();
    final slabs = _getQuantitySlabs();
    final effectiveUnitPrice = _getEffectiveUnitPrice(_selectedQuantity);
    final totalPrice = effectiveUnitPrice * _selectedQuantity;
    final standardTotal = basePrice * _selectedQuantity;
    final totalSavings = standardTotal - totalPrice;

    final cartState = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Share Product via WhatsApp',
            onPressed: () {
              final api = ref.read(apiClientProvider);
              ProductWhatsappShareSheet.show(
                context,
                product: p,
                backendBaseUrl: api.dio.options.baseUrl,
              );
            },
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => context.push('/cart'),
              ),
              if (cartState.itemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${cartState.itemCount}',
                      style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Large Product Image Showcase
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imgUrl.isNotEmpty)
                    Image.network(
                      imgUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.water_drop, size: 80, color: Color(0xFF0284C7)),
                      ),
                    )
                  else
                    const Center(
                      child: Icon(Icons.water_drop, size: 80, color: Color(0xFF0284C7)),
                    ),
                  // Brand & Guarantee Pill
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        brand.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  // Genuine Seal
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 12, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Text(
                            '100% Genuine',
                            style: TextStyle(
                              color: Color(0xFF047857),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 2. Product Title & Base Info Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (modelNumber.isNotEmpty)
                  Text(
                    'MODEL / SKU: $modelNumber',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Color(0xFF64748B),
                      fontFamily: 'monospace',
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),

                // Rating & Stock Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 15),
                          const SizedBox(width: 4),
                          Text(
                            avgRating > 0 ? avgRating.toStringAsFixed(1) : 'New',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.amber.shade900,
                            ),
                          ),
                          if (_reviews.isNotEmpty)
                            Text(
                              ' (${_reviews.length} reviews)',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: stock > 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: stock > 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            stock > 0 ? Icons.check_circle : Icons.cancel,
                            size: 13,
                            color: stock > 0 ? const Color(0xFF059669) : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            stock > 0 ? 'In Stock ($stock available)' : 'Out of Stock',
                            style: TextStyle(
                              color: stock > 0 ? const Color(0xFF047857) : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Divider(height: 24),

                // Base Applicable Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _currencyFormat.format(basePrice),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '/ piece (Standard Rate)',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Inclusive of all applicable GST taxes',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),

                const SizedBox(height: 14),
                // WHATSAPP CUSTOMER SHARING BANNER
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF25D366).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        final api = ref.read(apiClientProvider);
                        ProductWhatsappShareSheet.show(
                          context,
                          product: p,
                          backendBaseUrl: api.dio.options.baseUrl,
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.share, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Share Photos & Video to Customer via WhatsApp',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. CORE USER REQUEST: PER NO. OF PIECE OFFER PRICING TABLE & SELECTOR
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with fire / savings tag
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_offer_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BULK PURCHASE OFFERS',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0369A1),
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Special Per No. of Piece Offer Prices (Buy More, Save More!)',
                            style: TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Quantity Offer Slabs Table
                Column(
                  children: slabs.map((slab) {
                    final minQ = slab['minQuantity'] as int;
                    final maxQ = slab['maxQuantity'] as int;
                    final slabPrice = (slab['price'] as num).toDouble();
                    final discount = slab['discountPct'] as int;
                    final label = slab['label'] as String;

                    final isCurrentActive = _selectedQuantity >= minQ && _selectedQuantity <= maxQ;
                    final rangeText = maxQ >= 500 ? '$minQ+ pieces' : '$minQ - $maxQ pieces';

                    return InkWell(
                      onTap: () {
                        setState(() => _selectedQuantity = minQ);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: isCurrentActive ? Colors.white : Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrentActive ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                            width: isCurrentActive ? 2.0 : 1.0,
                          ),
                          boxShadow: isCurrentActive
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          children: [
                            // Quantity range
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCurrentActive ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                              ),
                              child: Center(
                                child: Icon(
                                  isCurrentActive ? Icons.check : Icons.layers,
                                  color: isCurrentActive ? Colors.white : const Color(0xFF64748B),
                                  size: 16,
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
                                        rangeText,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isCurrentActive ? const Color(0xFF0F172A) : const Color(0xFF334155),
                                        ),
                                      ),
                                      if (discount > 0) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Save $discount%',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF15803D),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (label.isNotEmpty)
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isCurrentActive ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Per piece offer price
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _currencyFormat.format(slabPrice),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: isCurrentActive ? const Color(0xFF0284C7) : const Color(0xFF0F172A),
                                  ),
                                ),
                                const Text(
                                  'per piece',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),

                // Interactive Quantity Picker & Live Savings Summary
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Number of Pieces:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                              ),
                              Text(
                                'Tap [-] or [+] to adjust order pieces',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),

                          // Quantity Stepper
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 18),
                                  onPressed: _selectedQuantity > 1
                                      ? () => setState(() => _selectedQuantity--)
                                      : null,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  child: Text(
                                    '$_selectedQuantity',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 18),
                                  onPressed: _selectedQuantity < stock
                                      ? () => setState(() => _selectedQuantity++)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 20),

                      // Live Calculation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Offer Rate: ${_currencyFormat.format(effectiveUnitPrice)} / piece',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                              if (totalSavings > 0)
                                Text(
                                  '🎉 You save ${_currencyFormat.format(totalSavings)} on this quantity!',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _currencyFormat.format(totalPrice),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'for $_selectedQuantity pieces',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. Warranty & Quality Assurance Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.security_rounded, color: Color(0xFF059669), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manufacturer Warranty',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        warranty,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '100% genuine spares & authorized service technician support',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 5. Technical Specifications Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune_rounded, color: Color(0xFF0284C7), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Technical Specifications',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1.2),
                    1: FlexColumnWidth(1.8),
                  },
                  children: specs.entries.map((entry) {
                    return TableRow(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '${entry.value}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 6. Product Description
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.description_outlined, color: Color(0xFF0284C7), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'About This Product',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                if (shortDesc.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    shortDesc,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  fullDesc,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 7. Verified Customer Reviews & Rating Section
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.rate_review_outlined, color: Color(0xFF0284C7), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Customer Reviews (${_reviews.length})',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    if (avgRating > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              avgRating.toStringAsFixed(1),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber.shade900),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // Review Eligibility Action Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _canReview ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _canReview ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _canReview ? Icons.verified_user_rounded : Icons.lock_outline_rounded,
                            size: 18,
                            color: _canReview ? const Color(0xFF16A34A) : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _canReview
                                ? (_existingReview != null ? 'Your Review is Live' : 'Verified Purchaser')
                                : 'Verified Buyer Review Only',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _canReview ? const Color(0xFF15803D) : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _canReview
                            ? 'You purchased this product (Order ${_orderNumber ?? ''}). Help other buyers by sharing your rating & feedback.'
                            : 'Only verified buyers who have purchased this product can leave a review.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      if (_canReview) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ProductReviewDialog.show(
                                context,
                                productId: (p['id'] ?? '').toString(),
                                productName: name,
                                productImage: imgUrl,
                                orderId: _orderId,
                                orderNumber: _orderNumber,
                                onReviewSubmitted: () => _loadReviewsAndEligibility(),
                              );
                            },
                            icon: const Icon(Icons.star_outline, size: 16),
                            label: Text(
                              _existingReview != null ? 'Update Your Review' : 'Rate & Write Review',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0284C7),
                              side: const BorderSide(color: Color(0xFF0284C7)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Reviews List
                if (_isLoadingReviews)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                else if (_reviews.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No reviews yet. Be the first to purchase and review!',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _reviews.length,
                    separatorBuilder: (_, _) => const Divider(height: 20),
                    itemBuilder: (ctx, i) {
                      final r = _reviews[i];
                      final rating = (r['rating'] as num? ?? 5).toInt();
                      final buyerName = r['buyer']?['user']?['fullName'] ?? 'Verified Buyer';
                      final title = r['title'] ?? '';
                      final comment = r['comment'] ?? '';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Row(
                                children: List.generate(
                                  5,
                                  (idx) => Icon(
                                    idx < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                buyerName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const Spacer(),
                              const Row(
                                children: [
                                  Icon(Icons.verified, size: 12, color: Colors.teal),
                                  SizedBox(width: 2),
                                  Text(
                                    'Verified Purchase',
                                    style: TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (title.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            comment,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),

          const SizedBox(height: 100), // Bottom padding for sticky action bar
        ],
      ),

      // 8. Bottom Sticky Cart & Order Action Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Price display
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currencyFormat.format(totalPrice),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    Text(
                      '${_currencyFormat.format(effectiveUnitPrice)} × $_selectedQuantity pcs',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              // Add To Cart Button
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: stock > 0
                      ? () {
                          ref.read(cartProvider.notifier).addItem(p, qty: _selectedQuantity);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added $_selectedQuantity pieces of ${p['name']} to cart!'),
                              action: SnackBarAction(
                                label: 'VIEW CART',
                                textColor: Colors.amber,
                                onPressed: () => context.push('/cart'),
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: Text(
                    stock > 0 ? 'Add to Cart ($_selectedQuantity)' : 'Out of Stock',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
