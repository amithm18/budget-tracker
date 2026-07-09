import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/group.dart';
import '../models/member.dart';
import '../models/expense.dart';
import '../services/storage_service.dart';

class MemberBalance {
  final String memberId;
  final String name;
  final double netBalance; // Positive: owed money, Negative: owes money
  final double totalPaid;
  final double totalSpent;

  MemberBalance({
    required this.memberId,
    required this.name,
    required this.netBalance,
    required this.totalPaid,
    required this.totalSpent,
  });
}

class Transaction {
  final String fromMemberId;
  final String fromMemberName;
  final String toMemberId;
  final String toMemberName;
  final double amount;

  Transaction({
    required this.fromMemberId,
    required this.fromMemberName,
    required this.toMemberId,
    required this.toMemberName,
    required this.amount,
  });
}

class BudgetController extends ChangeNotifier {
  final StorageService _storageService;
  final _uuid = const Uuid();

  List<Group> _groups = [];
  List<Member> _members = [];
  List<Expense> _expenses = [];
  String _currentUserName = ''; // Default user name
  String _currency = '₹'; // Default currency symbol

  BudgetController(this._storageService);

  // --- Getters ---
  List<Group> get groups => _groups;
  List<Member> get members => _members;
  List<Expense> get expenses => _expenses;
  String get currentUserName => _currentUserName;
  String get currency => _currency;

  // --- Initialization ---
  Future<void> init() async {
    _groups = List<Group>.from(await _storageService.getGroups());
    _members = List<Member>.from(await _storageService.getMembers());
    _expenses = List<Expense>.from(await _storageService.getExpenses());

    // Load custom username and currency if stored in settings
    _currentUserName = _storageService.getCurrentUserName();
    _currency = _storageService.getCurrency();

    // Reconstruct list references dynamically for RDBMS normalization
    _relinkLocalData();

    // Sort groups by creation date descending
    _groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  void _relinkLocalData() {
    for (var i = 0; i < _groups.length; i++) {
      final g = _groups[i];
      final gMembers = _members.where((m) => m.groupId == g.id).map((m) => m.id).toList();
      final gExpenses = _expenses.where((e) => e.groupId == g.id).map((e) => e.id).toList();
      _groups[i] = Group(
        id: g.id,
        name: g.name,
        createdAt: g.createdAt,
        dueDate: g.dueDate,
        memberIds: gMembers,
        expenseIds: gExpenses,
      );
    }
  }

  Future<void> refreshData() async {
    await init();
  }

  // --- Profile Operations ---
  Future<void> updateCurrentUserName(String name) async {
    _currentUserName = name.trim();
    await _storageService.setCurrentUserName(_currentUserName);
    await refreshData();
  }

  Future<void> updateCurrency(String symbol) async {
    _currency = symbol;
    await _storageService.setCurrency(symbol);
    notifyListeners();
  }

  // --- Read helpers ---
  List<Member> getMembersForGroup(String groupId) {
    return _members.where((m) => m.groupId == groupId).toList();
  }

  List<Expense> getExpensesForGroup(String groupId) {
    final groupExpenses = _expenses.where((e) => e.groupId == groupId).toList();
    groupExpenses.sort((a, b) => b.date.compareTo(a.date)); // newest first
    return groupExpenses;
  }

  Group? getGroupById(String groupId) {
    try {
      return _groups.firstWhere((g) => g.id == groupId);
    } catch (_) {
      return null;
    }
  }

  Member? getMemberById(String memberId) {
    try {
      return _members.firstWhere((m) => m.id == memberId);
    } catch (_) {
      return null;
    }
  }

  // --- Write Operations ---

  /// Creates a group and its initial members in Supabase
  Future<Group> createGroup(String name, List<String> memberNames, {DateTime? dueDate}) async {
    final groupId = _uuid.v4();
    final now = DateTime.now();

    // 1. Create and save group first so it exists in PostgreSQL
    final newGroup = Group(
      id: groupId,
      name: name.trim(),
      memberIds: [], // resolved dynamically from members table
      expenseIds: [], // resolved dynamically from expenses table
      createdAt: now,
      dueDate: dueDate,
    );
    await _storageService.saveGroup(newGroup);

    // 2. Create and save members afterward (satisfying the foreign key constraint)
    for (var mName in memberNames) {
      if (mName.trim().isEmpty) continue;
      final memberId = _uuid.v4();
      final newMember = Member(
        id: memberId,
        name: mName.trim(),
        groupId: groupId,
      );
      await _storageService.saveMember(newMember);
    }

    await refreshData();
    return newGroup;
  }

  /// Adds a member to an existing group in Supabase
  Future<void> addMemberToGroup(String groupId, String name) async {
    if (name.trim().isEmpty) return;

    final memberId = _uuid.v4();
    final newMember = Member(
      id: memberId,
      name: name.trim(),
      groupId: groupId,
    );

    await _storageService.saveMember(newMember);
    await refreshData();
  }

  /// Updates a member's UPI ID
  Future<void> updateMemberUpiId(String memberId, String upiId) async {
    final member = getMemberById(memberId);
    if (member == null) return;

    final updatedMember = Member(
      id: member.id,
      name: member.name,
      groupId: member.groupId,
      upiId: upiId.trim().isEmpty ? null : upiId.trim(),
    );

    await _storageService.saveMember(updatedMember);
    await refreshData();
  }

  /// Adds an expense to a group and updates the group references
  Future<void> addExpenseToGroup({
    required String groupId,
    required String title,
    required double amount,
    required String paidByMemberId,
    required List<String> participantIds,
  }) async {
    if (amount <= 0 || title.trim().isEmpty) return;

    final expenseId = _uuid.v4();
    final newExpense = Expense(
      id: expenseId,
      title: title.trim(),
      amount: amount,
      paidByMemberId: paidByMemberId,
      participantIds: participantIds,
      groupId: groupId,
      date: DateTime.now(),
    );

    await _storageService.saveExpense(newExpense);
    await refreshData();
  }

  /// Updates an existing expense in Supabase and refreshes data
  Future<void> updateExpense({
    required String expenseId,
    required String groupId,
    required String title,
    required double amount,
    required String paidByMemberId,
    required List<String> participantIds,
    required DateTime date,
  }) async {
    if (amount <= 0 || title.trim().isEmpty) return;

    final updatedExpense = Expense(
      id: expenseId,
      title: title.trim(),
      amount: amount,
      paidByMemberId: paidByMemberId,
      participantIds: participantIds,
      groupId: groupId,
      date: date,
    );

    await _storageService.saveExpense(updatedExpense);
    await refreshData();
  }

  /// Deletes a group and all its sub-records (via Postgres Cascade Deletes)
  Future<void> deleteGroup(String groupId) async {
    await _storageService.deleteGroup(groupId);
    await refreshData();
  }

  /// Deletes an individual expense from a group
  Future<void> deleteExpense(String expenseId) async {
    await _storageService.deleteExpense(expenseId);
    await refreshData();
  }

  /// Connects current user to an existing group using its code (prefix of UUID)
  Future<bool> joinGroup(String groupCode) async {
    if (groupCode.trim().isEmpty) return false;
    final code = groupCode.trim().toLowerCase();

    try {
      final targetGroup = await _storageService.getGroupByCode(code);
      if (targetGroup == null) {
        return false;
      }

      // Check if current user is already in this group
      final groupMembers = await _storageService.getMembersOfGroup(targetGroup.id);

      final isAlreadyMember = groupMembers.any(
        (m) => m.name.trim().toLowerCase() == _currentUserName.trim().toLowerCase(),
      );

      if (!isAlreadyMember) {
        final memberId = _uuid.v4();
        final newMember = Member(
          id: memberId,
          name: _currentUserName.trim(),
          groupId: targetGroup.id,
        );
        await _storageService.saveMember(newMember);
      }

      await refreshData();
      return true;
    } catch (e) {
      debugPrint("Error joining group: $e");
      return false;
    }
  }

  // --- Split Calculations ---

  /// Calculates net balances for all members of a group
  List<MemberBalance> getGroupBalances(String groupId) {
    final groupMembers = getMembersForGroup(groupId);
    final groupExpenses = getExpensesForGroup(groupId);

    final Map<String, double> paid = {for (var m in groupMembers) m.id: 0.0};
    final Map<String, double> spent = {for (var m in groupMembers) m.id: 0.0};

    for (var expense in groupExpenses) {
      // Add paid amount to payer
      if (paid.containsKey(expense.paidByMemberId)) {
        paid[expense.paidByMemberId] = paid[expense.paidByMemberId]! + expense.amount;
      }

      // Distribute share to participants
      final participantsCount = expense.participantIds.length;
      if (participantsCount > 0) {
        final share = expense.amount / participantsCount;
        for (var partId in expense.participantIds) {
          if (spent.containsKey(partId)) {
            spent[partId] = spent[partId]! + share;
          }
        }
      }
    }

    return groupMembers.map((m) {
      final totalPaid = paid[m.id] ?? 0.0;
      final totalSpent = spent[m.id] ?? 0.0;
      return MemberBalance(
        memberId: m.id,
        name: m.name,
        netBalance: totalPaid - totalSpent,
        totalPaid: totalPaid,
        totalSpent: totalSpent,
      );
    }).toList();
  }

  /// Optimizes settlements to minimize total transactions
  List<Transaction> getGroupSettlements(String groupId) {
    final balances = getGroupBalances(groupId);

    // Filter non-zero balances
    // Use a small epsilon for floating-point comparisons
    const epsilon = 0.01;

    final List<MapEntry<MemberBalance, double>> debtors = [];
    final List<MapEntry<MemberBalance, double>> creditors = [];

    for (var bal in balances) {
      if (bal.netBalance < -epsilon) {
        debtors.add(MapEntry(bal, bal.netBalance));
      } else if (bal.netBalance > epsilon) {
        creditors.add(MapEntry(bal, bal.netBalance));
      }
    }

    // Sort: Debtors ascending (most negative first), Creditors descending (most positive first)
    debtors.sort((a, b) => a.value.compareTo(b.value));
    creditors.sort((a, b) => b.value.compareTo(a.value));

    final List<Transaction> transactions = [];

    int dIdx = 0;
    int cIdx = 0;

    // Work on local copies of values to balance them
    final List<double> dVals = debtors.map((e) => e.value).toList();
    final List<double> cVals = creditors.map((e) => e.value).toList();

    while (dIdx < dVals.length && cIdx < cVals.length) {
      final debtorVal = dVals[dIdx];
      final creditorVal = cVals[cIdx];

      final debtorBal = debtors[dIdx].key;
      final creditorBal = creditors[cIdx].key;

      final double amountToSettle = (-debtorVal < creditorVal) ? -debtorVal : creditorVal;

      if (amountToSettle > epsilon) {
        transactions.add(Transaction(
          fromMemberId: debtorBal.memberId,
          fromMemberName: debtorBal.name,
          toMemberId: creditorBal.memberId,
          toMemberName: creditorBal.name,
          amount: amountToSettle,
        ));
      }

      dVals[dIdx] += amountToSettle;
      cVals[cIdx] -= amountToSettle;

      if (dVals[dIdx].abs() < epsilon) {
        dIdx++;
      }
      if (cVals[cIdx].abs() < epsilon) {
        cIdx++;
      }
    }

    return transactions;
  }

  /// Calculates the overall stats for the current user across all groups
  /// Returns a Map with keys: 'owe', 'owed', 'net'
  Map<String, double> getOverallStats() {
    double totalYouOwe = 0.0;
    double totalYouAreOwed = 0.0;

    for (var group in _groups) {
      // Find if user is in this group
      final groupMembers = getMembersForGroup(group.id);
      final userMember = groupMembers.firstWhere(
        (m) => m.name.trim().toLowerCase() == _currentUserName.trim().toLowerCase(),
        orElse: () => Member(id: '', name: '', groupId: ''),
      );

      if (userMember.id.isEmpty) continue; // Not in this group

      // Calculate settlements for this group
      final settlements = getGroupSettlements(group.id);

      for (var tx in settlements) {
        if (tx.fromMemberId == userMember.id) {
          totalYouOwe += tx.amount;
        } else if (tx.toMemberId == userMember.id) {
          totalYouAreOwed += tx.amount;
        }
      }
    }

    return {
      'owe': totalYouOwe,
      'owed': totalYouAreOwed,
      'net': totalYouAreOwed - totalYouOwe,
    };
  }

  // --- Reset database for debug ---
  Future<void> resetData() async {
    await _storageService.clearAll();
    _groups.clear();
    _members.clear();
    _expenses.clear();
    notifyListeners();
  }
}
