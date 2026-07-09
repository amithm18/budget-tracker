import 'package:flutter_test/flutter_test.dart';
import 'package:budget_splitter/main.dart';
import 'package:budget_splitter/models/group.dart';
import 'package:budget_splitter/models/member.dart';
import 'package:budget_splitter/models/expense.dart';
import 'package:budget_splitter/controllers/budget_controller.dart';
import 'package:budget_splitter/services/storage_service.dart';

class FakeStorageService implements StorageService {
  String currentUserName = 'Amith';
  String currency = '₹';

  @override
  Future<void> init() async {}
  
  @override
  String getCurrentUserName() => currentUserName;

  @override
  Future<void> setCurrentUserName(String name) async {
    currentUserName = name;
  }

  @override
  String getCurrency() => currency;

  @override
  Future<void> setCurrency(String symbol) async {
    currency = symbol;
  }

  @override
  Future<List<Group>> getGroups() async => [];
  @override
  Future<void> saveGroup(Group group) async {}
  @override
  Future<void> deleteGroup(String groupId) async {}
  @override
  Future<List<Member>> getMembers() async => [];
  @override
  Future<void> saveMember(Member member) async {}
  @override
  Future<void> deleteMember(String memberId) async {}
  @override
  Future<List<Expense>> getExpenses() async => [];
  @override
  Future<void> saveExpense(Expense expense) async {}
  @override
  Future<void> deleteExpense(String expenseId) async {}
  @override
  Future<Group?> getGroupByCode(String groupCode) async => null;
  @override
  Future<List<Member>> getMembersOfGroup(String groupId) async => [];
  @override
  Future<void> clearAll() async {}
}

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    final storage = FakeStorageService();
    final controller = BudgetController(storage);
    await controller.init();

    await tester.pumpWidget(BudgetSplitterApp(controller: controller));

    // Verify home screen elements render
    expect(find.text("Welcome back,"), findsOneWidget);
    expect(find.text("TOTAL NET BALANCE"), findsOneWidget);
  });
}