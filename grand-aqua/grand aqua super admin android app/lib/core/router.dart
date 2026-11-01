import 'package:go_router/go_router.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/buyers_screen.dart';
import '../screens/quotations_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/products_screen.dart';
import '../screens/categories_screen.dart';
import '../screens/salesmen_screen.dart';
import '../screens/payments_screen.dart';
import '../screens/credit_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/search_keywords_screen.dart';
import '../screens/banners_screen.dart';
import '../screens/loyalty_screen.dart';

final GoRouter adminRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const AdminLoginScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductsScreen(),
    ),
    GoRoute(
      path: '/categories',
      builder: (context, state) => const CategoriesScreen(),
    ),
    GoRoute(
      path: '/buyers',
      builder: (context, state) => const BuyersScreen(),
    ),
    GoRoute(
      path: '/salesmen',
      builder: (context, state) => const SalesmenScreen(),
    ),
    GoRoute(
      path: '/quotations',
      builder: (context, state) => const QuotationsScreen(),
    ),
    GoRoute(
      path: '/orders',
      builder: (context, state) => const OrdersScreen(),
    ),
    GoRoute(
      path: '/payments',
      builder: (context, state) => const PaymentsScreen(),
    ),
    GoRoute(
      path: '/credit',
      builder: (context, state) => const CreditScreen(),
    ),
    GoRoute(
      path: '/banners',
      builder: (context, state) => const BannersScreen(),
    ),
    GoRoute(
      path: '/search-keywords',
      builder: (context, state) => const SearchKeywordsScreen(),
    ),
    GoRoute(
      path: '/loyalty',
      builder: (context, state) => const LoyaltyScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
