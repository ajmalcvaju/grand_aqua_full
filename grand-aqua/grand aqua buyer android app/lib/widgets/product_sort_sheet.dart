import 'package:flutter/material.dart';

enum ProductSortOption {
  relevance('relevance', 'Relevance', 'Default recommended view'),
  popularity('popularity', 'Popularity', 'Best selling & most ordered'),
  priceLowToHigh('price_low_high', 'Price -- Low to High', 'Cheapest products first'),
  priceHighToLow('price_high_low', 'Price -- High to Low', 'Premium & high-capacity first'),
  ratingHighToLow('rating_high_low', 'Customer Rating', 'Highest rated 4★ & 5★ first'),
  newest('newest', 'Newest Arrivals', 'Recently launched purifiers & spares'),
  alphabetical('alphabetical', 'Alphabetical -- A to Z', 'Sorted by product name');

  final String id;
  final String label;
  final String description;

  const ProductSortOption(this.id, this.label, this.description);
}

class ProductSortSheet extends StatelessWidget {
  final ProductSortOption currentSort;
  final ValueChanged<ProductSortOption> onSortSelected;

  const ProductSortSheet({
    super.key,
    required this.currentSort,
    required this.onSortSelected,
  });

  static Future<ProductSortOption?> show(
    BuildContext context, {
    required ProductSortOption currentSort,
  }) {
    return showModalBottomSheet<ProductSortOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ProductSortSheet(
        currentSort: currentSort,
        onSortSelected: (opt) {
          Navigator.of(ctx).pop(opt);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header matching user reference image
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SORT BY',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  '${ProductSortOption.values.length} options',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Sort Options List
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: ProductSortOption.values.map((option) {
                  final isSelected = currentSort == option;
                  return InkWell(
                    onTap: () => onSortSelected(option),
                    child: Container(
                      color: isSelected ? const Color(0xFFF0F9FF) : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  option.description,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Radio button on the right matching user reference
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                                width: isSelected ? 6.5 : 1.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
