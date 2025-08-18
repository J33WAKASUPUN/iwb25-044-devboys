import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/stats/stats_bloc.dart';
import '../../blocs/stats/stats_event.dart';
import '../../blocs/stats/stats_state.dart';
import '../../utils/constants.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';
import '../../services/stats_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load statistics when screen initializes
    context.read<StatsBloc>().add(LoadStats());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Task Manager',
          style: AppConstants.headerStyle,
        ),
        backgroundColor: AppConstants.whiteColor,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(
              Icons.person,
              color: AppConstants.secondaryColor,
            ),
            onPressed: () => context.go('/profile'),
          ),
          IconButton(
            icon: Icon(
              Icons.logout,
              color: AppConstants.errorColor,
            ),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthUnauthenticated) {
            context.go('/login');
          }
        },
        child: RefreshIndicator(
          onRefresh: () async {
            context.read<StatsBloc>().add(RefreshStats());
          },
          color: AppConstants.primaryColor,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeCard(),
                const SizedBox(height: AppConstants.largePadding),
                _buildQuickActions(context),
                const SizedBox(height: AppConstants.largePadding),
                _buildStatsCards(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/tasks/create'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: AppConstants.whiteColor,
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        String userName = 'User';
        if (state is AuthSuccess) {
          userName = state.user.name;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppConstants.largePadding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppConstants.primaryColor,
                AppConstants.secondaryColor,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, $userName!',
                style: AppConstants.headerStyle.copyWith(
                  color: AppConstants.whiteColor,
                ),
              ),
              const SizedBox(height: AppConstants.smallPadding),
              Text(
                'Stay organized and manage your tasks efficiently',
                style: AppConstants.bodyStyle.copyWith(
                  color: AppConstants.whiteColor.withOpacity(0.9),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppConstants.subHeaderStyle,
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.add_task,
                title: 'Create Task',
                subtitle: 'Add a new task',
                color: AppConstants.primaryColor,
                onTap: () => context.go('/tasks/create'),
              ),
            ),
            const SizedBox(width: AppConstants.defaultPadding),
            Expanded(
              child: _buildActionCard(
                icon: Icons.list_alt,
                title: 'View Tasks',
                subtitle: 'See all tasks',
                color: AppConstants.secondaryColor,
                onTap: () => context.go('/tasks'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: AppConstants.smallPadding),
              Text(
                title,
                style: AppConstants.subHeaderStyle.copyWith(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppConstants.bodyStyle.copyWith(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Task Statistics',
          style: AppConstants.subHeaderStyle,
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        BlocBuilder<StatsBloc, StatsState>(
          builder: (context, state) {
            if (state is StatsLoading) {
              return const LoadingWidget(message: 'Loading statistics...');
            } else if (state is StatsError) {
              return ErrorDisplayWidget(
                message: state.message,
                onRetry: () => context.read<StatsBloc>().add(LoadStats()),
              );
            } else if (state is StatsLoaded) {
              return _buildStatsContent(state.statistics);
            }

            // Initial state - show loading
            return const LoadingWidget(message: 'Loading statistics...');
          },
        ),
      ],
    );
  }

  Widget _buildStatsContent(TaskStatistics stats) {
    return Column(
      children: [
        // First row - Overall stats
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total Tasks',
                value: stats.total.toString(),
                icon: Icons.assignment,
                color: AppConstants.primaryColor,
              ),
            ),
            const SizedBox(width: AppConstants.defaultPadding),
            Expanded(
              child: _buildStatCard(
                title: 'Overdue',
                value: stats.overdue.toString(),
                icon: Icons.warning,
                color: AppConstants.errorColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        // Second row - Status breakdown
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'To Do',
                value: (stats.byStatus['TODO'] ?? 0).toString(),
                icon: Icons.pending_actions,
                color: Colors.grey[600]!,
              ),
            ),
            const SizedBox(width: AppConstants.defaultPadding),
            Expanded(
              child: _buildStatCard(
                title: 'In Progress',
                value: (stats.byStatus['IN_PROGRESS'] ?? 0).toString(),
                icon: Icons.hourglass_bottom,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        // Third row - Priority and Completed
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Completed',
                value: (stats.byStatus['COMPLETED'] ?? 0).toString(),
                icon: Icons.check_circle,
                color: AppConstants.primaryColor,
              ),
            ),
            const SizedBox(width: AppConstants.defaultPadding),
            Expanded(
              child: _buildStatCard(
                title: 'High Priority',
                value: (stats.byPriority['HIGH'] ?? 0).toString(),
                icon: Icons.priority_high,
                color: AppConstants.errorColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              value,
              style: AppConstants.headerStyle.copyWith(
                fontSize: 24,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: AppConstants.bodyStyle.copyWith(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<AuthBloc>().add(LogoutRequested());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.errorColor,
                foregroundColor: AppConstants.whiteColor,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}
