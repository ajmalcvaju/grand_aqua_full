import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/auth_provider.dart';

class AdminDrawer extends ConsumerWidget {
  final String currentRoute;
  const AdminDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    final navItems = [
      {
        'title': 'Dashboard',
        'route': '/dashboard',
        'icon': Icons.dashboard_outlined,
      },
      {
        'title': 'Buyers (4 Categories)',
        'route': '/buyers',
        'icon': Icons.people_outline,
      },
      {
        'title': 'Search Keywords',
        'route': '/search-keywords',
        'icon': Icons.search_outlined,
      },
      {
        'title': 'Credit Management',
        'route': '/credit',
        'icon': Icons.credit_card_outlined,
      },
      {
        'title': 'Loyalty & Gift Rewards',
        'route': '/loyalty',
        'icon': Icons.loyalty_outlined,
      },
      {
        'title': 'Category Management',
        'route': '/categories',
        'icon': Icons.category_outlined,
      },
      {
        'title': 'Banner Management',
        'route': '/banners',
        'icon': Icons.image_outlined,
      },
      {
        'title': 'Products & 4-Tier Pricing',
        'route': '/products',
        'icon': Icons.inventory_2_outlined,
      },
      {
        'title': 'Salesman Management',
        'route': '/salesmen',
        'icon': Icons.badge_outlined,
      },
      {
        'title': 'Quotations & Approvals',
        'route': '/quotations',
        'icon': Icons.request_quote_outlined,
      },
      {
        'title': 'Order Management',
        'route': '/orders',
        'icon': Icons.shopping_cart_outlined,
      },
      {
        'title': 'Payments & Receivables',
        'route': '/payments',
        'icon': Icons.payments_outlined,
      },
      {
        'title': 'Settings & Admin Roles',
        'route': '/settings',
        'icon': Icons.settings_outlined,
      },
    ];

    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          children: [
            // Header / Brand (Official Grand Aqua Logo)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1E293B)),
                ),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/grand_aqua_logo.png',
                  height: 42,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // User Info Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?['fullName'] ?? 'Super Admin',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user?['role'] ?? 'SUPER_ADMIN',
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, size: 18, color: Color(0xFF94A3B8)),
                    tooltip: 'Logout',
                    onPressed: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ],
              ),
            ),

            // Navigation List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                itemCount: navItems.length,
                separatorBuilder: (context, index) => const SizedBox(height: 2),
                itemBuilder: (context, i) {
                  final item = navItems[i];
                  final isCurrent = currentRoute == item['route'];

                  return ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    tileColor: isCurrent ? const Color(0xFF0284C7) : Colors.transparent,
                    leading: Icon(
                      item['icon'] as IconData,
                      color: isCurrent ? Colors.white : const Color(0xFF94A3B8),
                      size: 20,
                    ),
                    title: Text(
                      item['title'] as String,
                      style: TextStyle(
                        color: isCurrent ? Colors.white : const Color(0xFFCBD5E1),
                        fontSize: 12,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    trailing: isCurrent
                        ? const Icon(Icons.chevron_right, color: Colors.white70, size: 18)
                        : null,
                    onTap: () {
                      Navigator.pop(context); // close drawer
                      if (!isCurrent) {
                        context.go(item['route'] as String);
                      }
                    },
                  );
                },
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                  SizedBox(width: 6),
                  Text(
                    'Server Connected • Grand Aqua v1.0.0',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
