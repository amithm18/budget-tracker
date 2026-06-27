import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'controllers/budget_controller.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive and services
  final storageService = StorageService();
  await storageService.init();
  
  final budgetController = BudgetController(storageService);
  await budgetController.init();

  runApp(BudgetSplitterApp(controller: budgetController));
}

class BudgetSplitterApp extends StatelessWidget {
  final BudgetController controller;

  const BudgetSplitterApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Budget Splitter for Groups',
      theme: AppTheme.darkTheme,
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.currentUserName.isEmpty) {
            return WelcomeScreen(controller: controller);
          }
          return HomeScreen(controller: controller);
        },
      ),
    );
  }
}