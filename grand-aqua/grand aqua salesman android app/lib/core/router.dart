import 'package:go_router/go_router.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/shops_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/quotations_screen.dart';
import '../screens/quotation_builder_screen.dart';
import '../screens/incentives_screen.dart';

final GoRouter salesmanRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const SalesmanLoginScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const SalesmanDashboardScreen(),
    ),
    GoRoute(
      path: '/shops',
      builder: (context, state) => const ShopsScreen(),
    ),
    GoRoute(
      path: '/orders',
      builder: (context, state) => const SalesmanOrdersScreen(),
    ),
    GoRoute(
      path: '/quotations',
      builder: (context, state) => const QuotationsScreen(),
    ),
    GoRoute(
      path: '/quotation-builder',
      builder: (context, state) => const QuotationBuilderScreen(),
    ),
    GoRoute(
      path: '/incentives',
      builder: (context, state) => const IncentivesScreen(),
    ),
  ],
);
