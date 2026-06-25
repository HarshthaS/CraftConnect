import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'firebase_options.dart';

import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password.dart';

import 'screens/artisan_dashboard.dart';
import 'screens/buyer_dashboard.dart';

import 'screens/upload_product_manual.dart';
import 'screens/upload_product_voice.dart';
import 'screens/my_products.dart';
import 'screens/product_details.dart';

import 'screens/profile_screen.dart';

import 'screens/buyer_orders.dart';
import 'screens/artisan_orders.dart';

import 'screens/recommendations_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: 'https://zmdtadbagbuxeawvflef.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InptZHRhZGJhZ2J1eGVhd3ZmbGVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMxNTg4MjAsImV4cCI6MjA3ODczNDgyMH0.qF9ptJ4wNWLTcwwohAxRVw0Dgd5qbS5JEZTCg1hn6G8',
  );

  runApp(const CraftConnectApp());

  Future.microtask(() async {
    try {
      Stripe.publishableKey = "pk_test_REPLACE_WITH_YOUR_PUBLISHABLE_KEY";
      await Stripe.instance.applySettings();
    } catch (e) {
      print("Stripe init failed: $e");
    }
  });
}

class CraftConnectApp extends StatelessWidget {
  const CraftConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CraftConnect',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),

      initialRoute: '/login',

      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());

          case '/signup':
            return MaterialPageRoute(builder: (_) => const SignUpScreen());

          case '/forgot-password':
            return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());

          case '/artisan_dashboard':
            return MaterialPageRoute(builder: (_) => const ArtisanDashboard());

          case '/buyer_dashboard':
            return MaterialPageRoute(
              builder: (_) => BuyerDashboard(),
              settings: settings,
            );

          case '/upload_product_manual':
            return MaterialPageRoute(builder: (_) => const UploadProductManual());

          case '/upload_product_voice':
            return MaterialPageRoute(builder: (_) => const UploadProductVoice());

          case '/my_products':
            return MaterialPageRoute(builder: (_) => const MyProductsScreen());

          case '/profile':
            return MaterialPageRoute(builder: (_) => const ProfileScreen());

          case '/buyer_orders':
            return MaterialPageRoute(builder: (_) => const BuyerOrdersScreen());

          case '/artisan_orders':
            return MaterialPageRoute(builder: (_) => const ArtisanOrdersScreen());

          case '/product_details':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => ProductDetailsPage(
                productId: args['productId'],
                data: args['data'],
              ),
            );

          case '/recommendations':
            return MaterialPageRoute(
              builder: (_) => const RecommendationsScreen(),
            );
        }

        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );
      },
    );
  }
}
