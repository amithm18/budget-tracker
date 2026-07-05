import 'package:flutter/material.dart';
import '../controllers/budget_controller.dart';
import '../models/member.dart';
import '../theme/app_theme.dart';
import '../widgets/glassmorphic_card.dart';

class AddExpenseScreen extends StatefulWidget {
  final BudgetController controller;
  final String groupId;
  final String? prefilledPayerId;
  final String? prefilledTitle;
  final double? prefilledAmount;

  const AddExpenseScreen({
    super.key,
    required this.controller,
    required this.groupId,
    this.prefilledPayerId,
    this.prefilledTitle,
    this.prefilledAmount,
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

  // Custom split variables
  bool _splitEqually = true;
  final Map<String, TextEditingController> _customSplitControllers = {};

  @override
  void initState() {
    super.initState();
    _groupMembers = widget.controller.getMembersForGroup(widget.groupId);

    // Initial controllers for custom splits
    for (var m in _groupMembers) {
      _customSplitControllers[m.id] = TextEditingController(text: '0.00');
    }

    // Prefills
    if (widget.prefilledTitle != null) {
      _titleController.text = widget.prefilledTitle!;
    }
    if (widget.prefilledAmount != null) {
      _amountController.text = widget.prefilledAmount!.toString();
      _amount = widget.prefilledAmount!;
    }

    if (widget.prefilledPayerId != null) {
      _selectedPayerId = widget.prefilledPayerId;
    } else {
      // Default payer is the current user if they are in the group, otherwise the first member
      final currentUserMember = _groupMembers.firstWhere(
        (m) => m.name.toLowerCase() == widget.controller.currentUserName.toLowerCase(),
        orElse: () => _groupMembers.isNotEmpty ? _groupMembers.first : Member(id: '', name: '', groupId: ''),
      );

      if (currentUserMember.id.isNotEmpty) {
        _selectedPayerId = currentUserMember.id;
      }
    }

    // Default: split among all members
    _selectedParticipantIds.addAll(_groupMembers.map((m) => m.id));

    // Listen to amount changes to dynamically calculate share
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _titleController.dispose();
    _amountController.dispose();
    _customSplitControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _onAmountChanged() {
    final parsed = double.tryParse(_amountController.text);
    setState(() {
      _amount = parsed ?? 0.0;
      if (_splitEqually) {
        _distributeEqually();
      }
    });
  }

  void _distributeEqually() {
    if (_selectedParticipantIds.isEmpty || _amount <= 0) return;
    final share = _amount / _selectedParticipantIds.length;
    _customSplitControllers.forEach((memberId, controller) {
      if (_selectedParticipantIds.contains(memberId)) {
        controller.text = share.toStringAsFixed(2);
      } else {
        controller.text = '0.00';
      }
    });
  }

  void _toggleParticipant(String memberId) {
    setState(() {
      if (_selectedParticipantIds.contains(memberId)) {
        _selectedParticipantIds.remove(memberId);
        _customSplitControllers[memberId]?.text = '0.00';
      } else {
        _selectedParticipantIds.add(memberId);
      }

      if (_splitEqually) {
        _distributeEqually();
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedParticipantIds.clear();
      _selectedParticipantIds.addAll(_groupMembers.map((m) => m.id));
      if (_splitEqually) {
        _distributeEqually();
      }
    });
  }

  void _selectNone() {
    setState(() {
      _selectedParticipantIds.clear();
      _customSplitControllers.forEach((_, controller) => controller.text = '0.00');
    });
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

    Map<String, double>? customAmounts;

    if (!_splitEqually) {
      // Validate sum of custom splits
      double sum = 0.0;
      final tempCustomAmounts = <String, double>{};
      
      for (var mId in _selectedParticipantIds) {
        final val = double.tryParse(_customSplitControllers[mId]?.text ?? '0') ?? 0.0;
        if (val <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Each selected participant must owe a valid amount greater than 0")),
          );
          return;
        }
        sum += val;
        tempCustomAmounts[mId] = val;
      }

      // Check with a minor margin of tolerance for decimals
      if ((sum - _amount).abs() > 0.05) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Total split sum (${widget.controller.currency}${sum.toStringAsFixed(2)}) must equal total amount (${widget.controller.currency}${_amount.toStringAsFixed(2)})"
            ),
          ),
        );
        return;
      }
      customAmounts = tempCustomAmounts;
    }

    try {
      await widget.controller.addExpenseToGroup(
        groupId: widget.groupId,
        title: _titleController.text.trim(),
        amount: _amount,
        paidByMemberId: _selectedPayerId!,
        participantIds: _selectedParticipantIds,
        customAmounts: customAmounts,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Expense '${_titleController.text}' added.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error adding expense: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sharePerPerson = _selectedParticipantIds.isNotEmpty
        ? _amount / _selectedParticipantIds.length
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Expense"),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Details Form Card
              GlassmorphicCard(
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
                          final isMe = m.name.toLowerCase() == widget.controller.currentUserName.toLowerCase();
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
              const SizedBox(height: 20),

              // Split Type Toggle Selector
              GlassmorphicCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Split Type",
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text("Equally"),
                          selected: _splitEqually,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _splitEqually = true;
                                _distributeEqually();
                              });
                            }
                          },
                          selectedColor: AppTheme.primary,
                          backgroundColor: AppTheme.bgSurfaceLight,
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text("Custom Unequal"),
                          selected: !_splitEqually,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _splitEqually = false;
                              });
                            }
                          },
                          selectedColor: AppTheme.primary,
                          backgroundColor: AppTheme.bgSurfaceLight,
                        ),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Split Section Card
              GlassmorphicCard(
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
                    const SizedBox(height: 8),

                    // Participants Filter/Custom Split Inputs
                    Column(
                      children: _groupMembers.map((m) {
                        final isSelected = _selectedParticipantIds.contains(m.id);
                        final isMe = m.name.toLowerCase() == widget.controller.currentUserName.toLowerCase();
                        
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              // Selection Checkbox/Switch
                              Checkbox(
                                value: isSelected,
                                activeColor: AppTheme.primary,
                                onChanged: (val) {
                                  _toggleParticipant(m.id);
                                },
                              ),
                              Expanded(
                                child: Text(
                                  m.name + (isMe ? " (You)" : ""),
                                  style: TextStyle(
                                    color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              // Amount display or text input
                              if (isSelected) ...[
                                if (_splitEqually)
                                  Text(
                                    "${widget.controller.currency}${sharePerPerson.toStringAsFixed(2)}",
                                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                                  )
                                else
                                  SizedBox(
                                    width: 100,
                                    height: 38,
                                    child: TextFormField(
                                      controller: _customSplitControllers[m.id],
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                                      decoration: InputDecoration(
                                        prefixText: widget.controller.currency,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                    if (_selectedParticipantIds.isNotEmpty && _amount > 0 && _splitEqually) ...[
                      const Divider(color: AppTheme.border),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Each pays:",
                              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                            ),
                            Text(
                              "${widget.controller.currency}${sharePerPerson.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.accentGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text("Add Expense"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
