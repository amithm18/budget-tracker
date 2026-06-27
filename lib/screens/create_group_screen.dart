import 'package:flutter/material.dart';
import '../controllers/budget_controller.dart';
import '../theme/app_theme.dart';

class CreateGroupScreen extends StatefulWidget {
  final BudgetController controller;

  const CreateGroupScreen({super.key, required this.controller});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _memberInputController = TextEditingController();
  final List<String> _membersList = [];
  DateTime? _selectedDueDate;

  @override
  void initState() {
    super.initState();
    // Pre-populate with current user's name to make it easier for them
    final user = widget.controller.currentUserName.trim();
    if (user.isNotEmpty) {
      _membersList.add(user);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _memberInputController.dispose();
    super.dispose();
  }

  void _addMember() {
    final name = _memberInputController.text.trim();
    if (name.isEmpty) return;

    if (_membersList.any((m) => m.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Member already added!")),
      );
      return;
    }

    setState(() {
      _membersList.add(name);
      _memberInputController.clear();
    });
  }

  void _removeMember(int index) {
    setState(() {
      _membersList.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_membersList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one member to the group.")),
      );
      return;
    }

    try {
      await widget.controller.createGroup(
        _nameController.text.trim(),
        _membersList,
        dueDate: _selectedDueDate,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Group '${_nameController.text}' created successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error creating group: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Group"),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group Name Input
              const Text(
                "Group Details",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryLight,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: "Group Name",
                  hintText: "e.g., Roommates, Paris Trip, Dinner Club",
                  prefixIcon: Icon(Icons.group_work, color: AppTheme.primaryLight),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter a group name";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Settle-up Deadline Date Picker
              const Text(
                "Settlement Deadline (Optional)",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryLight,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppTheme.primary,
                            onPrimary: Colors.white,
                            surface: AppTheme.bgSurface,
                            onSurface: AppTheme.textPrimary,
                          ),
                          textButtonTheme: TextButtonThemeData(
                            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryLight),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDueDate = picked;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border, width: 1.2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_month, color: AppTheme.primaryLight),
                          const SizedBox(width: 12),
                          Text(
                            _selectedDueDate == null
                                ? "No Deadline Set"
                                : "${_selectedDueDate!.day}/${_selectedDueDate!.month}/${_selectedDueDate!.year}",
                            style: TextStyle(
                              color: _selectedDueDate == null ? AppTheme.textSecondary : AppTheme.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      if (_selectedDueDate != null)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDueDate = null;
                            });
                          },
                          child: const Icon(Icons.clear, color: AppTheme.textSecondary, size: 20),
                        )
                      else
                        const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Group Members Header
              const Text(
                "Add Group Members",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryLight,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Members will share expenses in this group.",
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),

              // Member input row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _memberInputController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: "Member Name",
                        hintText: "Enter name",
                        prefixIcon: Icon(Icons.person, color: AppTheme.textSecondary),
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
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: _addMember,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Note about Current User
              if (!_membersList.any((m) => m.toLowerCase() == widget.controller.currentUserName.toLowerCase()))
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: AppTheme.primaryLight, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Tip: Add '${widget.controller.currentUserName}' to track your personal share in this group.",
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _membersList.add(widget.controller.currentUserName);
                          });
                        },
                        child: const Text("Add Me"),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Members List chips
              const Text(
                "Current Members:",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              if (_membersList.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      "No members added yet.",
                      style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: List.generate(_membersList.length, (index) {
                    final memberName = _membersList[index];
                    final isMe = memberName.toLowerCase() == widget.controller.currentUserName.toLowerCase();
                    return Chip(
                      label: Text(
                        memberName + (isMe ? " (You)" : ""),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: isMe ? AppTheme.primary : AppTheme.bgSurfaceLight,
                      deleteIconColor: Colors.white70,
                      onDeleted: () => _removeMember(index),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isMe ? AppTheme.primaryLight : AppTheme.border,
                        ),
                      ),
                    );
                  }),
                ),

              const SizedBox(height: 40),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text("Create Group"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
