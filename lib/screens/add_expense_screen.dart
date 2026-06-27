import 'package:flutter/material.dart';
import '../controllers/budget_controller.dart';
import '../models/member.dart';
import '../theme/app_theme.dart';

class AddExpenseScreen extends StatefulWidget {
  final BudgetController controller;
  final String groupId;

  const AddExpenseScreen({
    super.key,
    required this.controller,
    required this.groupId,
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

  @override
  void initState() {
    super.initState();
    _groupMembers = widget.controller.getMembersForGroup(widget.groupId);

    // Default payer is the current user if they are in the group, otherwise the first member
    final currentUserMember = _groupMembers.firstWhere(
      (m) => m.name.toLowerCase() == widget.controller.currentUserName.toLowerCase(),
      orElse: () => _groupMembers.isNotEmpty ? _groupMembers.first : Member(id: '', name: '', groupId: ''),
    );

    if (currentUserMember.id.isNotEmpty) {
      _selectedPayerId = currentUserMember.id;
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
    super.dispose();
  }

  void _onAmountChanged() {
    final parsed = double.tryParse(_amountController.text);
    setState(() {
      _amount = parsed ?? 0.0;
    });
  }

  void _toggleParticipant(String memberId) {
    setState(() {
      if (_selectedParticipantIds.contains(memberId)) {
        _selectedParticipantIds.remove(memberId);
      } else {
        _selectedParticipantIds.add(memberId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedParticipantIds.clear();
      _selectedParticipantIds.addAll(_groupMembers.map((m) => m.id));
    });
  }

  void _selectNone() {
    setState(() {
      _selectedParticipantIds.clear();
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

    try {
      await widget.controller.addExpenseToGroup(
        groupId: widget.groupId,
        title: _titleController.text.trim(),
        amount: _amount,
        paidByMemberId: _selectedPayerId!,
        participantIds: _selectedParticipantIds,
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
                      const SizedBox(height: 8),

                      // Participants Filter Chips
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: _groupMembers.map((m) {
                          final isSelected = _selectedParticipantIds.contains(m.id);
                          final isMe = m.name.toLowerCase() == widget.controller.currentUserName.toLowerCase();
                          return FilterChip(
                            label: Text(m.name + (isMe ? " (You)" : "")),
                            selected: isSelected,
                            onSelected: (_) => _toggleParticipant(m.id),
                            selectedColor: AppTheme.primary,
                            checkmarkColor: Colors.white,
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
                          );
                        }).toList(),
                      ),

                      if (_selectedParticipantIds.isNotEmpty && _amount > 0) ...[
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
