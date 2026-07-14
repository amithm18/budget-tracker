import 'package:flutter/material.dart';
import '../controllers/budget_controller.dart';
import '../models/member.dart';
import '../models/expense.dart';
import '../theme/app_theme.dart';

class AddExpenseScreen extends StatefulWidget {
  final BudgetController controller;
  final String groupId;
  final Expense? expenseToEdit;

  const AddExpenseScreen({
    super.key,
    required this.controller,
    required this.groupId,
    this.expenseToEdit,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedPayerId;
  final List<String> _selectedParticipantIds = [];
  List<Member> _groupMembers = [];
  double _amount = 0.0;

  // New State variables for custom split
  SplitType _splitType = SplitType.equal;
  final Map<String, double> _customSplitValues = {};
  final Map<String, TextEditingController> _splitControllers = {};
  final Set<String> _lockedMemberIds = {};

  @override
  void initState() {
    super.initState();
    _groupMembers = widget.controller.getMembersForGroup(widget.groupId);

    // Initialize text controllers for all members
    for (var m in _groupMembers) {
      _splitControllers[m.id] = TextEditingController();
    }

    if (widget.expenseToEdit != null) {
      _titleController.text = widget.expenseToEdit!.title;
      _amountController.text = widget.expenseToEdit!.amount.toString();
      _amount = widget.expenseToEdit!.amount;
      _selectedPayerId = widget.expenseToEdit!.paidByMemberId;
      
      _selectedParticipantIds.addAll(widget.expenseToEdit!.cleanParticipantIds);
      _splitType = widget.expenseToEdit!.splitType;
      _customSplitValues.addAll(widget.expenseToEdit!.splitValues);

      // Populate text controllers with values
      for (var m in _groupMembers) {
        if (_selectedParticipantIds.contains(m.id)) {
          final val = _customSplitValues[m.id] ?? 0.0;
          if (val > 0) {
            _splitControllers[m.id]!.text = _splitType == SplitType.share && val == val.toInt()
                ? val.toInt().toString()
                : val.toStringAsFixed(val % 1 == 0 ? 0 : 2);
          }
        }
      }
    } else {
      // Default payer is the current user if they are in the group, otherwise the first member
      final currentUserMember = _groupMembers.firstWhere(
        (m) => m.userId == widget.controller.currentUserId,
        orElse: () => _groupMembers.isNotEmpty ? _groupMembers.first : Member(id: '', name: '', groupId: ''),
      );

      if (currentUserMember.id.isNotEmpty) {
        _selectedPayerId = currentUserMember.id;
      }

      // Default: split among all members
      _selectedParticipantIds.addAll(_groupMembers.map((m) => m.id));
      _splitType = SplitType.equal;
    }

    // Listen to amount changes to dynamically calculate share
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _titleController.dispose();
    _amountController.dispose();
    for (var controller in _splitControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onAmountChanged() {
    final parsed = double.tryParse(_amountController.text);
    setState(() {
      _amount = parsed ?? 0.0;
      _redistributeRemaining();
    });
  }

  void _toggleParticipant(String memberId) {
    setState(() {
      if (_selectedParticipantIds.contains(memberId)) {
        _selectedParticipantIds.remove(memberId);
        _customSplitValues.remove(memberId);
        _lockedMemberIds.remove(memberId);
        _splitControllers[memberId]?.clear();
      } else {
        _selectedParticipantIds.add(memberId);
        // Default initial values
        if (_splitType == SplitType.share) {
          _customSplitValues[memberId] = 1.0;
          _splitControllers[memberId]?.text = "1";
        } else {
          _customSplitValues[memberId] = 0.0;
          _splitControllers[memberId]?.text = "0";
        }
      }
      _redistributeRemaining();
    });
  }

  void _selectAll() {
    setState(() {
      _selectedParticipantIds.clear();
      _selectedParticipantIds.addAll(_groupMembers.map((m) => m.id));
      _lockedMemberIds.clear();
      _resetSplitEqually();
    });
  }

  void _selectNone() {
    setState(() {
      _selectedParticipantIds.clear();
      _customSplitValues.clear();
      _lockedMemberIds.clear();
      for (var m in _groupMembers) {
        _splitControllers[m.id]?.clear();
      }
    });
  }

  void _resetSplitEqually() {
    if (_selectedParticipantIds.isEmpty) return;

    setState(() {
      _lockedMemberIds.clear(); // Clear manual edits on reset split equally

      if (_splitType == SplitType.equal) {
        // Equal split is handled automatically, no custom values needed
      } else if (_splitType == SplitType.amount) {
        if (_amount <= 0) return;
        final equalShare = _amount / _selectedParticipantIds.length;
        final shareRounded = double.parse(equalShare.toStringAsFixed(2));

        double sum = 0.0;
        for (var id in _selectedParticipantIds) {
          _customSplitValues[id] = shareRounded;
          sum += shareRounded;
        }

        // Adjust remaining rounding error
        final diff = _amount - sum;
        if (diff.abs() > 0.001 && _selectedParticipantIds.isNotEmpty) {
          final firstId = _selectedParticipantIds.first;
          _customSplitValues[firstId] = (_customSplitValues[firstId] ?? 0.0) + diff;
        }
      } else if (_splitType == SplitType.share) {
        for (var id in _selectedParticipantIds) {
          _customSplitValues[id] = 1.0;
        }
      } else if (_splitType == SplitType.percent) {
        final equalPct = 100.0 / _selectedParticipantIds.length;
        final pctRounded = double.parse(equalPct.toStringAsFixed(2));

        double sum = 0.0;
        for (var id in _selectedParticipantIds) {
          _customSplitValues[id] = pctRounded;
          sum += pctRounded;
        }

        // Adjust remaining rounding error
        final diff = 100.0 - sum;
        if (diff.abs() > 0.001 && _selectedParticipantIds.isNotEmpty) {
          final firstId = _selectedParticipantIds.first;
          _customSplitValues[firstId] = (_customSplitValues[firstId] ?? 0.0) + diff;
        }
      }

      // Update controllers text
      for (var id in _selectedParticipantIds) {
        final val = _customSplitValues[id] ?? 0.0;
        final controller = _splitControllers[id];
        if (controller != null) {
          controller.text = val == val.toInt() ? val.toInt().toString() : val.toStringAsFixed(2);
        }
      }
    });
  }

  void _redistributeRemaining() {
    if (_selectedParticipantIds.isEmpty) return;
    if (_splitType == SplitType.equal || _splitType == SplitType.share) return;

    final unlockedSelectedIds = _selectedParticipantIds.where((id) => !_lockedMemberIds.contains(id)).toList();
    if (unlockedSelectedIds.isEmpty) return;

    final sumOfLocked = _selectedParticipantIds
        .where((id) => _lockedMemberIds.contains(id))
        .fold<double>(0.0, (sum, id) => sum + (_customSplitValues[id] ?? 0.0));

    final double totalToDistribute = _splitType == SplitType.amount ? _amount : 100.0;
    final remaining = totalToDistribute - sumOfLocked;

    // Distribute remaining equally among unlocked members
    final equalShare = remaining / unlockedSelectedIds.length;
    final shareRounded = double.parse(equalShare.toStringAsFixed(2));

    double sum = 0.0;
    for (var id in unlockedSelectedIds) {
      _customSplitValues[id] = shareRounded;
      sum += shareRounded;
    }

    // Rounding error correction
    final diff = remaining - sum;
    if (diff.abs() > 0.001 && unlockedSelectedIds.isNotEmpty) {
      final firstId = unlockedSelectedIds.first;
      _customSplitValues[firstId] = (_customSplitValues[firstId] ?? 0.0) + diff;
    }

    // Update text fields only for unlocked members to avoid cursor jumping
    for (var id in unlockedSelectedIds) {
      final val = _customSplitValues[id] ?? 0.0;
      final controller = _splitControllers[id];
      if (controller != null) {
        controller.text = val == val.toInt() ? val.toInt().toString() : val.toStringAsFixed(2);
      }
    }
  }

  void _onSplitValueChanged(String memberId, String valStr) {
    final parsed = double.tryParse(valStr) ?? 0.0;
    setState(() {
      _customSplitValues[memberId] = parsed;
      _lockedMemberIds.add(memberId);
      _redistributeRemaining();
    });
  }

  double get _customSplitSum {
    return _selectedParticipantIds.fold<double>(0.0, (sum, id) => sum + (_customSplitValues[id] ?? 0.0));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPayerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a payer.")),
      );
      return;
    }

    if (_selectedParticipantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one participant.")),
      );
      return;
    }

    // Submit Validation for Custom Splits
    if (_splitType == SplitType.amount) {
      final sum = _customSplitSum;
      if ((_amount - sum).abs() >= 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("The sum of split amounts (${widget.controller.currency}${sum.toStringAsFixed(2)}) must equal the total amount (${widget.controller.currency}${_amount.toStringAsFixed(2)})."),
            backgroundColor: AppTheme.accentRed,
          ),
        );
        return;
      }
    } else if (_splitType == SplitType.percent) {
      final sum = _customSplitSum;
      if ((100.0 - sum).abs() >= 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("The sum of percentages (${sum.toStringAsFixed(1)}%) must equal 100%."),
            backgroundColor: AppTheme.accentRed,
          ),
        );
        return;
      }
    } else if (_splitType == SplitType.share) {
      final sum = _customSplitSum;
      if (sum <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("The total sum of shares must be greater than 0."),
            backgroundColor: AppTheme.accentRed,
          ),
        );
        return;
      }
    }

    // Serialize split type and custom values into participantIds list
    final formattedParticipantIds = _selectedParticipantIds.map((id) {
      if (_splitType == SplitType.equal) {
        return id;
      } else {
        final val = _customSplitValues[id] ?? 0.0;
        return "$id:${_splitType.name}:$val";
      }
    }).toList();

    try {
      if (widget.expenseToEdit != null) {
        await widget.controller.updateExpense(
          expenseId: widget.expenseToEdit!.id,
          groupId: widget.groupId,
          title: _titleController.text.trim(),
          amount: _amount,
          paidByMemberId: _selectedPayerId!,
          participantIds: formattedParticipantIds,
          date: widget.expenseToEdit!.date,
        );
      } else {
        await widget.controller.addExpenseToGroup(
          groupId: widget.groupId,
          title: _titleController.text.trim(),
          amount: _amount,
          paidByMemberId: _selectedPayerId!,
          participantIds: formattedParticipantIds,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.expenseToEdit != null
                ? "Expense '${_titleController.text}' updated."
                : "Expense '${_titleController.text}' added."),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.expenseToEdit != null
                ? "Error updating expense: $e"
                : "Error adding expense: $e"),
          ),
        );
      }
    }
  }

  Widget _buildSplitModeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: SplitType.values.map((type) {
          final isSelected = _splitType == type;
          String label = "";
          IconData icon;
          switch (type) {
            case SplitType.equal:
              label = "Equally";
              icon = Icons.align_horizontal_center;
              break;
            case SplitType.amount:
              label = "Amount";
              icon = Icons.payments;
              break;
            case SplitType.share:
              label = "Share";
              icon = Icons.pie_chart;
              break;
            case SplitType.percent:
              label = "Percent";
              icon = Icons.percent;
              break;
          }
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.textSecondary),
              label: Text(label),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _splitType = type;
                    _resetSplitEqually();
                  });
                }
              },
              selectedColor: AppTheme.primary,
              backgroundColor: AppTheme.bgSurfaceLight,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? AppTheme.primaryLight : AppTheme.border,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSplitStatusMessage() {
    if (_selectedParticipantIds.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          "Please select at least one participant.",
          style: TextStyle(color: AppTheme.accentRed, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      );
    }

    if (_splitType == SplitType.amount) {
      final sum = _customSplitSum;
      final diff = _amount - sum;
      final isExact = diff.abs() < 0.01;
      
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isExact ? "Sum matches total!" : "Sum: ${widget.controller.currency}${sum.toStringAsFixed(2)} of ${widget.controller.currency}${_amount.toStringAsFixed(2)}",
              style: TextStyle(
                color: isExact ? AppTheme.accentGreen : AppTheme.accentRed,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            if (!isExact)
              Text(
                diff > 0 
                    ? "Remaining: ${widget.controller.currency}${diff.toStringAsFixed(2)}" 
                    : "Over by: ${widget.controller.currency}${(-diff).toStringAsFixed(2)}",
                style: const TextStyle(
                  color: AppTheme.accentRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
          ],
        ),
      );
    } else if (_splitType == SplitType.percent) {
      final sum = _customSplitSum;
      final diff = 100.0 - sum;
      final isExact = diff.abs() < 0.01;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isExact ? "Percentage sum matches 100%!" : "Sum: ${sum.toStringAsFixed(1)}% of 100%",
              style: TextStyle(
                color: isExact ? AppTheme.accentGreen : AppTheme.accentRed,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            if (!isExact)
              Text(
                diff > 0 
                    ? "Remaining: ${diff.toStringAsFixed(1)}%" 
                    : "Over by: ${(-diff).toStringAsFixed(1)}%",
                style: const TextStyle(
                  color: AppTheme.accentRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMembersSplitList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _groupMembers.length,
      itemBuilder: (context, index) {
        final m = _groupMembers[index];
        final isSelected = _selectedParticipantIds.contains(m.id);
        final isMe = m.userId == widget.controller.currentUserId;
        
        // Calculate dynamic share for display
        double individualShare = 0.0;
        if (isSelected) {
          if (_splitType == SplitType.equal) {
            individualShare = _selectedParticipantIds.isNotEmpty ? _amount / _selectedParticipantIds.length : 0.0;
          } else if (_splitType == SplitType.amount) {
            individualShare = _customSplitValues[m.id] ?? 0.0;
          } else if (_splitType == SplitType.share) {
            final totalShares = _selectedParticipantIds.fold<double>(0.0, (sum, id) => sum + (_customSplitValues[id] ?? 0.0));
            final mShare = _customSplitValues[m.id] ?? 0.0;
            individualShare = totalShares > 0 ? (mShare / totalShares) * _amount : 0.0;
          } else if (_splitType == SplitType.percent) {
            final mPercent = _customSplitValues[m.id] ?? 0.0;
            individualShare = (mPercent / 100.0) * _amount;
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.bgSurfaceLight : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.glassBorder : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                activeColor: AppTheme.primary,
                onChanged: (val) {
                  _toggleParticipant(m.id);
                },
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 18,
                backgroundColor: isSelected ? AppTheme.primary.withOpacity(0.2) : AppTheme.bgSurfaceLight,
                child: Text(
                  m.name.isNotEmpty ? m.name[0].toUpperCase() : "?",
                  style: TextStyle(
                    color: isSelected ? AppTheme.primaryLight : AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name + (isMe ? " (You)" : ""),
                      style: TextStyle(
                        color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 15,
                      ),
                    ),
                    if (isSelected && _splitType != SplitType.equal && _splitType != SplitType.amount)
                      Text(
                        "${widget.controller.currency}${individualShare.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: AppTheme.accentGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (_splitType != SplitType.equal)
                SizedBox(
                  width: 100,
                  height: 40,
                  child: Opacity(
                    opacity: isSelected ? 1.0 : 0.4,
                    child: TextFormField(
                      controller: _splitControllers[m.id],
                      enabled: isSelected,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        prefixText: _splitType == SplitType.amount ? widget.controller.currency : null,
                        suffixText: _splitType == SplitType.percent ? "%" : null,
                        hintText: _splitType == SplitType.share ? "1" : "0",
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.border, width: 1.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.transparent),
                        ),
                      ),
                      onChanged: (val) => _onSplitValueChanged(m.id, val),
                    ),
                  ),
                )
              else if (isSelected)
                Text(
                  "${widget.controller.currency}${individualShare.toStringAsFixed(2)}",
                  style: const TextStyle(
                    color: AppTheme.accentGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expenseToEdit != null ? "Edit Expense" : "Add Expense"),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Details Form Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Expense details",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleController,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: "Title / Description",
                          hintText: "e.g., Lunch, Petrol, Movie tickets",
                          prefixIcon: Icon(Icons.description, color: AppTheme.textSecondary),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Please enter a description";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: "Amount (${widget.controller.currency})",
                          hintText: "0.00",
                          prefixIcon: const Icon(Icons.currency_rupee, color: AppTheme.primaryLight),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Please enter an amount";
                          }
                          final parsed = double.tryParse(value);
                          if (parsed == null || parsed <= 0) {
                            return "Please enter a valid amount greater than 0";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Payer Selection Chips
                      const Text(
                        "Who Paid?",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 48,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _groupMembers.length,
                          itemBuilder: (context, index) {
                            final m = _groupMembers[index];
                            final isSelected = _selectedPayerId == m.id;
                            final isMe = m.userId == widget.controller.currentUserId;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(m.name + (isMe ? " (You)" : "")),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedPayerId = m.id;
                                    });
                                  }
                                },
                                selectedColor: AppTheme.primary,
                                backgroundColor: AppTheme.bgSurfaceLight,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isSelected ? AppTheme.primaryLight : AppTheme.border,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Split Section Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Split Between",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryLight,
                            ),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: _selectAll,
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                child: const Text("All"),
                              ),
                              const Text("|", style: TextStyle(color: AppTheme.border)),
                              TextButton(
                                onPressed: _selectNone,
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                child: const Text("None"),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(color: AppTheme.border),
                      
                      // Split Type choice selector
                      const Text(
                        "Split by",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      _buildSplitModeSelector(),
                      const SizedBox(height: 12),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${_selectedParticipantIds.length}/${_groupMembers.length} Selected",
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                          ),
                          if (_splitType != SplitType.equal)
                            TextButton.icon(
                              onPressed: _resetSplitEqually,
                              icon: const Icon(Icons.refresh, size: 14, color: AppTheme.primaryLight),
                              label: const Text(
                                "Split Equally",
                                style: TextStyle(color: AppTheme.primaryLight, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                        ],
                      ),
                      const Divider(color: AppTheme.border),
                      const SizedBox(height: 8),

                      // List of members with custom inputs
                      _buildMembersSplitList(),

                      // Status messages for warnings and differences
                      _buildSplitStatusMessage(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: Text(widget.expenseToEdit != null ? "Save Changes" : "Add Expense"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
