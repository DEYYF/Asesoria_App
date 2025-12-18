import 'package:asesoria_app/screens/first_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
// import 'screens/home_screen.dart';
import 'screens/client_dashboard_screen.dart';
import 'screens/client_profile_screen.dart';
import 'screens/diet/create_diet_screen.dart';
import 'screens/training/create_training_screen.dart';
import 'screens/training/training_detail_screen.dart';
import 'screens/training/notebook_screen.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize Spanish locale date formatting
  await initializeDateFormatting('es');

  final authService = AuthService();
  await authService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        Provider(create: (_) => ApiService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    final router = GoRouter(
      refreshListenable: auth,
      initialLocation: '/',
      redirect: (context, state) {
        final loggedIn = auth.isAuthenticated;
        final onLogin = state.matchedLocation == '/login';
        final onFirstLogin = state.matchedLocation == '/first-login';

        print(
          'Router Redirect: path=${state.matchedLocation}, loggedIn=$loggedIn, onLogin=$onLogin, onFirstLogin=$onFirstLogin',
        );

        // Not logged in - redirect to login (allow first-login screen)
        if (!loggedIn && !onLogin && !onFirstLogin) {
          print('Redirecting to /login (auth required)');
          return '/login';
        }

        // Logged in on login page - redirect to appropriate home
        if (loggedIn && (onLogin || onFirstLogin)) {
          final target = auth.isClient ? '/clientes/${auth.userId}' : '/';
          print('Already logged in, redirecting to $target');
          return target;
        }

        // Client access restrictions
        if (loggedIn && auth.isClient) {
          final currentPath = state.matchedLocation;

          // Prevent clients from accessing dashboard
          if (currentPath == '/') {
            print('Client tried to access dashboard, redirecting to profile');
            return '/clientes/${auth.userId}';
          }

          // Prevent clients from accessing other client profiles
          if (currentPath.startsWith('/clientes/')) {
            final pathClientId = state.pathParameters['id'];
            if (pathClientId != null && pathClientId != auth.userId) {
              print(
                'Client tried to access another profile, redirecting to own',
              );
              return '/clientes/${auth.userId}';
            }
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/first-login',
          builder: (context, state) {
            final email = state.uri.queryParameters['email'] ?? '';
            return FirstLoginScreen(email: email);
          },
        ),
        // GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/',
          builder: (context, state) => const ClientDashboardScreen(),
        ),
        GoRoute(
          path: '/clientes/:id',
          builder: (context, state) =>
              ClientProfileScreen(clienteId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/clientes/:id/crear-dieta',
          builder: (context, state) =>
              CreateDietScreen(clienteId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/clientes/:id/crear-entrenamiento',
          builder: (context, state) =>
              CreateTrainingScreen(clienteId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/entrenamientos/:id',
          builder: (context, state) => TrainingDetailScreen(
            entrenamientoId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/entrenamientos/cuaderno/:id',
          builder: (context, state) =>
              NotebookScreen(entrenamientoId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/entrenamientos/:id/editar',
          builder: (context, state) => CreateTrainingScreen(
            entrenamientoId: state.pathParameters['id'],
            clienteId: null, // Context will load via API
          ),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Asesoría App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
