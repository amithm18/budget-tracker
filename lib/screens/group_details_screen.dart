import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/budget_controller.dart';
import '../models/member.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../theme/app_theme.dart';
import '../widgets/antigravity_background.dart';
import '../widgets/analytics_pie_chart.dart';
import 'add_expense_screen.dart';

class GroupDetailsScreen extends StatefulWidget {
  final BudgetController controller;
  final String groupId;

  const GroupDetailsScreen({
    super.key,
    required this.controller,
    required this.groupId,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final _newMemberController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  bool _isSpinning = false;
  int _rouletteSelectedIndex = -1;

  Widget _getCategoryAvatar(String title) {
    final t = title.toLowerCase();
    String emoji = "💰";
    Color startColor = const Color(0xFF6B7280);
    Color endColor = const Color(0xFF4B5563);

    if (t.contains("settle")) {
      emoji = "🤝";
      startColor = const Color(0xFF10B981);
      endColor = const Color(0xFF059669);
    } else if (t.contains("food") || t.contains("lunch") || t.contains("dinner") || t.contains("cafe") || t.contains("restaurant") || t.contains("drink") || t.contains("starbucks") || t.contains("eat") || t.contains("biryani")) {
      emoji = "🍔";
      startColor = const Color(0xFFF59E0B);
      endColor = const Color(0xFFD97706);
    } else if (t.contains("fuel") || t.contains("petrol") || t.contains("diesel") || t.contains("cab") || t.contains("uber") || t.contains("auto") || t.contains("travel") || t.contains("train") || t.contains("flight") || t.contains("trip")) {
      emoji = "🚗";
      startColor = const Color(0xFF3B82F6);
      endColor = const Color(0xFF1D4ED8);
    } else if (t.contains("rent") || t.contains("flat") || t.contains("room") || t.contains("electricity") || t.contains("bill") || t.contains("wifi") || t.contains("water") || t.contains("recharge")) {
      emoji = "🏠";
      startColor = const Color(0xFF8B5CF6);
      endColor = const Color(0xFF7C3AED);
    } else if (t.contains("movie") || t.contains("ticket") || t.contains("netflix") || t.contains("show") || t.contains("game") || t.contains("fun") || t.contains("multiplex")) {
      emoji = "🎬";
      startColor = const Color(0xFFEC4899);
      endColor = const Color(0xFFDB2777);
    } else if (t.contains("grocer") || t.contains("milk") || t.contains("supermarket") || t.contains("vegetable") || t.contains("mart")) {
      emoji = "🛒";
      startColor = const Color(0xFF10B981);
      endColor = const Color(0xFF047857);
    }

    return Container(
      height: 48,
      width: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: startColor.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 22),
      ),
    );
  }

  @override
  void dispose() {
    _newMemberController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _addMember() {
    final name = _newMemberController.text.trim();
    if (name.isEmpty) return;

    final members = widget.controller.getMembersForGroup(widget.groupId);
    if (members.any((m) => m.name.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Member already exists in this group!")),
      );
      return;
    }

    widget.controller.addMemberToGroup(widget.groupId, name);
    _newMemberController.clear();
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Added '$name' to group.")),
    );
  }

  void _showEditUpiDialog(Member member) {
    final textController = TextEditingController(text: member.upiId ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.bgSurface,
          title: Text("Set UPI ID for ${member.name}"),
          content: TextField(
            controller: textController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: "UPI ID / VPA",
              hintText: "e.g., name@okaxis, 9876543210@paytm",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final upi = textController.text.trim();
                await widget.controller.updateMemberUpiId(member.id, upi);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(upi.isEmpty 
                          ? "UPI ID cleared for ${member.name}." 
                          : "UPI ID updated to '$upi' for ${member.name}."),
                    ),
                  );
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _recordSettlement(Transaction tx) async {
    await widget.controller.addExpenseToGroup(
      groupId: widget.groupId,
      title: "Settle: ${tx.fromMemberName} to ${tx.toMemberName}",
      amount: tx.amount,
      paidByMemberId: tx.fromMemberId,
      participantIds: [tx.toMemberId],
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Recorded payment of ${widget.controller.currency}${tx.amount.toStringAsFixed(2)}",
          ),
        ),
      );
    }
  }

  void _showUpiQrModal(Transaction tx, String upiId) {
    final upiUrl = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(tx.toMemberName)}&am=${tx.amount.toStringAsFixed(2)}&cu=INR';
    final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(upiUrl)}';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.bgSurface,
          contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          title: Row(
            children: [
              const Icon(Icons.qr_code_scanner, color: AppTheme.primaryLight),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Pay ${tx.toMemberName}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Scan to pay ${widget.controller.currency}${tx.amount.toStringAsFixed(2)} to $upiId",
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.15),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    qrUrl,
                    height: 200,
                    width: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        width: 200,
                        color: Colors.white,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(
                          color: AppTheme.primary,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        width: 200,
                        color: Colors.white,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: AppTheme.accentRed, size: 36),
                            SizedBox(height: 8),
                            Text(
                              "Failed to load QR",
                              style: TextStyle(color: Colors.black54, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Use any UPI app (GPay, PhonePe, Paytm, BHIM) to scan the QR code.",
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
              child: const Text("Close"),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text("Mark as Paid"),
              onPressed: () async {
                Navigator.pop(context); // close QR dialog
                Navigator.pop(context); // close choice dialog if open
                await _recordSettlement(tx);
              },
            ),
          ],
        );
      },
    );
  }

  void _showSettleUpDialog(Transaction tx) {
    final receiver = widget.controller.getMemberById(tx.toMemberId);
    final hasUpi = receiver?.upiId != null && receiver!.upiId!.trim().isNotEmpty;

    if (!hasUpi) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: AppTheme.bgSurface,
            title: const Text("Record Settlement"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Would you like to record a cash payment of ${widget.controller.currency}${tx.amount.toStringAsFixed(2)} from ${tx.fromMemberName} to ${tx.toMemberName}?",
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppTheme.primaryLight, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Tip: Set a UPI ID for ${tx.toMemberName} in the Members tab to unlock direct scan-and-pay QR codes!",
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _recordSettlement(tx);
                },
                child: const Text("Confirm"),
              ),
            ],
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: AppTheme.bgSurface,
            title: const Text("Settle Expense"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Choose how you want to settle the payment of ${widget.controller.currency}${tx.amount.toStringAsFixed(2)} to ${tx.toMemberName}:",
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 20),
                
                InkWell(
                  onTap: () {
                    _showUpiQrModal(tx, receiver.upiId!);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primary.withOpacity(0.2), AppTheme.primary.withOpacity(0.05)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.primary, width: 1.2),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.qr_code, color: AppTheme.primaryLight, size: 30),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Scan & Pay via UPI",
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Generates a dynamic QR code",
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    await _recordSettlement(tx);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border, width: 1.2),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.money_off_csred_outlined, color: AppTheme.textSecondary, size: 30),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Record Cash Payment",
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Settle manually offline",
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                child: const Text("Cancel"),
              ),
            ],
          );
        },
      );
    }
  }

  void _confirmDeleteGroup(BuildContext context, Group group) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.bgSurface,
          title: const Text("Delete Group?"),
          content: Text(
            "Are you sure you want to delete '${group.name}'? This will permanently erase all members, expenses, and balances.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // pop screen back to home
                await widget.controller.deleteGroup(group.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Group '${group.name}' deleted successfully."),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final group = widget.controller.getGroupById(widget.groupId);
        if (group == null) {
          return const Scaffold(
            body: Center(
              child: Text("Group not found"),
            ),
          );
        }

        final members = widget.controller.getMembersForGroup(widget.groupId);
        final expenses = widget.controller.getExpensesForGroup(widget.groupId);
        final settlements = widget.controller.getGroupSettlements(widget.groupId);
        final balances = widget.controller.getGroupBalances(widget.groupId);

        return DefaultTabController(
          length: 5,
          child: Scaffold(
            appBar: AppBar(
              title: Text(group.name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.accentRed),
                  onPressed: () => _confirmDeleteGroup(context, group),
                  tooltip: "Delete Group",
                ),
              ],
              bottom: TabBar(
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: AppTheme.primary.withOpacity(0.12),
                ),
                indicatorPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                labelColor: AppTheme.primaryLight,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                tabs: const [
                  Tab(text: "Expenses"),
                  Tab(text: "Balances"),
                  Tab(text: "Analytics"),
                  Tab(text: "Members"),
                  Tab(text: "Roulette"),
                ],
              ),
            ),
            body: AntigravityBackground(
              child: Column(
                children: [
                  if (group.dueDate != null &&
                      DateTime.now().isAfter(group.dueDate!) &&
                      settlements.isNotEmpty)
                    _buildOverdueBanner(group),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // 1. Expenses Tab
                        _buildExpensesTab(expenses, members),

                        // 2. Balances Tab
                        _buildBalancesTab(balances, settlements),

                        // 3. Analytics Tab
                        _buildAnalyticsTab(expenses, members),

                        // 4. Members Tab
                        _buildMembersTab(members),

                        // 5. Roulette Tab
                        _buildRouletteTab(members),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            floatingActionButton: Builder(
              builder: (context) {
                return FloatingActionButton.extended(
                  onPressed: () {
                    if (members.length < 2) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Add at least 2 members before adding expenses!"),
                        ),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddExpenseScreen(
                          controller: widget.controller,
                          groupId: widget.groupId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text("Add Expense"),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // --- TAB BUILDERS ---

  String _getCategoryForExpense(String title) {
    final t = title.toLowerCase();
    if (t.startsWith("settle:")) return 'Settlements';
    if (t.contains("food") || t.contains("lunch") || t.contains("dinner") || t.contains("cafe") || t.contains("restaurant") || t.contains("drink") || t.contains("starbucks") || t.contains("eat") || t.contains("biryani")) {
      return 'Food';
    }
    if (t.contains("fuel") || t.contains("petrol") || t.contains("diesel") || t.contains("cab") || t.contains("uber") || t.contains("auto") || t.contains("travel") || t.contains("train") || t.contains("flight") || t.contains("trip")) {
      return 'Fuel/Travel';
    }
    if (t.contains("rent") || t.contains("flat") || t.contains("room") || t.contains("electricity") || t.contains("bill") || t.contains("wifi") || t.contains("water") || t.contains("recharge")) {
      return 'Bills/Rent';
    }
    if (t.contains("movie") || t.contains("ticket") || t.contains("netflix") || t.contains("show") || t.contains("game") || t.contains("fun") || t.contains("multiplex")) {
      return 'Entertainment';
    }
    if (t.contains("grocer") || t.contains("milk") || t.contains("supermarket") || t.contains("vegetable") || t.contains("mart")) {
      return 'Groceries';
    }
    return 'Other';
  }

  Widget _buildCategoryChip(String label, String? emoji, Color? color) {
    String? categoryValue;
    if (label == "Travel") {
      categoryValue = "Fuel/Travel";
    } else if (label == "Bills") {
      categoryValue = "Bills/Rent";
    } else if (label == "Fun") {
      categoryValue = "Entertainment";
    } else if (label != "All") {
      categoryValue = label;
    }

    final isSelected = _selectedCategory == categoryValue;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        avatar: emoji != null ? Text(emoji, style: const TextStyle(fontSize: 14)) : null,
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? categoryValue : null;
          });
        },
        selectedColor: color?.withOpacity(0.18) ?? AppTheme.primary.withOpacity(0.18),
        checkmarkColor: color ?? AppTheme.primaryLight,
        backgroundColor: AppTheme.bgSurface,
        labelStyle: TextStyle(
          color: isSelected ? (color ?? AppTheme.primaryLight) : AppTheme.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? (color ?? AppTheme.primary) : AppTheme.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: AppTheme.accentRed),
            const SizedBox(height: 16),
            const Text(
              "No matching expenses found",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              "Try adjusting your keywords or category filters.",
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _selectedCategory = null;
                  _searchController.clear();
                });
              },
              child: const Text("Clear Filters"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesTab(List<Expense> expenses, List<Member> members) {
    if (expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text(
              "No expenses added yet",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              "Tap 'Add Expense' below to log group spending.",
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    final filteredExpenses = expenses.where((expense) {
      final matchesSearch = expense.title.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == null || 
          _getCategoryForExpense(expense.title) == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border, width: 1.2),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: "Search expenses...",
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryLight),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),

        // Category filter chips
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            children: [
              _buildCategoryChip("All", null, null),
              _buildCategoryChip("Food", "🍔", const Color(0xFFF59E0B)),
              _buildCategoryChip("Travel", "🚗", const Color(0xFF3B82F6)),
              _buildCategoryChip("Bills", "🏠", const Color(0xFF8B5CF6)),
              _buildCategoryChip("Fun", "🎬", const Color(0xFFEC4899)),
              _buildCategoryChip("Groceries", "🛒", const Color(0xFF10B981)),
              _buildCategoryChip("Settlements", "🤝", const Color(0xFF06B6D4)),
              _buildCategoryChip("Other", "💰", const Color(0xFF6B7280)),
            ],
          ),
        ),

        // Expense List
        Expanded(
          child: filteredExpenses.isEmpty
              ? _buildNoResultsFallback()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filteredExpenses.length,
                  itemBuilder: (context, index) {
                    final expense = filteredExpenses[index];
                    final payer = widget.controller.getMemberById(expense.paidByMemberId);
                    final payerName = payer?.name ?? "Unknown";
                    final isSettlement = expense.title.startsWith("Settle:");

                    // Get names of participants
                    final participantNames = expense.participantIds
                        .map((id) => widget.controller.getMemberById(id)?.name ?? "Unknown")
                        .join(", ");

                    final dateStr = "${expense.date.day}/${expense.date.month}/${expense.date.year}";

                    return Dismissible(
                      key: Key(expense.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.accentRed.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Delete Expense?"),
                            content: Text("Are you sure you want to delete '${expense.title}'? This will recalculate all group balances."),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Cancel"),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
                                child: const Text("Delete"),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) {
                        widget.controller.deleteExpense(expense.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Expense '${expense.title}' deleted")),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _getCategoryAvatar(expense.title),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          expense.title,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isSettlement ? AppTheme.accentGreen : AppTheme.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isSettlement
                                              ? "$payerName → $participantNames"
                                              : "Paid by $payerName",
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${widget.controller.currency}${expense.amount.toStringAsFixed(0)}",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: isSettlement ? AppTheme.accentGreen : AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24, color: AppTheme.border),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.people_outline, size: 14, color: AppTheme.textSecondary),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            isSettlement ? "Settlement payment" : "Split: $participantNames",
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    dateStr,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBalancesTab(List<MemberBalance> balances, List<Transaction> settlements) {
    final group = widget.controller.getGroupById(widget.groupId);
    if (group == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simplified Settlements Header/Card
          const Text(
            "Settlement Summary",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
          ),
          const SizedBox(height: 12),
          Card(
            color: AppTheme.bgSurface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.insights, color: AppTheme.secondary),
                      const SizedBox(width: 8),
                      Text(
                        settlements.isEmpty ? "All Clear!" : "Simplified Repayments",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (settlements.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          "Everyone is fully settled up! No transactions needed.",
                          style: TextStyle(fontSize: 13, color: AppTheme.accentGreen, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: settlements.length,
                      separatorBuilder: (context, index) => const Divider(color: AppTheme.border),
                      itemBuilder: (context, index) {
                        final tx = settlements[index];
                        final isFromMe = tx.fromMemberName.toLowerCase() == widget.controller.currentUserName.toLowerCase();
                        final isToMe = tx.toMemberName.toLowerCase() == widget.controller.currentUserName.toLowerCase();

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                                    children: [
                                      TextSpan(
                                        text: tx.fromMemberName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isFromMe ? AppTheme.accentRed : AppTheme.textPrimary,
                                        ),
                                      ),
                                      const TextSpan(text: " owes "),
                                      TextSpan(
                                        text: tx.toMemberName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isToMe ? AppTheme.accentGreen : AppTheme.textPrimary,
                                        ),
                                      ),
                                      const TextSpan(text: " "),
                                      TextSpan(
                                        text: "${widget.controller.currency}${tx.amount.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.notifications_active_outlined, color: AppTheme.primaryLight, size: 20),
                                onPressed: () => _showReminderDialog(tx, group.name),
                                tooltip: "Remind",
                              ),
                              const SizedBox(width: 4),
                              ElevatedButton(
                                onPressed: () => _showSettleUpDialog(tx),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  backgroundColor: isFromMe ? AppTheme.accentRed : AppTheme.primary,
                                ),
                                child: const Text("Settle"),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Individual Balances
          const Text(
            "Individual Net Balances",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: balances.length,
            itemBuilder: (context, index) {
              final bal = balances[index];
              Color balanceColor = AppTheme.textSecondary;
              String balanceSign = "";

              if (bal.netBalance > 0.01) {
                balanceColor = AppTheme.accentGreen;
                balanceSign = "+";
              } else if (bal.netBalance < -0.01) {
                balanceColor = AppTheme.accentRed;
              }

              final isMe = bal.name.toLowerCase() == widget.controller.currentUserName.toLowerCase();

              final totalGroupSpending = balances.fold<double>(0, (sum, item) => sum + item.totalSpent);
              final spendingShareProgress = totalGroupSpending > 0 
                  ? bal.totalSpent / totalGroupSpending 
                  : 0.0;

              return Card(
                color: AppTheme.bgSurface,
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            bal.name + (isMe ? " (You)" : ""),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          Text(
                            "$balanceSign${widget.controller.currency}${bal.netBalance.abs().toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: balanceColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: spendingShareProgress,
                          backgroundColor: AppTheme.bgSurfaceLight,
                          color: isMe ? AppTheme.primary : AppTheme.secondary,
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Paid: ${widget.controller.currency}${bal.totalPaid.toStringAsFixed(0)}",
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                          Text(
                            "Spent: ${widget.controller.currency}${bal.totalSpent.toStringAsFixed(0)}",
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMembersTab(List<Member> members) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Member Inline
          const Text(
            "Add Member to Group",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newMemberController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: "New Member Name",
                    hintText: "Enter name",
                    prefixIcon: Icon(Icons.person_add, color: AppTheme.textSecondary),
                  ),
                  onSubmitted: (_) => _addMember(),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.check, color: Colors.white),
                  onPressed: _addMember,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Member List
          Text(
            "Group Members (${members.length})",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final isMe = member.name.toLowerCase() == widget.controller.currentUserName.toLowerCase();

              final hasUpi = member.upiId != null && member.upiId!.isNotEmpty;
              return Card(
                color: AppTheme.bgSurface,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isMe ? AppTheme.primary : AppTheme.bgSurfaceLight,
                    child: Text(
                      member.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    member.name + (isMe ? " (You)" : ""),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    hasUpi ? member.upiId! : "UPI ID not set",
                    style: TextStyle(
                      fontSize: 12,
                      color: hasUpi ? AppTheme.primaryLight : AppTheme.textSecondary,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: AppTheme.primaryLight),
                    onPressed: () => _showEditUpiDialog(member),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(List<Expense> expenses, List<Member> members) {
    // 1. Group expenses by category
    final Map<String, double> categoryData = {};
    final Map<String, Color> categoryColors = {
      'Food': const Color(0xFFF59E0B),
      'Fuel/Travel': const Color(0xFF3B82F6),
      'Bills/Rent': const Color(0xFF8B5CF6),
      'Entertainment': const Color(0xFFEC4899),
      'Groceries': const Color(0xFF10B981),
      'Settlements': const Color(0xFF06B6D4),
      'Other': const Color(0xFF6B7280),
    };
    final Map<String, String> categoryEmojis = {
      'Food': '🍔',
      'Fuel/Travel': '🚗',
      'Bills/Rent': '🏠',
      'Entertainment': '🎬',
      'Groceries': '🛒',
      'Settlements': '🤝',
      'Other': '💰',
    };

    for (var cat in categoryColors.keys) {
      categoryData[cat] = 0.0;
    }

    for (var expense in expenses) {
      final title = expense.title.toLowerCase();
      String category = 'Other';

      if (title.startsWith("settle:")) {
        category = 'Settlements';
      } else if (title.contains("food") || title.contains("lunch") || title.contains("dinner") || title.contains("cafe") || title.contains("restaurant") || title.contains("drink") || title.contains("starbucks") || title.contains("eat") || title.contains("biryani")) {
        category = 'Food';
      } else if (title.contains("fuel") || title.contains("petrol") || title.contains("diesel") || title.contains("cab") || title.contains("uber") || title.contains("auto") || title.contains("travel") || title.contains("train") || title.contains("flight") || title.contains("trip")) {
        category = 'Fuel/Travel';
      } else if (title.contains("rent") || title.contains("flat") || title.contains("room") || title.contains("electricity") || title.contains("bill") || title.contains("wifi") || title.contains("water") || title.contains("recharge")) {
        category = 'Bills/Rent';
      } else if (title.contains("movie") || title.contains("ticket") || title.contains("netflix") || title.contains("show") || title.contains("game") || title.contains("fun") || title.contains("multiplex")) {
        category = 'Entertainment';
      } else if (title.contains("grocer") || title.contains("milk") || title.contains("supermarket") || title.contains("vegetable") || title.contains("mart")) {
        category = 'Groceries';
      }

      categoryData[category] = categoryData[category]! + expense.amount;
    }

    final Map<String, double> filteredData = {};
    for (var entry in categoryData.entries) {
      if (entry.value > 0) {
        filteredData[entry.key] = entry.value;
      }
    }

    final totalSpent = filteredData.values.fold<double>(0, (sum, val) => sum + val);

    if (expenses.isEmpty || totalSpent == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pie_chart_outline, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text(
              "No data to analyze",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              "Log group expenses first to view spending analytics.",
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final sortedEntries = filteredData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Spend Distribution",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
          ),
          const SizedBox(height: 12),
          Card(
            color: AppTheme.bgSurface,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: AnalyticsPieChart(
                data: filteredData,
                colors: categoryColors,
                emojis: categoryEmojis,
                currencySymbol: widget.controller.currency,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Category Breakdown",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedEntries.length,
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              final percentage = (entry.value / totalSpent) * 100;
              final color = categoryColors[entry.key] ?? Colors.grey;
              final emoji = categoryEmojis[entry.key] ?? "💰";

              return Card(
                color: AppTheme.bgSurface,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.15),
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                  title: Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${percentage.toStringAsFixed(1)}% of total spend",
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  trailing: Text(
                    "${widget.controller.currency}${entry.value.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverdueBanner(Group group) {
    final dateStr = "${group.dueDate!.day}/${group.dueDate!.month}/${group.dueDate!.year}";
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.accentRed.withOpacity(0.12),
        border: const Border(
          bottom: BorderSide(color: AppTheme.accentRed, width: 1.2),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.accentRed, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "OVERDUE SETTLEMENT DEADLINE",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentRed,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "This group was due for settlement on $dateStr.",
                  style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReminderDialog(Transaction tx, String groupName) {
    final reminderText = "Hey ${tx.fromMemberName}! Friendly reminder to settle up your debt of ${widget.controller.currency}${tx.amount.toStringAsFixed(2)} for the split group '$groupName'. Thanks!";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.bgSurface,
          title: const Row(
            children: [
              Icon(Icons.notifications_active, color: AppTheme.primaryLight),
              SizedBox(width: 10),
              Text("Send Reminder"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Reminder text preview:",
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  reminderText,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.content_copy, size: 16),
              label: const Text("Copy to Clipboard"),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: reminderText));
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Reminder text copied to clipboard!"),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildRouletteTab(List<Member> members) {
    if (members.isEmpty) {
      return const Center(
        child: Text(
          "No members in this group to run Roulette!",
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          // Fun Header
          const Icon(Icons.casino, size: 52, color: AppTheme.primaryLight),
          const SizedBox(height: 12),
          const Text(
            "Who Pays the Bill?",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            "Spin the roulette wheel to pick a random payer!",
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // The Roulette Display area
          Container(
            height: 220,
            width: double.infinity,
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // outer ring decorative
                Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _isSpinning ? AppTheme.primary : AppTheme.glassBorder, width: 4),
                  ),
                ),
                
                // Display the current cycling member
                if (_rouletteSelectedIndex >= 0 && _rouletteSelectedIndex < members.length)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: _isSpinning 
                          ? AppTheme.primary.withOpacity(0.2)
                          : AppTheme.accentGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isSpinning ? AppTheme.primaryLight : AppTheme.accentGreen,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isSpinning ? AppTheme.primary : AppTheme.accentGreen).withOpacity(0.2),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isSpinning ? "🎯 PICKING..." : "🏆 CHOSEN PAYER",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _isSpinning ? AppTheme.primaryLight : AppTheme.accentGreen,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          members[_rouletteSelectedIndex].name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("🎲", style: TextStyle(fontSize: 40)),
                      SizedBox(height: 8),
                      Text(
                        "Tap below to roll",
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),

          // Spin Button
          SizedBox(
            width: 200,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSpinning 
                  ? null 
                  : () async {
                      setState(() {
                        _isSpinning = true;
                      });

                      // Simple interval-based rotation animation simulation
                      int cycles = 20; // total steps
                      int delay = 50;  // initial delay in ms

                      for (int i = 0; i < cycles; i++) {
                        if (!mounted) return;
                        setState(() {
                          _rouletteSelectedIndex = (i % members.length);
                        });
                        
                        // Slowly decay speed (increase delay)
                        if (i > cycles * 0.7) {
                          delay += 40;
                        } else if (i > cycles * 0.5) {
                          delay += 20;
                        }
                        await Future.delayed(Duration(milliseconds: delay));
                      }

                      // Pick final random winner
                      final winnerIndex = (DateTime.now().millisecondsSinceEpoch) % members.length;
                      if (!mounted) return;
                      setState(() {
                        _rouletteSelectedIndex = winnerIndex;
                        _isSpinning = false;
                      });

                      // Show winner toast/banner
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("🎉 ${members[winnerIndex].name} has been chosen to pay!"),
                          backgroundColor: AppTheme.primary,
                        ),
                      );
                    },
              icon: const Icon(Icons.autorenew),
              label: Text(_isSpinning ? "SPINNING..." : "SPIN WHEEL"),
              style: ElevatedButton.styleFrom(
                disabledBackgroundColor: AppTheme.primary.withOpacity(0.3),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          // Option to clear selection
          if (!_isSpinning && _rouletteSelectedIndex >= 0)
            TextButton(
              onPressed: () {
                setState(() {
                  _rouletteSelectedIndex = -1;
                });
              },
              style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
              child: const Text("Reset Selection"),
            ),
        ],
      ),
    );
  }
}
