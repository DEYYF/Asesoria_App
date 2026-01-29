import 'package:asesoria_app/screens/first_login_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/settings_service.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/super_admin_provider.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
// import 'screens/home_screen.dart';
import 'screens/client_dashboard_screen.dart';
import 'screens/client_profile_screen.dart';
import 'screens/diet/create_diet_screen.dart';
import 'screens/training/create_training_screen.dart';
import 'screens/training/training_detail_screen.dart';
import 'screens/training/notebook_screen.dart';
import 'screens/training/live_session_screen.dart';
import 'screens/exercises/ejercicios_screen.dart';
import 'screens/meals/comidas_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'widgets/scaffold_with_navbar.dart';
import 'services/chat_service.dart';
import 'screens/chat/advisor_chat_list_screen.dart';
import 'screens/chat/chat_detail_screen.dart';
import 'screens/chat/chat_contacts_screen.dart';
import 'screens/advisor_calendar_screen.dart'; // Add
import 'screens/presupuestos_screen.dart';
import 'screens/settings/automation_screen.dart';
import 'services/template_service.dart';
import 'screens/settings/finanzas_screen.dart';
import 'screens/tasks/kanban_screen.dart';
import 'services/task_service.dart';
import 'screens/settings/team_management_screen.dart';
import 'screens/settings/advisor_detail_screen.dart';
import 'services/google_calendar_service.dart';
import 'services/smart_insights_service.dart';

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
        ProxyProvider2<ApiService, AuthService, ChatService>(
          update: (_, api, auth, __) => ChatService(api, auth),
          dispose: (_, chat) => chat.dispose(),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProxyProvider<ApiService, TemplateService>(
          create: (context) =>
              TemplateService(Provider.of<ApiService>(context, listen: false)),
          update: (_, api, previous) => previous ?? TemplateService(api),
        ),
        ChangeNotifierProxyProvider<ApiService, SettingsProvider>(
          create: (context) => SettingsProvider(
            SettingsService(Provider.of<ApiService>(context, listen: false)),
          ),
          update: (_, api, previous) =>
              previous ?? SettingsProvider(SettingsService(api)),
        ),
        ChangeNotifierProxyProvider<ApiService, TaskService>(
          create: (context) =>
              TaskService(Provider.of<ApiService>(context, listen: false)),
          update: (_, api, previous) => previous ?? TaskService(api),
        ),
        ChangeNotifierProxyProvider<ApiService, SuperAdminProvider>(
          create: (context) => SuperAdminProvider(
            Provider.of<ApiService>(context, listen: false),
          ),
          update: (_, api, previous) => previous ?? SuperAdminProvider(api),
        ),
        ChangeNotifierProxyProvider<ApiService, GoogleCalendarService>(
          create: (context) => GoogleCalendarService(
            Provider.of<ApiService>(context, listen: false),
          ),
          update: (_, api, previous) => previous ?? GoogleCalendarService(api),
        ),
        ProxyProvider<ApiService, SmartInsightsService>(
          update: (_, api, __) => SmartInsightsService(api),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late GoRouter _router;
  late AuthService _auth;

  @override
  void initState() {
    super.initState();
    _auth = Provider.of<AuthService>(context, listen: false);
    _router = _buildRouter();

    // Sync theme settings on app start if already logged in
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_auth.isAuthenticated) {
        final settingsProvider = Provider.of<SettingsProvider>(
          context,
          listen: false,
        );
        await settingsProvider.loadSettings();
        if (mounted && settingsProvider.settings != null) {
          Provider.of<ThemeProvider>(
            context,
            listen: false,
          ).syncWithSettings(settingsProvider.settings!.toJson());
        }
      }
    });
  }

  GoRouter _buildRouter() {
    return GoRouter(
      refreshListenable: _auth,
      initialLocation: '/',
      redirect: (context, state) {
        final loggedIn = _auth.isAuthenticated;
        final onLogin = state.matchedLocation == '/login';
        final onFirstLogin = state.matchedLocation == '/first-login';

        // Not logged in - redirect to login (allow first-login screen)
        if (!loggedIn && !onLogin && !onFirstLogin) {
          return '/login';
        }

        // Logged in on login page - redirect to appropriate home
        if (loggedIn && (onLogin || onFirstLogin)) {
          return _auth.isClient ? '/clientes/${_auth.userId}' : '/';
        }

        // Client access restrictions
        if (loggedIn && _auth.isClient) {
          final currentPath = state.matchedLocation;

          // Prevent clients from accessing dashboard
          if (currentPath == '/') {
            return '/clientes/${_auth.userId}';
          }

          // Prevent clients from accessing other client profiles
          if (currentPath.startsWith('/clientes/')) {
            final pathClientId = state.pathParameters['id'];
            if (pathClientId != null && pathClientId != _auth.userId) {
              return '/clientes/${_auth.userId}';
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
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return ScaffoldWithNavbar(navigationShell: navigationShell);
          },
          branches: [
            // Branch 0: Dashboard/Clients
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const ClientDashboardScreen(),
                  routes: [
                    GoRoute(
                      path: 'clientes/:id',
                      builder: (context, state) {
                        return ClientProfileScreen(
                          clienteId: state.pathParameters['id']!,
                        );
                      },
                      routes: [
                        GoRoute(
                          path: 'crear-dieta',
                          builder: (context, state) => CreateDietScreen(
                            clienteId: state.pathParameters['id']!,
                          ),
                        ),
                        GoRoute(
                          path: 'crear-entrenamiento',
                          builder: (context, state) => CreateTrainingScreen(
                            clienteId: state.pathParameters['id']!,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            // Branch 1: Exercises
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/ejercicios',
                  builder: (context, state) => const EjerciciosScreen(),
                ),
              ],
            ),
            // Branch 2: Comidas
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/comidas',
                  builder: (context, state) => const ComidasScreen(),
                ),
              ],
            ),
            // Branch 3: Chat
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/chat',
                  builder: (context, state) => const AdvisorChatListScreen(),
                  routes: [
                    GoRoute(
                      path: 'new',
                      builder: (context, state) => const ChatContactsScreen(),
                    ),
                  ],
                ),
              ],
            ),
            // Branch 4: Settings
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (context, state) => const SettingsScreen(),
                ),
              ],
            ),
            // Branch 5: Calendar (Advisor)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/calendar',
                  builder: (context, state) => const AdvisorCalendarScreen(),
                ),
              ],
            ),
            // Branch 6: Presupuestos
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/presupuestos',
                  builder: (context, state) => const PresupuestosScreen(),
                ),
              ],
            ),
            // Branch 7: Automation
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/automation',
                  builder: (context, state) => const AutomationScreen(),
                ),
              ],
            ),
            // Branch 8: Finanzas
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/finanzas',
                  builder: (context, state) => const FinanzasScreen(),
                ),
              ],
            ),
            // Branch 9: Tasks
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/tasks',
                  builder: (context, state) => const KanbanScreen(),
                ),
              ],
            ),
            // Branch 10: Team Management (Super Admin only)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/team',
                  builder: (context, state) => const TeamManagementScreen(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/chat/:id',
          builder: (context, state) =>
              ChatDetailScreen(conversationId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/entrenamientos/sesion/:id',
          builder: (context, state) =>
              LiveSessionScreen(entrenamientoId: state.pathParameters['id']!),
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
        GoRoute(
          path: '/team/:id',
          builder: (context, state) =>
              AdvisorDetailScreen(advisorId: state.pathParameters['id']!),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp.router(
      title: 'Asesoría App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(themeProvider.accentColor, isDark: false),
      darkTheme: AppTheme.getTheme(themeProvider.accentColor, isDark: true),
      themeMode: themeProvider.themeMode,
      routerConfig: _router,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],
    );
  }
}
