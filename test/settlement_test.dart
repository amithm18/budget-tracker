import 'package:flutter_test/flutter_test.dart';
import 'package:budget_splitter/models/group.dart';
import 'package:budget_splitter/models/member.dart';
import 'package:budget_splitter/models/expense.dart';
import 'package:budget_splitter/services/storage_service.dart';
import 'package:budget_splitter/controllers/budget_controller.dart';

// A mock in-memory storage service to test the controller without Hive dependencies
class FakeStorageService implements StorageService {
  final List<Group> groups = [];
  final List<Member> members = [];
  final List<Expense> expenses = [];

  String currentUserName = 'Amith';

  @override
  Future<void> init() async {}

  @override
  String getCurrentUserName() => currentUserName;

  @override
  Future<void> setCurrentUserName(String name) async {
    currentUserName = name;
  }

  @override
  List<Group> getGroups() => groups;

  @override
  Future<void> saveGroup(Group group) async {
    groups.removeWhere((g) => g.id == group.id);
    groups.add(group);
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    groups.removeWhere((g) => g.id == groupId);
  }

  @override
  List<Member> getMembers() => members;

  @override
  Future<void> saveMember(Member member) async {
    members.removeWhere((m) => m.id == member.id);
    members.add(member);
  }

  @override
  Future<void> deleteMember(String memberId) async {
    members.removeWhere((m) => m.id == memberId);
  }

  @override
  List<Expense> getExpenses() => expenses;

  @override
  Future<void> saveExpense(Expense expense) async {
    expenses.removeWhere((e) => e.id == expense.id);
    expenses.add(expense);
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    expenses.removeWhere((e) => e.id == expenseId);
  }

  @override
  Future<void> clearAll() async {
    groups.clear();
    members.clear();
    expenses.clear();
  }
}

void main() {
  group('Budget Splitter & Settlement Tests', () {
    late FakeStorageService storageService;
    late BudgetController controller;
    setUp(() async {
      storageService = FakeStorageService();
      controller = BudgetController(storageService);
      await controller.init();
    });

    test('Should calculate correct equal splits and optimize settlements', () async {
      // 1. Create a group "Holiday Trip" with members Amith, Bob, Charlie
      final group = await controller.createGroup(
        "Holiday Trip",
        ["Amith", "Bob", "Charlie"],
      );

      final members = controller.getMembersForGroup(group.id);
      expect(members.length, 3);

      final amith = members.firstWhere((m) => m.name == "Amith");
      final bob = members.firstWhere((m) => m.name == "Bob");
      final charlie = members.firstWhere((m) => m.name == "Charlie");

      // Set the active user profile name
      await controller.updateCurrentUserName("Amith");

      // 2. Add an expense of ₹90, paid by Amith, split among all 3
      await controller.addExpenseToGroup(
        groupId: group.id,
        title: "Dinner bill",
        amount: 90.00,
        paidByMemberId: amith.id,
        participantIds: [amith.id, bob.id, charlie.id],
      );

      // Verify individual balances
      // Amith paid 90, spent 30 -> Net is +60
      // Bob paid 0, spent 30 -> Net is -30
      // Charlie paid 0, spent 30 -> Net is -30
      var balances = controller.getGroupBalances(group.id);
      
      final amithBal1 = balances.firstWhere((b) => b.memberId == amith.id);
      final bobBal1 = balances.firstWhere((b) => b.memberId == bob.id);
      final charlieBal1 = balances.firstWhere((b) => b.memberId == charlie.id);

      expect(amithBal1.netBalance, closeTo(60.0, 0.01));
      expect(bobBal1.netBalance, closeTo(-30.0, 0.01));
      expect(charlieBal1.netBalance, closeTo(-30.0, 0.01));

      // Verify settlements
      // Bob owes Amith 30, Charlie owes Amith 30
      var settlements = controller.getGroupSettlements(group.id);
      expect(settlements.length, 2);
      
      expect(settlements.any((s) => s.fromMemberName == "Bob" && s.toMemberName == "Amith" && s.amount == 30.0), true);
      expect(settlements.any((s) => s.fromMemberName == "Charlie" && s.toMemberName == "Amith" && s.amount == 30.0), true);

      // 3. Add a second expense of ₹30, paid by Bob, split among all 3
      await controller.addExpenseToGroup(
        groupId: group.id,
        title: "Taxi ride",
        amount: 30.00,
        paidByMemberId: bob.id,
        participantIds: [amith.id, bob.id, charlie.id],
      );

      // Recalculate balances:
      // Amith: paid 90, spent 30 (Dinner) + 10 (Taxi) = 40. Net = +50.
      // Bob: paid 30, spent 30 (Dinner) + 10 (Taxi) = 40. Net = -10.
      // Charlie: paid 0, spent 30 (Dinner) + 10 (Taxi) = 40. Net = -40.
      balances = controller.getGroupBalances(group.id);
      
      final amithBal2 = balances.firstWhere((b) => b.memberId == amith.id);
      final bobBal2 = balances.firstWhere((b) => b.memberId == bob.id);
      final charlieBal2 = balances.firstWhere((b) => b.memberId == charlie.id);

      expect(amithBal2.netBalance, closeTo(50.0, 0.01));
      expect(bobBal2.netBalance, closeTo(-10.0, 0.01));
      expect(charlieBal2.netBalance, closeTo(-40.0, 0.01));

      // Verify optimized settlements
      // Transactions should be minimized:
      // - Bob owes Amith ₹10
      // - Charlie owes Amith ₹40
      // Total transactions = 2 (instead of Bob paying Amith 30, Charlie paying Amith 30, Amith paying Bob 10)
      settlements = controller.getGroupSettlements(group.id);
      expect(settlements.length, 2);
      
      expect(settlements.any((s) => s.fromMemberName == "Bob" && s.toMemberName == "Amith" && s.amount == 10.0), true);
      expect(settlements.any((s) => s.fromMemberName == "Charlie" && s.toMemberName == "Amith" && s.amount == 40.0), true);

      // 4. Settle Bob's debt to Amith (₹10 payment from Bob to Amith)
      final bobToAmithTx = settlements.firstWhere((s) => s.fromMemberName == "Bob" && s.toMemberName == "Amith");
      
      await controller.addExpenseToGroup(
        groupId: group.id,
        title: "Settle: Bob to Amith",
        amount: bobToAmithTx.amount,
        paidByMemberId: bobToAmithTx.fromMemberId,
        participantIds: [bobToAmithTx.toMemberId], // only Amith participates, so Amith gets the value
      );

      // Recalculate balances:
      // Amith: previous net = 50. Paid 90, spent 40 (Dinner/Taxi) + 10 (Settlement spent) = 50. Net = +40.
      // Bob: previous net = -10. Paid 30 (Taxi) + 10 (Settlement paid) = 40, spent 40. Net = 0.
      // Charlie: Net remains -40.
      balances = controller.getGroupBalances(group.id);
      
      final amithBal3 = balances.firstWhere((b) => b.memberId == amith.id);
      final bobBal3 = balances.firstWhere((b) => b.memberId == bob.id);
      final charlieBal3 = balances.firstWhere((b) => b.memberId == charlie.id);

      expect(bobBal3.netBalance, closeTo(0.0, 0.01));
      expect(amithBal3.netBalance, closeTo(40.0, 0.01));
      expect(charlieBal3.netBalance, closeTo(-40.0, 0.01));

      // Only 1 settlement remaining: Charlie owes Amith 40
      settlements = controller.getGroupSettlements(group.id);
      expect(settlements.length, 1);
      expect(settlements.first.fromMemberName, "Charlie");
      expect(settlements.first.toMemberName, "Amith");
      expect(settlements.first.amount, closeTo(40.0, 0.01));
    });
  });
}
