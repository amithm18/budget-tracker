import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  String _selectedAvatarPreset = '0'; // Default avatar preset
  XFile? _selectedGroupPhoto; // Custom picked group photo

  // Preset Gradients
  final List<Gradient> _avatarGradients = [
    const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF0EA5E9)]), // Blue/Indigo
    const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]), // Green
    const LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFE11D48)]), // Rose
    const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]), // Purple/Pink
    const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]), // Amber/Orange
  ];

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

  Future<void> _pickGroupPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 600, maxHeight: 600);
      if (picked != null) {
        setState(() {
          _selectedGroupPhoto = picked;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not access photo: $e")),
      );
    }
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
        imageUrl: _selectedGroupPhoto != null ? _selectedGroupPhoto!.path : _selectedAvatarPreset,
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
              // Custom Photo Upload Option
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: AppTheme.bgSurface,
                          builder: (context) {
                            return SafeArea(
                              child: Wrap(
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.photo_library, color: AppTheme.primaryLight),
                                    title: const Text("Choose from Gallery"),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _pickGroupPhoto(ImageSource.gallery);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.camera_alt, color: AppTheme.secondary),
                                    title: const Text("Take Photo with Camera"),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _pickGroupPhoto(ImageSource.camera);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.bgSurfaceLight,
                          border: Border.all(color: AppTheme.primaryLight, width: 2),
                          image: _selectedGroupPhoto != null
                              ? DecorationImage(
                                  image: kIsWeb
                                      ? NetworkImage(_selectedGroupPhoto!.path) as ImageProvider
                                      : FileImage(File(_selectedGroupPhoto!.path)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _selectedGroupPhoto == null
                            ? const Icon(
                                Icons.add_a_photo,
                                color: AppTheme.textSecondary,
                                size: 30,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Upload Custom Group Photo",
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Group Avatar Preset Selector
              const Text(
                "Choose Group Photo Preset",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryLight,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _avatarGradients.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedAvatarPreset == index.toString();
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedAvatarPreset = index.toString();
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _avatarGradients[index],
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: Colors.white.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 28)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

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
