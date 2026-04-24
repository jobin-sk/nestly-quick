import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/folder_screen.dart';
import 'screens/list_view_screen.dart';
import 'screens/share_list_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'services/auth_service.dart';
import 'theme/colors.dart';
import 'screens/friends_screen.dart';

//async then were waiting for firebase to intialize before app starts
void main() async {
  //flutter needs its binding ready before any async platform
  WidgetsFlutterBinding.ensureInitialized();
  // initialize firebase  must happen before runApp
  await Firebase.initializeApp();
  //multi provider makes auth service available to every screen so we dont pass user around manually
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const NestlyQuickApp(),
    ),
  );
}

// root widget of the whole app
class NestlyQuickApp extends StatelessWidget {
  const NestlyQuickApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NestlyQuick',
      debugShowCheckedModeBanner: false,

      // setting theme for reference colors so we can change these later ( so always consistent across pages)
      // scarlett says to much white
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          background: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
// top bar themes
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.dark,
          elevation: 0,
          centerTitle: true,
        ),
        //elevated button in app dont have to restyle buttons on all the screens now :D
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),

        //default  style for text input fields gives login sign up fields and bottom sheet consistent color ( purple now switch to pink to show )
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
      //plugs gorouter into app all navigation action is routed through this config
      routerConfig: _router,
    );
  }
}
//all nav for the app is here isntead of scattered push calls
final GoRouter _router = GoRouter(
  //first screen the app tries to show on laucnh if already loged in sends to dashboard
  initialLocation: '/login',

  // redirect checks Firebase auth state on every navigation
  redirect: (context, state) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isLoggedIn = authService.currentUser != null;
    final isOnAuthScreen = state.matchedLocation == '/login' ||
        state.matchedLocation == '/signup';

    if (!isLoggedIn && !isOnAuthScreen) return '/login';
    if (isLoggedIn && isOnAuthScreen) return '/dashboard';
    return null;
  },
// these sit outside  shellroute so they dont show nav bar until theyre logged in
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    //wraps every screen inside it with the scaffoldwith bottom nav widget, this way the bottom stays persistent
    ShellRoute(
      builder: (context, state, child) => ScaffoldWithBottomNav(child: child),
      routes: [

        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
          routes: [
            GoRoute(
              //folderid is path param w/e value is in url gets passed to folderscreen
              path: 'folder/:folderId',
              builder: (context, state) => FolderScreen(
                folderId: state.pathParameters['folderId']!,
              ),
            ),
            GoRoute(
              path: 'list/:listId',
              builder: (context, state) => ListViewScreen(
                listId: state.pathParameters['listId']!,
              ),
            ),
            //share screen is nested under specific list so it knows which ones being shared
            GoRoute(
              path: 'list/:listId/share',
              builder: (context, state) => ShareListScreen(
                listId: state.pathParameters['listId']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/friends',
          builder: (context, state) => const FriendsScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
          routes: [
            //edit profile is nested under settings should return user to the settings screen naturally
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
//the persistent scaffold that wraps every main screen shoulds current routes content in the body and bottom nav bar below it
class ScaffoldWithBottomNav extends StatelessWidget {
  final Widget child;
  const ScaffoldWithBottomNav({super.key, required this.child});
//highlights tab based on current route.
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
        //context.go() replaces the currnt rounte instead of stacking on old ones
        onTap: (index) {
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
            label: 'Alerts',
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

