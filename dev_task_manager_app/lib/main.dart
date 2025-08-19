import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'app.dart';
import 'test_api.dart'; // Uncommented for testing

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Uncommented for API testing
  await testApiConnection();

  runApp(const DevTaskManagerApp());
}

class DevTaskManagerApp extends StatelessWidget {
  const DevTaskManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc()..add(CheckAuthStatus()),
      child: const MyApp(),
    );
  }
}