import 'package:hive_flutter/hive_flutter.dart';
import '../models/group.dart';
import '../models/member.dart';
import '../models/expense.dart';
import '../models/chat_message.dart';

class StorageService {
  static const String _groupsBoxName = 'groups';
  static const String _membersBoxName = 'members';
  static const String _expensesBoxName = 'expenses';
  static const String _messagesBoxName = 'messages';

  late Box _groupsBox;
  late Box _membersBox;
  late Box _expensesBox;
  late Box _messagesBox;
  late Box _settingsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _groupsBox = await Hive.openBox(_groupsBoxName);
    _membersBox = await Hive.openBox(_membersBoxName);
    _expensesBox = await Hive.openBox(_expensesBoxName);
    _messagesBox = await Hive.openBox(_messagesBoxName);
    _settingsBox = await Hive.openBox('settings');
  }

  String getCurrentUserName() {
    return _settingsBox.get('currentUserName', defaultValue: '') as String;
  }

  Future<void> setCurrentUserName(String name) async {
    await _settingsBox.put('currentUserName', name);
  }

  String getCurrency() {
    return _settingsBox.get('currency', defaultValue: '₹') as String;
  }

  Future<void> setCurrency(String symbol) async {
    await _settingsBox.put('currency', symbol);
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
    // Also clean up members, expenses, and messages associated with this group
    final membersToDelete = getMembers().where((m) => m.groupId == groupId).map((m) => m.id);
    for (var id in membersToDelete) {
      await deleteMember(id);
    }
    final expensesToDelete = getExpenses().where((e) => e.groupId == groupId).map((e) => e.id);
    for (var id in expensesToDelete) {
      await deleteExpense(id);
    }
    await deleteMessagesForGroup(groupId);
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

  // --- Message Operations ---
  List<ChatMessage> getMessages() {
    return _messagesBox.values
        .map((val) => ChatMessage.fromMap(Map<dynamic, dynamic>.from(val as Map)))
        .toList();
  }

  Future<void> saveMessage(ChatMessage message) async {
    await _messagesBox.put(message.id, message.toMap());
  }

  Future<void> deleteMessagesForGroup(String groupId) async {
    final toDelete = getMessages().where((m) => m.groupId == groupId).map((m) => m.id);
    for (var id in toDelete) {
      await _messagesBox.delete(id);
    }
  }

  // Clear all data (useful for testing or reset)
  Future<void> clearAll() async {
    await _groupsBox.clear();
    await _membersBox.clear();
    await _expensesBox.clear();
    await _messagesBox.clear();
    await _settingsBox.clear();
  }
}
