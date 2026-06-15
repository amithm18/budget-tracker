import 'package:hive_flutter/hive_flutter.dart';
import '../models/group.dart';
import '../models/member.dart';
import '../models/expense.dart';

class StorageService {
  static const String _groupsBoxName = 'groups';
  static const String _membersBoxName = 'members';
  static const String _expensesBoxName = 'expenses';

  late Box _groupsBox;
  late Box _membersBox;
  late Box _expensesBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _groupsBox = await Hive.openBox(_groupsBoxName);
    _membersBox = await Hive.openBox(_membersBoxName);
    _expensesBox = await Hive.openBox(_expensesBoxName);
  }

  // --- Group Operations ---
  List<Group> getGroups() {
    return _groupsBox.values
        .map((val) => Group.fromMap(Map<dynamic, dynamic>.from(val as Map)))
        .toList();
  }

  Future<void> saveGroup(Group group) async {
    await _groupsBox.put(group.id, group.toMap());
  }

  Future<void> deleteGroup(String groupId) async {
    await _groupsBox.delete(groupId);
    // Also clean up members and expenses associated with this group
    final membersToDelete = getMembers().where((m) => m.groupId == groupId).map((m) => m.id);
    for (var id in membersToDelete) {
      await deleteMember(id);
    }
    final expensesToDelete = getExpenses().where((e) => e.groupId == groupId).map((e) => e.id);
    for (var id in expensesToDelete) {
      await deleteExpense(id);
    }
  }

  // --- Member Operations ---
  List<Member> getMembers() {
    return _membersBox.values
        .map((val) => Member.fromMap(Map<dynamic, dynamic>.from(val as Map)))
        .toList();
  }

  Future<void> saveMember(Member member) async {
    await _membersBox.put(member.id, member.toMap());
  }

  Future<void> deleteMember(String memberId) async {
    await _membersBox.delete(memberId);
  }

  // --- Expense Operations ---
  List<Expense> getExpenses() {
    return _expensesBox.values
        .map((val) => Expense.fromMap(Map<dynamic, dynamic>.from(val as Map)))
        .toList();
  }

  Future<void> saveExpense(Expense expense) async {
    await _expensesBox.put(expense.id, expense.toMap());
  }

  Future<void> deleteExpense(String expenseId) async {
    await _expensesBox.delete(expenseId);
  }

  // Clear all data (useful for testing or reset)
  Future<void> clearAll() async {
    await _groupsBox.clear();
    await _membersBox.clear();
    await _expensesBox.clear();
  }
}
