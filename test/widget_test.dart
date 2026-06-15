import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:budget_splitter/main.dart';
import 'package:budget_splitter/models/group.dart';
import 'package:budget_splitter/models/member.dart';
import 'package:budget_splitter/models/expense.dart';
import 'package:budget_splitter/controllers/budget_controller.dart';
import 'package:budget_splitter/services/storage_service.dart';

class FakeStorageService implements StorageService {
  @override
  Future<void> init() async {}
  @override
  List<Group> getGroups() => [];
  @override
  Future<void> saveGroup(Group group) async {}
  @override
  Future<void> deleteGroup(String groupId) async {}
  @override
  List<Member> getMembers() => [];
  @override
  Future<void> saveMember(Member member) async {}
  @override
  Future<void> deleteMember(String memberId) async {}
  @override
  List<Expense> getExpenses() => [];
  @override
  Future<void> saveExpense(Expense expense) async {}
  @override
  Future<void> deleteExpense(String expenseId) async {}
  @override
  Future<void> clearAll() async {}
}

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    final tempDir = Directory.systemTemp.createTempSync('widget_test_');
    Hive.init(tempDir.path);

    final storage = FakeStorageService();
    final controller = BudgetController(storage);
    await controller.init();

    await tester.pumpWidget(BudgetSplitterApp(controller: controller));

    // Verify home screen elements render
    expect(find.text("Welcome back,"), findsOneWidget);
    expect(find.text("TOTAL NET BALANCE"), findsOneWidget);

    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });
}