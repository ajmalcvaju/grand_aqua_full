import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../core/auth_provider.dart';
import 'product_review_dialog.dart';

class ProductDetailsModal extends ConsumerStatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsModal({super.key, required this.product});

  static void show(BuildContext context, Map<String, dynamic> product) {
    context.push('/product-details', extra: product);
  }

  @override
  ConsumerState<ProductDetailsModal> createState() => _ProductDetailsModalState();
}

class _ProductDetailsModalState extends ConsumerState<ProductDetailsModal> {
  bool _isLoadingReviews = true;
  List<dynamic> _reviews = [];
  bool _canReview = false;
  String? _orderId;
  String? _orderNumber;
  Map<String, dynamic>? _existingReview;

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

      // Load approved reviews
      final reviewsRes = await dio.get('/reviews/product/$productId');
      final rawReviews = reviewsRes.data is Map ? reviewsRes.data['data'] : reviewsRes.data;
      final reviewsList = (rawReviews as List? ?? []);

      // Check review eligibility
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
    if (_reviews.isEmpty) return 0.0;
    double sum = 0;
    for (var r in _reviews) {
      sum += (r['rating'] as num? ?? 5).toDouble();
    }
    return sum / _reviews.length;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final price = p['applicablePrice'] ?? 0;
    final name = p['name'] ?? 'Water Purifier';
    final description = p['description'] ?? 'Premium multi-stage reverse osmosis water purifier.';

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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Scrollable product & reviews content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    color: Colors.grey.shade50,
                    child: imgUrl.isNotEmpty
                        ? Image.network(
                            imgUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.water_drop, size: 64, color: Color(0xFF0284C7)),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.water_drop, size: 64, color: Color(0xFF0284C7)),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Name & Price
                Text(
                  name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '₹$price',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    const Spacer(),
                    if (avgRating > 0) ...[
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '${avgRating.toStringAsFixed(1)} (${_reviews.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                ),
                const SizedBox(height: 20),

                const Divider(),

                // Ratings & Reviews Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.rate_review, color: Color(0xFF0284C7), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Customer Reviews (${_reviews.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (avgRating > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
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

                // Eligibility / Rate Product Action Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _canReview ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _canReview ? Colors.green.shade200 : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _canReview ? Icons.verified_user : Icons.lock_outline,
                            color: _canReview ? Colors.green.shade700 : Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _canReview
                                  ? (_existingReview != null ? 'You have reviewed this purchased item' : 'Verified Purchase Available')
                                  : 'Reviews restricted to verified buyers',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _canReview ? Colors.green.shade800 : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _canReview
                          ? 'As a verified purchaser of this product, your rating & feedback helps the distributor network.'
                          : 'You can rate and write review comments once you have purchased this product.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 10),
                      if (_canReview)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              ProductReviewDialog.show(
                                context,
                                productId: p['id'],
                                productName: name,
                                productImage: imgUrl,
                                orderId: _orderId,
                                orderNumber: _orderNumber,
                                onReviewSubmitted: _loadReviewsAndEligibility,
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.teal.shade700,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.star_rate_rounded, size: 18),
                            label: Text(
                              _existingReview != null ? 'Update Your Review' : 'Rate & Write Review',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Reviews List
                if (_isLoadingReviews)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                else if (_reviews.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.rate_review_outlined, size: 40, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text(
                          'No reviews yet for this product',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                else
                  ..._reviews.map((r) {
                    final rating = (r['rating'] as num? ?? 5).toInt();
                    final title = r['title'] ?? 'Verified Review';
                    final comment = r['comment'] ?? '';
                    final buyerName = r['buyer']?['user']?['fullName'] ?? 'Verified Buyer';
                    final isVerified = r['isVerifiedPurchase'] == true;
                    final dateStr = r['createdAt'] != null
                        ? DateFormat.yMMMd().format(DateTime.parse(r['createdAt']))
                        : '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Row(
                                children: List.generate(5, (s) {
                                  return Icon(
                                    s < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                    size: 16,
                                    color: s < rating ? Colors.amber.shade600 : Colors.grey.shade300,
                                  );
                                }),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            comment,
                            style: const TextStyle(fontSize: 12, height: 1.3),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                buyerName,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified, size: 12, color: Colors.teal),
                                const SizedBox(width: 2),
                                const Text(
                                  'Verified Purchase',
                                  style: TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.bold),
                                ),
                              ],
                              const Spacer(),
                              Text(
                                dateStr,
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 80),
              ],
            ),
          ),

          // Bottom Bar with Add to Cart
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Unit Price', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text('₹$price', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0284C7))),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      ref.read(cartProvider.notifier).addItem(p);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${p['name']} added to cart!'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                    label: const Text('Add to Cart', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
