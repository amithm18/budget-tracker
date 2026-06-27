import 'package:flutter/material.dart';
import '../controllers/budget_controller.dart';
import '../models/group.dart';
import '../models/member.dart';
import '../theme/app_theme.dart';
import '../widgets/antigravity_background.dart';
import 'create_group_screen.dart';
import 'group_details_screen.dart';

class HomeScreen extends StatefulWidget {
  final BudgetController controller;

  const HomeScreen({super.key, required this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
  }

  Gradient _getGroupGradient(String name) {
    final int hash = name.hashCode;
    final List<List<Color>> gradients = [
      [const Color(0xFF6366F1), const Color(0xFF0EA5E9)], // Indigo -> Sky
      [const Color(0xFF10B981), const Color(0xFF059669)], // Emerald -> Green
      [const Color(0xFFF43F5E), const Color(0xFFE11D48)], // Rose -> Red
      [const Color(0xFFF59E0B), const Color(0xFFD97706)], // Amber -> Orange
      [const Color(0xFF8B5CF6), const Color(0xFFEC4899)], // Purple -> Pink
      [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)], // Blue -> Dark Blue
    ];
    return LinearGradient(
      colors: gradients[hash.abs() % gradients.length],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  void _showProfileDialog() {
    final TextEditingController nameEditController =
        TextEditingController(text: widget.controller.currentUserName);
    String tempCurrency = widget.controller.currency;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.bgSurface,
              title: const Text("Edit Settings", style: TextStyle(color: AppTheme.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameEditController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: "Your Name",
                      hintText: "Enter your name to track your balances",
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: tempCurrency,
                    dropdownColor: AppTheme.bgSurface,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: "Preferred Currency Symbol",
                    ),
                    items: const [
                      DropdownMenuItem(value: '₹', child: Text("₹ (INR)")),
                      DropdownMenuItem(value: '\$', child: Text("\$ (USD)")),
                      DropdownMenuItem(value: '€', child: Text("€ (EUR)")),
                      DropdownMenuItem(value: '£', child: Text("£ (GBP)")),
                      DropdownMenuItem(value: '¥', child: Text("¥ (JPY/CNY)")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          tempCurrency = val;
                        });
                      }
                    },
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
                    if (nameEditController.text.trim().isNotEmpty) {
                      await widget.controller.updateCurrentUserName(nameEditController.text);
                      await widget.controller.updateCurrency(tempCurrency);
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final stats = widget.controller.getOverallStats();
        final groups = widget.controller.groups;

        return Scaffold(
          body: AntigravityBackground(
            child: SafeArea(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header / Profile Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Welcome back,",
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            widget.controller.currentUserName,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _showProfileDialog,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.primary, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: AppTheme.bgSurfaceLight,
                            child: Text(
                              widget.controller.currentUserName.isNotEmpty
                                  ? widget.controller.currentUserName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryLight,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Premium Glassmorphic Dashboard Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Container(
                    height: 195,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.08),
                          Colors.white.withOpacity(0.02),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.15),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          // Decorative transparent shapes to feel organic/premium
                          Positioned(
                            right: -30,
                            top: -30,
                            child: CircleAvatar(
                              radius: 80,
                              backgroundColor: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          Positioned(
                            left: -40,
                            bottom: -50,
                            child: CircleAvatar(
                              radius: 90,
                              backgroundColor: Colors.black.withOpacity(0.12),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "TOTAL NET BALANCE",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white70,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    Icon(
                                      Icons.account_balance_wallet,
                                      color: Colors.white.withOpacity(0.6),
                                      size: 20,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "${stats['net']! >= 0 ? '+' : ''}${widget.controller.currency}${stats['net']!.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Spacer(),
                                Row(
                                  children: [
                                    // Owed Card
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.1),
                                            width: 1,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            const CircleAvatar(
                                              radius: 13,
                                              backgroundColor: Colors.white24,
                                              child: Icon(
                                                Icons.arrow_downward,
                                                size: 14,
                                                color: AppTheme.accentGreen,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    "You're owed",
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                  Text(
                                                    "${widget.controller.currency}${stats['owed']!.toStringAsFixed(1)}",
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.accentGreen,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Owe Card
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.1),
                                            width: 1,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            const CircleAvatar(
                                              radius: 13,
                                              backgroundColor: Colors.white24,
                                              child: Icon(
                                                Icons.arrow_upward,
                                                size: 14,
                                                color: AppTheme.accentRed,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    "You owe",
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                  Text(
                                                    "${widget.controller.currency}${stats['owe']!.toStringAsFixed(1)}",
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.accentRed,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Title
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "Your Split Groups",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Group List or Empty State
                Expanded(
                  child: groups.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                          itemCount: groups.length,
                          itemBuilder: (context, index) {
                            final group = groups[index];
                            return _buildGroupItem(group);
                          },
                        ),
                ),
              ],
            ),
          )),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateGroupScreen(controller: widget.controller),
                ),
              );
            },
            icon: const Icon(Icons.group_add),
            label: const Text("New Group"),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border, width: 2),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              size: 60,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "No active groups",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Create a group, add your friends, and start splitting expenses easily!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupItem(Group group) {
    // Determine the user's specific balance status in this group
    final members = widget.controller.getMembersForGroup(group.id);
    final userMember = members.firstWhere(
      (m) => m.name.trim().toLowerCase() == widget.controller.currentUserName.trim().toLowerCase(),
      orElse: () => Member(id: '', name: '', groupId: ''),
    );

    String statusText = "No expenses yet";
    Color statusColor = AppTheme.textSecondary;
    IconData statusIcon = Icons.info_outline;

    if (userMember.id.isNotEmpty) {
      final settlements = widget.controller.getGroupSettlements(group.id);
      double owe = 0;
      double owed = 0;

      for (var tx in settlements) {
        if (tx.fromMemberId == userMember.id) {
          owe += tx.amount;
        } else if (tx.toMemberId == userMember.id) {
          owed += tx.amount;
        }
      }

      if (owed > 0) {
        statusText = "You are owed ${widget.controller.currency}${owed.toStringAsFixed(1)}";
        statusColor = AppTheme.accentGreen;
        statusIcon = Icons.call_received;
      } else if (owe > 0) {
        statusText = "You owe ${widget.controller.currency}${owe.toStringAsFixed(1)}";
        statusColor = AppTheme.accentRed;
        statusIcon = Icons.call_made;
      } else if (widget.controller.getExpensesForGroup(group.id).isNotEmpty) {
        statusText = "You are settled up";
        statusColor = AppTheme.textSecondary;
        statusIcon = Icons.check_circle_outline;
      }
    } else if (members.isNotEmpty) {
      statusText = "Join group as '${widget.controller.currentUserName}' to track";
    }

    return Dismissible(
      key: Key(group.id),
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
            title: const Text("Delete Group?"),
            content: Text("Are you sure you want to delete '${group.name}'? All members and expenses will be permanently removed."),
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
        widget.controller.deleteGroup(group.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Group '${group.name}' deleted")),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupDetailsScreen(
                  controller: widget.controller,
                  groupId: group.id,
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: statusColor == AppTheme.textSecondary
                        ? Colors.transparent
                        : statusColor,
                    width: 5,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Group Icon/Initial
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      gradient: _getGroupGradient(group.name),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      group.name.substring(0, group.name.length >= 2 ? 2 : 1).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Group Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${members.length} members",
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Group Balance Status
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
