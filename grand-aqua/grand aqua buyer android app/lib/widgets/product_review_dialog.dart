import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';

class ProductReviewDialog extends ConsumerStatefulWidget {
  final String productId;
  final String productName;
  final String? productImage;
  final String? orderId;
  final String? orderNumber;
  final VoidCallback? onReviewSubmitted;

  const ProductReviewDialog({
    super.key,
    required this.productId,
    required this.productName,
    this.productImage,
    this.orderId,
    this.orderNumber,
    this.onReviewSubmitted,
  });

  static Future<void> show(
    BuildContext context, {
    required String productId,
    required String productName,
    String? productImage,
    String? orderId,
    String? orderNumber,
    VoidCallback? onReviewSubmitted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProductReviewDialog(
        productId: productId,
        productName: productName,
        productImage: productImage,
        orderId: orderId,
        orderNumber: orderNumber,
        onReviewSubmitted: onReviewSubmitted,
      ),
    );
  }

  @override
  ConsumerState<ProductReviewDialog> createState() => _ProductReviewDialogState();
}

class _ProductReviewDialogState extends ConsumerState<ProductReviewDialog> {
  int _rating = 5;
  final _titleCtrl = TextEditingController(text: 'Excellent product quality');
  final _commentCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  final Set<String> _selectedTags = {};

  final List<String> _quickTags = [
    '💧 Pure Water Taste',
    '⚡ High TDS Reduction',
    '🔧 Easy Installation',
    '🛡️ Heavy Duty Build',
    '🔇 Low Operating Noise',
    '💰 Value for Money',
    '🚀 Fast Delivery',
  ];

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Poor Quality 😞';
      case 2:
        return 'Below Expectations 😐';
      case 3:
        return 'Good / Satisfactory 🙂';
      case 4:
        return 'Very Good / Impressive 😊';
      case 5:
        return 'Outstanding & Excellent! 🤩';
      default:
        return '';
    }
  }

  Color _getRatingColor(int rating) {
    if (rating >= 4) return Colors.amber.shade700;
    if (rating == 3) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  Future<void> _submitReview() async {
    final comment = _commentCtrl.text.trim();
    if (comment.length < 5) {
      setState(() {
        _errorMessage = 'Please write at least a brief comment (min 5 characters)';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioProvider);

      // Append selected tags to comment if any
      String finalComment = comment;
      if (_selectedTags.isNotEmpty) {
        final tagsStr = _selectedTags.join(' • ');
        finalComment = '$comment\n\nHighlights: $tagsStr';
      }

      await dio.post('/reviews', data: {
        'productId': widget.productId,
        'rating': _rating,
        'title': _titleCtrl.text.trim().isEmpty ? 'Verified Buyer Review' : _titleCtrl.text.trim(),
        'comment': finalComment,
        'orderId': widget.orderId,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Thank you! Your verified review has been submitted.'),
              ],
            ),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onReviewSubmitted?.call();
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to submit review';
        if (e is DioException && e.response?.data != null) {
          msg = e.response?.data['message']?.toString() ?? msg;
        }
        setState(() {
          _errorMessage = msg;
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomInset + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.rate_review_outlined, color: Colors.amber.shade800, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rate & Review Product',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Verified Buyer Feedback',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Product Banner & Verified Purchase Badge
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: widget.productImage != null && widget.productImage!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              widget.productImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.water_drop, color: Color(0xFF0284C7)),
                            ),
                          )
                        : const Icon(Icons.water_drop, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.verified, size: 14, color: Colors.teal),
                            const SizedBox(width: 4),
                            Text(
                              widget.orderNumber != null
                                  ? 'Verified Purchase (${widget.orderNumber})'
                                  : 'Verified Buyer Purchase',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.teal,
                                fontWeight: FontWeight.bold,
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
            const SizedBox(height: 20),

            // Star Rating Section
            Center(
              child: Column(
                children: [
                  const Text(
                    'How was your experience?',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starNum = index + 1;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = starNum),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            starNum <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 40,
                            color: starNum <= _rating ? Colors.amber.shade600 : Colors.grey.shade300,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _getRatingLabel(_rating),
                      key: ValueKey(_rating),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _getRatingColor(_rating),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Quick Highlight Chips
            const Text(
              'What did you like the most? (Optional)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _quickTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  selected: isSelected,
                  label: Text(tag, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87)),
                  selectedColor: const Color(0xFF0284C7),
                  backgroundColor: Colors.grey.shade100,
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Review Title Field
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Review Headline',
                hintText: 'e.g. Great RO filtration, crystal clear water',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 14),

            // Review Comment Field
            TextField(
              controller: _commentCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Detailed Feedback / Review *',
                hintText: 'Share your experience with water output, filtration, maintenance, or build quality...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your review will be marked as "Verified Buyer" and help other distributors and retail buyers make informed decisions.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submitReview,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _isSubmitting ? 'Submitting Review...' : 'Submit Verified Review',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
