import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/group.dart';
import '../models/member.dart';
import '../models/expense.dart';
import '../models/chat_message.dart';
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
  List<ChatMessage> _messages = [];
  String _currentUserName = ''; // Default user name
  String _currency = '₹'; // Default currency symbol

  final List<String> cosmicRoasts = [
    "Your debt is older than the universe. Settle up or get sucked into the event horizon!",
    "A light-year is a unit of distance, not the speed at which you pay back your friends. Settle up!",
    "Einstein proved time is relative, but your payback time is entering absolute zero. Settle up!",
    "My scanners indicate your wallet has entered a localized gravity well where money cannot escape.",
    "The expansion of the universe is faster than the speed of your payments.",
    "Houston, we have a problem. Someone forgot to pay back their space crew.",
    "Black holes consume everything, including the memory of your debt. Settle up before the collapse!",
  ];

  BudgetController(this._storageService);

  // --- Getters ---
  List<Group> get groups => _groups;
  List<Member> get members => _members;
  List<Expense> get expenses => _expenses;
  List<ChatMessage> get messages => _messages;
  String get currentUserName => _currentUserName;
  String get currency => _currency;

  // --- Initialization ---
  Future<void> init() async {
    _groups = List<Group>.from(_storageService.getGroups());
    _members = List<Member>.from(_storageService.getMembers());
    _expenses = List<Expense>.from(_storageService.getExpenses());
    _messages = List<ChatMessage>.from(_storageService.getMessages());

    // Load custom username and currency if stored in settings
    _currentUserName = _storageService.getCurrentUserName();
    _currency = _storageService.getCurrency();

    // Sort groups by creation date descending
    _groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  // --- Profile Operations ---
  Future<void> updateCurrentUserName(String name) async {
    _currentUserName = name.trim();
    await _storageService.setCurrentUserName(_currentUserName);
    notifyListeners();
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

  List<ChatMessage> getMessagesForGroup(String groupId) {
    final groupMessages = _messages.where((m) => m.groupId == groupId).toList();
    groupMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp)); // oldest first (chat sequence)
    return groupMessages;
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

  String getRandomCosmicRoast() {
    final random = DateTime.now().millisecond;
    return cosmicRoasts[random % cosmicRoasts.length];
  }

  // --- Write Operations ---

  /// Creates a group and its initial members
  Future<Group> createGroup(String name, List<String> memberNames, {DateTime? dueDate, String? imageUrl}) async {
    final groupId = _uuid.v4();
    final now = DateTime.now();

    final List<String> memberIds = [];

    // Create and save members
    for (var mName in memberNames) {
      if (mName.trim().isEmpty) continue;
      final memberId = _uuid.v4();
      final newMember = Member(
        id: memberId,
        name: mName.trim(),
        groupId: groupId,
      );
      await _storageService.saveMember(newMember);
      _members.add(newMember);
      memberIds.add(memberId);
    }

    // Create and save group
    final newGroup = Group(
      id: groupId,
      name: name.trim(),
      memberIds: memberIds,
      expenseIds: [],
      createdAt: now,
      dueDate: dueDate,
      imageUrl: imageUrl,
    );

    await _storageService.saveGroup(newGroup);
    _groups.insert(0, newGroup); // insert at start
    notifyListeners();
    return newGroup;
  }

  /// Adds a member to an existing group
  Future<void> addMemberToGroup(String groupId, String name) async {
    final group = getGroupById(groupId);
    if (group == null || name.trim().isEmpty) return;

    final memberId = _uuid.v4();
    final newMember = Member(
      id: memberId,
      name: name.trim(),
      groupId: groupId,
    );

    await _storageService.saveMember(newMember);
    _members.add(newMember);

    // Update group's member references
    final updatedMemberIds = List<String>.from(group.memberIds)..add(memberId);
    final updatedGroup = Group(
      id: group.id,
      name: group.name,
      memberIds: updatedMemberIds,
      expenseIds: group.expenseIds,
      createdAt: group.createdAt,
      dueDate: group.dueDate,
      imageUrl: group.imageUrl,
    );

    await _storageService.saveGroup(updatedGroup);
    final index = _groups.indexWhere((g) => g.id == groupId);
    if (index != -1) {
      _groups[index] = updatedGroup;
    }

    notifyListeners();
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
    final index = _members.indexWhere((m) => m.id == memberId);
    if (index != -1) {
      _members[index] = updatedMember;
    }
    notifyListeners();
  }

  /// Adds an expense to a group and updates the group references
  Future<void> addExpenseToGroup({
    required String groupId,
    required String title,
    required double amount,
    required String paidByMemberId,
    required List<String> participantIds,
    Map<String, double>? customAmounts,
  }) async {
    final group = getGroupById(groupId);
    if (group == null || amount <= 0 || title.trim().isEmpty) return;

    final expenseId = _uuid.v4();
    final newExpense = Expense(
      id: expenseId,
      title: title.trim(),
      amount: amount,
      paidByMemberId: paidByMemberId,
      participantIds: participantIds,
      groupId: groupId,
      date: DateTime.now(),
      customAmounts: customAmounts,
    );

    await _storageService.saveExpense(newExpense);
    _expenses.add(newExpense);

    // Update group's expense references
    final updatedExpenseIds = List<String>.from(group.expenseIds)..add(expenseId);
    final updatedGroup = Group(
      id: group.id,
      name: group.name,
      memberIds: group.memberIds,
      expenseIds: updatedExpenseIds,
      createdAt: group.createdAt,
      dueDate: group.dueDate,
      imageUrl: group.imageUrl,
    );

    await _storageService.saveGroup(updatedGroup);
    final index = _groups.indexWhere((g) => g.id == groupId);
    if (index != -1) {
      _groups[index] = updatedGroup;
    }

    notifyListeners();
  }

  /// Deletes a group and all its sub-records
  Future<void> deleteGroup(String groupId) async {
    await _storageService.deleteGroup(groupId);
    _groups.removeWhere((g) => g.id == groupId);
    _members.removeWhere((m) => m.groupId == groupId);
    _expenses.removeWhere((e) => e.groupId == groupId);
    _messages.removeWhere((m) => m.groupId == groupId);
    notifyListeners();
  }

  /// Deletes an individual expense from a group
  Future<void> deleteExpense(String expenseId) async {
    final expenseIndex = _expenses.indexWhere((e) => e.id == expenseId);
    if (expenseIndex == -1) return;

    final expense = _expenses[expenseIndex];
    final group = getGroupById(expense.groupId);

    await _storageService.deleteExpense(expenseId);
    _expenses.removeAt(expenseIndex);

    if (group != null) {
      final updatedExpenseIds = List<String>.from(group.expenseIds)..remove(expenseId);
      final updatedGroup = Group(
        id: group.id,
        name: group.name,
        memberIds: group.memberIds,
        expenseIds: updatedExpenseIds,
        createdAt: group.createdAt,
        dueDate: group.dueDate,
        imageUrl: group.imageUrl,
      );

      await _storageService.saveGroup(updatedGroup);
      final index = _groups.indexWhere((g) => g.id == group.id);
      if (index != -1) {
        _groups[index] = updatedGroup;
      }
    }

    notifyListeners();
  }

  // --- Message Operations ---
  Future<void> sendChatMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String content,
    required String messageType,
  }) async {
    final messageId = _uuid.v4();
    final newMessage = ChatMessage(
      id: messageId,
      groupId: groupId,
      senderId: senderId,
      senderName: senderName,
      messageType: messageType,
      content: content,
      timestamp: DateTime.now(),
    );

    await _storageService.saveMessage(newMessage);
    _messages.add(newMessage);
    notifyListeners();
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
      final hasCustomAmounts = expense.customAmounts != null && expense.customAmounts!.isNotEmpty;
      if (hasCustomAmounts) {
        expense.customAmounts!.forEach((partId, customAmt) {
          if (spent.containsKey(partId)) {
            spent[partId] = spent[partId]! + customAmt;
          }
        });
      } else {
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
    _messages.clear();
    notifyListeners();
  }
}
