import 'package:flutter/material.dart';

import '../features/auth/login/login_screen.dart';
import '../features/auth/signup/signup_screen.dart';
import '../features/admin/admin_shell.dart';
import '../features/dashboard/client_dashboard_screen.dart';
import '../features/driver/driver_dashboard_screen.dart';
import '../features/delivery/delivery_categories_screen.dart';
import '../features/delivery/gas_delivery_location_screen.dart';
import '../features/delivery/gas_order_screen.dart';
import '../features/delivery/parcel/parcel_expedition_screen.dart';
import '../features/delivery/parcel/parcel_express_screen.dart';
import '../features/events/event_catalog_screen.dart';
import '../features/events/event_detail_screen.dart';
import '../features/events/my_tickets_screen.dart';
import '../features/food/food_hub_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/splash/splash_screen.dart';

abstract class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';
  static const dashboard = '/dashboard';
  static const driverDashboard = '/driver/dashboard';
  static const adminDashboard = '/admin/dashboard';
  static const deliveryCategories = '/delivery/categories';
  static const gasOrder = '/delivery/gas-order';
  static const gasLocation = '/delivery/gas/location';
  static const parcelExpress = '/delivery/parcel/express';
  static const parcelExpedition = '/delivery/parcel/expedition';
  static const foodHub = '/food/hub';
  static const events = '/events';
  static const eventDetail = '/events/detail';
  static const myTickets = '/events/my-tickets';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case signup:
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      case dashboard:
        final args = settings.arguments;
        final initialTab = args is int ? args : 0;
        return MaterialPageRoute(builder: (_) => ClientDashboardScreen(initialTab: initialTab));
       case driverDashboard:
         return MaterialPageRoute(builder: (_) => const DriverDashboardScreen());
       case adminDashboard:
         return MaterialPageRoute(builder: (_) => const AdminShell());
       case deliveryCategories:
         return MaterialPageRoute(builder: (_) => const DeliveryCategoriesScreen());
       case gasOrder:
         return MaterialPageRoute(builder: (_) => const GasOrderScreen());
       case gasLocation:
         return MaterialPageRoute(builder: (_) => const GasDeliveryLocationScreen());
       case parcelExpress:
         return MaterialPageRoute(builder: (_) => const ParcelExpressScreen());
       case parcelExpedition:
         final args = settings.arguments;
         return MaterialPageRoute(
           builder: (_) => ParcelExpeditionScreen(
             draft: args is ParcelDraft ? args : const ParcelDraft(),
           ),
         );
       case foodHub:
         return MaterialPageRoute(builder: (_) => const FoodHubScreen());
       case events:
         return MaterialPageRoute(builder: (_) => const EventCatalogScreen());
       case eventDetail:
         final args = settings.arguments;
         final eventId = args is int ? args : (int.tryParse(args?.toString() ?? '') ?? 0);
         return MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: eventId));
       case myTickets:
         return MaterialPageRoute(builder: (_) => const MyTicketsScreen());
       default:
         return MaterialPageRoute(
           builder: (_) => Scaffold(
             body: Center(
               child: Text('Route inconnue: ${settings.name}'),
             ),
           ),
         );
    }
  }
}

