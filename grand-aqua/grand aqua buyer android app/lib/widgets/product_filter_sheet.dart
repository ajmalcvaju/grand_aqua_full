import 'package:flutter/material.dart';

class ProductFilterCriteria {
  final String? selectedCategoryId;
  final String? selectedCategoryName;
  final double minPrice;
  final double maxPrice;
  final double? minRating;
  final bool inStockOnly;
  final bool purchasedOnly;
  final bool featuredOnly;

  const ProductFilterCriteria({
    this.selectedCategoryId,
    this.selectedCategoryName,
    this.minPrice = 0,
    this.maxPrice = 100000,
    this.minRating,
    this.inStockOnly = false,
    this.purchasedOnly = false,
    this.featuredOnly = false,
  });

  ProductFilterCriteria copyWith({
    String? selectedCategoryId,
    String? selectedCategoryName,
    bool clearCategory = false,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    bool clearRating = false,
    bool? inStockOnly,
    bool? purchasedOnly,
    bool? featuredOnly,
  }) {
    return ProductFilterCriteria(
      selectedCategoryId: clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      selectedCategoryName: clearCategory ? null : (selectedCategoryName ?? this.selectedCategoryName),
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minRating: clearRating ? null : (minRating ?? this.minRating),
      inStockOnly: inStockOnly ?? this.inStockOnly,
      purchasedOnly: purchasedOnly ?? this.purchasedOnly,
      featuredOnly: featuredOnly ?? this.featuredOnly,
    );
  }

  int get activeFilterCount {
    int count = 0;
    if (selectedCategoryId != null) count++;
    if (minPrice > 0 || maxPrice < 100000) count++;
    if (minRating != null && minRating! > 0) count++;
    if (inStockOnly) count++;
    if (purchasedOnly) count++;
    if (featuredOnly) count++;
    return count;
  }

  bool get isDefault => activeFilterCount == 0;
}

class ProductFilterSheet extends StatefulWidget {
  final ProductFilterCriteria initialCriteria;
  final List<dynamic> categories;
  final ValueChanged<ProductFilterCriteria> onApply;

  const ProductFilterSheet({
    super.key,
    required this.initialCriteria,
    required this.categories,
    required this.onApply,
  });

  static Future<ProductFilterCriteria?> show(
    BuildContext context, {
    required ProductFilterCriteria initialCriteria,
    required List<dynamic> categories,
  }) {
    return showModalBottomSheet<ProductFilterCriteria>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ProductFilterSheet(
        initialCriteria: initialCriteria,
        categories: categories,
        onApply: (criteria) {
          Navigator.of(ctx).pop(criteria);
        },
      ),
    );
  }

  @override
  State<ProductFilterSheet> createState() => _ProductFilterSheetState();
}

class _ProductFilterSheetState extends State<ProductFilterSheet> {
  late String? _selectedCategoryId;
  late String? _selectedCategoryName;
  late RangeValues _priceRange;
  late double? _minRating;
  late bool _inStockOnly;
  late bool _purchasedOnly;
  late bool _featuredOnly;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCriteria.selectedCategoryId;
    _selectedCategoryName = widget.initialCriteria.selectedCategoryName;
    _priceRange = RangeValues(
      widget.initialCriteria.minPrice.clamp(0, 100000),
      widget.initialCriteria.maxPrice.clamp(0, 100000),
    );
    _minRating = widget.initialCriteria.minRating;
    _inStockOnly = widget.initialCriteria.inStockOnly;
    _purchasedOnly = widget.initialCriteria.purchasedOnly;
    _featuredOnly = widget.initialCriteria.featuredOnly;
  }

  void _resetAll() {
    setState(() {
      _selectedCategoryId = null;
      _selectedCategoryName = null;
      _priceRange = const RangeValues(0, 100000);
      _minRating = null;
      _inStockOnly = false;
      _purchasedOnly = false;
      _featuredOnly = false;
    });
  }

  ProductFilterCriteria _buildCriteria() {
    return ProductFilterCriteria(
      selectedCategoryId: _selectedCategoryId,
      selectedCategoryName: _selectedCategoryName,
      minPrice: _priceRange.start,
      maxPrice: _priceRange.end,
      minRating: _minRating,
      inStockOnly: _inStockOnly,
      purchasedOnly: _purchasedOnly,
      featuredOnly: _featuredOnly,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final criteria = _buildCriteria();

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.88,
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: Color(0xFF0284C7), size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (criteria.activeFilterCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${criteria.activeFilterCount} active',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                TextButton(
                  onPressed: criteria.isDefault ? null : _resetAll,
                  child: Text(
                    'Reset All',
                    style: TextStyle(
                      color: criteria.isDefault ? Colors.grey.shade400 : const Color(0xFFE11D48),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scrollable Filter Sections
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                // 1. Categories
                _buildSectionHeader('CATEGORY', Icons.category_outlined),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCategoryPill(null, 'All Categories'),
                    ...widget.categories.map((c) {
                      final name = c['name'] ?? '';
                      final id = c['id'] ?? '';
                      final count = c['_count']?['products'];
                      final label = count != null ? '$name ($count)' : name;
                      return _buildCategoryPill(id, label, rawName: name);
                    }),
                  ],
                ),

                const SizedBox(height: 24),
                // 2. Price Range
                _buildSectionHeader('PRICE RANGE', Icons.currency_rupee),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${_priceRange.start.round()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0284C7)),
                    ),
                    Text(
                      _priceRange.end >= 100000 ? '₹1,00,000+' : '₹${_priceRange.end.round()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0284C7)),
                    ),
                  ],
                ),
                RangeSlider(
                  values: _priceRange,
                  min: 0,
                  max: 100000,
                  divisions: 20,
                  activeColor: const Color(0xFF0284C7),
                  inactiveColor: const Color(0xFFE2E8F0),
                  onChanged: (vals) {
                    setState(() => _priceRange = vals);
                  },
                ),
                // Quick price presets
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildPricePreset('Under ₹5k', 0, 5000),
                    _buildPricePreset('₹5k - ₹15k', 5000, 15000),
                    _buildPricePreset('₹15k - ₹30k', 15000, 30000),
                    _buildPricePreset('₹30k - ₹50k', 30000, 50000),
                    _buildPricePreset('Above ₹50k', 50000, 100000),
                  ],
                ),

                const SizedBox(height: 24),
                // 3. Customer Rating
                _buildSectionHeader('MINIMUM CUSTOMER RATING', Icons.star_rate_rounded),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildRatingChip(null, 'Any Rating'),
                    _buildRatingChip(4.0, '4★ & Above'),
                    _buildRatingChip(3.0, '3★ & Above'),
                    _buildRatingChip(2.0, '2★ & Above'),
                  ],
                ),

                const SizedBox(height: 24),
                // 4. Availability & Specialized Toggles
                _buildSectionHeader('AVAILABILITY & PREFERENCES', Icons.verified_outlined),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _inStockOnly,
                        activeTrackColor: const Color(0xFF0284C7),
                        title: const Text('In Stock Only', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Hide purifiers and spares currently out of stock', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        onChanged: (val) => setState(() => _inStockOnly = val),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: _purchasedOnly,
                        activeTrackColor: const Color(0xFF0284C7),
                        title: const Text('Purchased by Me', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Show only products you have bought (re-order & review)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        onChanged: (val) => setState(() => _purchasedOnly = val),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        value: _featuredOnly,
                        activeTrackColor: const Color(0xFF0284C7),
                        title: const Text('Featured & Best Value', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Show top recommended models and flagship purifiers', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        onChanged: (val) => setState(() => _featuredOnly = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => widget.onApply(_buildCriteria()),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    criteria.activeFilterCount > 0
                        ? 'Apply Filters (${criteria.activeFilterCount})'
                        : 'Show All Products',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPill(String? categoryId, String label, {String? rawName}) {
    final isSelected = _selectedCategoryId == categoryId;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedCategoryId = categoryId;
            _selectedCategoryName = rawName ?? (categoryId == null ? null : label);
          } else {
            _selectedCategoryId = null;
            _selectedCategoryName = null;
          }
        });
      },
      selectedColor: const Color(0xFF0284C7),
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF334155),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
        ),
      ),
    );
  }

  Widget _buildPricePreset(String label, double min, double max) {
    final isSelected = _priceRange.start == min && _priceRange.end == max;
    return InkWell(
      onTap: () {
        setState(() {
          _priceRange = RangeValues(min, max);
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE0F2FE) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingChip(double? rating, String label) {
    final isSelected = _minRating == rating;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rating != null) ...[
            const Icon(Icons.star_rate_rounded, size: 16, color: Colors.amber),
            const SizedBox(width: 4),
          ],
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _minRating = selected ? rating : null;
        });
      },
      selectedColor: const Color(0xFF0284C7),
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF334155),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
        ),
      ),
    );
  }
}
