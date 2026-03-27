import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/folder_screen.dart';
import 'screens/list_view_screen.dart';
import 'screens/share_list_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'theme/colors.dart';

void main() async {
  // Ensure Flutter is initialized before Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase — must happen before runApp
  await Firebase.initializeApp();

  runApp(const NestlyQuickApp());
}

// root widget of the entire app
class NestlyQuickApp extends StatelessWidget {
  const NestlyQuickApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NestlyQuick',
      debugShowCheckedModeBanner: false,

      // App-wide theme using our purple/pink color scheme
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          background: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.dark,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.primaryLighter,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),

      // GoRouter handles all navigation
      routerConfig: _router,
    );
  }
}

// GoRouter configuration — defines all routes in the app
final GoRouter _router = GoRouter(
  // app starts at login screen
  initialLocation: '/login',
  routes: [

    // login screen doesn't no bottom nav
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

    // main shell  wraps all tabs with the bottom navigation bar
    ShellRoute(
      builder: (context, state, child) => ScaffoldWithBottomNav(child: child),
      routes: [

        // Lists tab — the main dashboard showing all lists
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
          routes: [

            // Folder screen — pushed on top when a folder card is tapped
            GoRoute(
              path: 'folder/:folderId',
              builder: (context, state) => FolderScreen(
                folderId: state.pathParameters['folderId']!,
              ),
            ),

            // List view screen — pushed on top when a list card is tapped
            GoRoute(
              path: 'list/:listId',
              builder: (context, state) => ListViewScreen(
                listId: state.pathParameters['listId']!,
              ),
            ),

            // Share list screen — pushed from inside list view
            GoRoute(
              path: 'list/:listId/share',
              builder: (context, state) => ShareListScreen(
                listId: state.pathParameters['listId']!,
              ),
            ),
          ],
        ),

        // Friends tab
        GoRoute(
          path: '/friends',
          builder: (context, state) => const FriendsPlaceholderScreen(),
        ),

        // Notifications tab
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),

        // Settings tab
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
          routes: [
            // Edit profile — pushed from settings
            GoRoute(
              path: 'edit-profile',
              builder: (context, state) => const EditProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

// bottom navigation shell  persists across all tab screens
class ScaffoldWithBottomNav extends StatelessWidget {
  final Widget child;
  const ScaffoldWithBottomNav({super.key, required this.child});

  // Returns the index of the currently active tab based on the route
  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/friends')) return 1;
    if (location.startsWith('/notifications')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _getCurrentIndex(context),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.subtext,
        backgroundColor: AppColors.background,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        onTap: (index) {
          // Navigate to the correct tab when tapped
          switch (index) {
            case 0:
              context.go('/dashboard');
              break;
            case 1:
              context.go('/friends');
              break;
            case 2:
              context.go('/notifications');
              break;
            case 3:
              context.go('/settings');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list_rounded),
            label: 'Lists',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline_rounded),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none_rounded),
            label: 'Notifs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// temporary placeholder for Friends screen  will be built out later
class FriendsPlaceholderScreen extends StatelessWidget {
  const FriendsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Friends — Coming Soon'),
      ),
    );
  }
}