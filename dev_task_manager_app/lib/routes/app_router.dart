import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/tasks/task_list_screen.dart';
import '../screens/tasks/task_detail_screen.dart';
import '../screens/tasks/task_form_screen.dart';
import '../screens/admin/admin_screen.dart';

class AppRouter {
  static GoRouter createRouter(AuthBloc authBloc) {
    return GoRouter(
      initialLocation: '/login',
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      redirect: (context, state) {
        final authState = authBloc.state;
        final isLoginPage = state.matchedLocation == '/login';
        final isRegisterPage = state.matchedLocation == '/register';

        if (authState is AuthSuccess) {
          if (isLoginPage || isRegisterPage) {
            return '/home';
          }
        } else if (authState is AuthUnauthenticated) {
          if (!isLoginPage && !isRegisterPage) {
            return '/login';
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
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        // Create a shell route for authenticated pages with proper navigation
        ShellRoute(
          builder: (context, state, child) {
            return MainNavigationWrapper(child: child);
          },
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
            GoRoute(
              path: '/tasks',
              builder: (context, state) => const TaskListScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (context, state) => const TaskFormScreen(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) => TaskDetailScreen(
                    taskId: state.pathParameters['id']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) => TaskFormScreen(
                        taskId: state.pathParameters['id']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/admin',
              builder: (context, state) => const AdminScreen(),
            ),
          ],
        ),
      ],
    );
  }
}

// Navigation wrapper to handle back button properly
class MainNavigationWrapper extends StatelessWidget {
  final Widget child;

  const MainNavigationWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Handle back button press
        final canPop = GoRouter.of(context).canPop();
        if (canPop) {
          GoRouter.of(context).pop();
          return false;
        } else {
          // If can't pop, go to home instead of exiting
          GoRouter.of(context).go('/home');
          return false;
        }
      },
      child: child,
    );
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
