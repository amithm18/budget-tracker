import 'package:flutter/material.dart';
import '../controllers/budget_controller.dart';
import '../models/member.dart';
import '../models/expense.dart';
import '../theme/app_theme.dart';
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

  @override
  void dispose() {
    _newMemberController.dispose();
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

  void _showSettleUpDialog(Transaction tx) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Record Settlement"),
          content: Text(
            "Would you like to record a payment of ₹${tx.amount.toStringAsFixed(2)} from ${tx.fromMemberName} to ${tx.toMemberName}?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                // Record the settlement as a special expense
                // paidBy = fromMember, participant = toMember.
                // This adjusts the balance exactly: fromMember gets +amount (paid), toMember gets -amount (spent).
                await widget.controller.addExpenseToGroup(
                  groupId: widget.groupId,
                  title: "Settle: ${tx.fromMemberName} to ${tx.toMemberName}",
                  amount: tx.amount,
                  paidByMemberId: tx.fromMemberId,
                  participantIds: [tx.toMemberId],
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Recorded payment of ₹${tx.amount.toStringAsFixed(2)}",
                      ),
                    ),
                  );
                }
              },
              child: const Text("Confirm"),
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
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(group.name),
              bottom: const TabBar(
                indicatorColor: AppTheme.primary,
                labelColor: AppTheme.primaryLight,
                unselectedLabelColor: AppTheme.textSecondary,
                tabs: [
                  Tab(icon: Icon(Icons.receipt_long), text: "Expenses"),
                  Tab(icon: Icon(Icons.account_balance), text: "Balances"),
                  Tab(icon: Icon(Icons.people), text: "Members"),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // 1. Expenses Tab
                _buildExpensesTab(expenses, members),

                // 2. Balances Tab
                _buildBalancesTab(balances, settlements),

                // 3. Members Tab
                _buildMembersTab(members),
              ],
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

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final expense = expenses[index];
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                                decoration: isSettlement ? TextDecoration.none : TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isSettlement
                                  ? "$payerName paid $participantNames"
                                  : "Paid by $payerName",
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "₹${expense.amount.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isSettlement ? AppTheme.accentGreen : AppTheme.primaryLight,
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
                                isSettlement ? "Settlement payment" : "Split among: $participantNames",
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
    );
  }

  Widget _buildBalancesTab(List<MemberBalance> balances, List<Transaction> settlements) {
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
                      separatorBuilder: (_, __) => const Divider(color: AppTheme.border),
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
                                        text: "₹${tx.amount.toStringAsFixed(2)}",
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

              return Card(
                color: AppTheme.bgSurface,
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bal.name + (isMe ? " (You)" : ""),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Paid: ₹${bal.totalPaid.toStringAsFixed(1)} • Spent: ₹${bal.totalSpent.toStringAsFixed(1)}",
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                      Text(
                        "$balanceSign₹${bal.netBalance.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: balanceColor,
                        ),
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
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
