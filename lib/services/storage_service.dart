import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group.dart';
import '../models/member.dart';
import '../models/expense.dart';

class StorageService {
  // Replace these with your actual Supabase URL and Anon Key!
  static const String supabaseUrl = 'https://uhzxgbhsgsllzfibapeu.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVoenhnYmhzZ3NsbHpmaWJhcGV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM1Nzc0ODYsImV4cCI6MjA5OTE1MzQ4Nn0.BrkLOdJFffvStk4CsSyCXKefT4ZQvqoCWbleWewUDSQ';

  late Box _settingsBox;

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> init() async {
    await Hive.initFlutter();
    _settingsBox = await Hive.openBox('settings');
  }

  String getCurrentUserName() {
    return _settingsBox.get('currentUserName', defaultValue: '') as String;
  }

  Future<void> setCurrentUserName(String name) async {
    await _settingsBox.put('currentUserName', name);
  }

  String getCurrency() {
    return _settingsBox.get('currency', defaultValue: '₹') as String;
  }

  Future<void> setCurrency(String symbol) async {
    await _settingsBox.put('currency', symbol);
  }

  // --- Group Operations ---
  Future<List<Group>> getGroups() async {
    try {
      final userName = getCurrentUserName().trim().toLowerCase();
      if (userName.isEmpty) return [];

      // 1. Fetch group IDs where the current user is a member
      final membersResponse = await _supabase
          .from('members')
          .select('group_id')
          .ilike('name', userName);

      final List<String> userGroupIds = (membersResponse as List)
          .map((m) => m['group_id'] as String)
          .toList();

      if (userGroupIds.isEmpty) return [];

      // 2. Fetch the corresponding groups
      final response = await _supabase
          .from('groups')
          .select()
          .inFilter('id', userGroupIds);

      return (response as List).map((val) => Group.fromMap(val)).toList();
    } catch (e) {
      debugPrint("Error fetching groups: $e");
      return [];
    }
  }

  Future<Group?> getGroupByCode(String groupCode) async {
    try {
      final response = await _supabase
          .from('groups')
          .select()
          .like('id', '${groupCode.toLowerCase()}%');
      
      if ((response as List).isEmpty) return null;
      return Group.fromMap(response.first);
    } catch (e) {
      debugPrint("Error fetching group by code: $e");
      return null;
    }
  }

  Future<List<Member>> getMembersOfGroup(String groupId) async {
    try {
      final response = await _supabase.from('members').select().eq('group_id', groupId);
      return (response as List).map((val) => Member.fromMap(val)).toList();
    } catch (e) {
      debugPrint("Error fetching members of group: $e");
      return [];
    }
  }

  Future<void> saveGroup(Group group) async {
    try {
      await _supabase.from('groups').upsert(group.toSupabaseMap());
    } catch (e) {
      debugPrint("Error saving group: $e");
      rethrow;
    }
  }

  Future<void> deleteGroup(String groupId) async {
    try {
      // PostgreSQL cascade delete will clean up associated members & expenses automatically
      await _supabase.from('groups').delete().eq('id', groupId);
    } catch (e) {
      debugPrint("Error deleting group: $e");
      rethrow;
    }
  }

  // --- Member Operations ---
  Future<List<Member>> getMembers() async {
    try {
      final userName = getCurrentUserName().trim().toLowerCase();
      if (userName.isEmpty) return [];

      // 1. Fetch group IDs where the current user is a member
      final membersResponse = await _supabase
          .from('members')
          .select('group_id')
          .ilike('name', userName);

      final List<String> userGroupIds = (membersResponse as List)
          .map((m) => m['group_id'] as String)
          .toList();

      if (userGroupIds.isEmpty) return [];

      // 2. Fetch members belonging to those groups
      final response = await _supabase
          .from('members')
          .select()
          .inFilter('group_id', userGroupIds);

      return (response as List).map((val) => Member.fromMap(val)).toList();
    } catch (e) {
      debugPrint("Error fetching members: $e");
      return [];
    }
  }

  Future<void> saveMember(Member member) async {
    try {
      await _supabase.from('members').upsert(member.toSupabaseMap());
    } catch (e) {
      debugPrint("Error saving member: $e");
      rethrow;
    }
  }

  Future<void> deleteMember(String memberId) async {
    try {
      await _supabase.from('members').delete().eq('id', memberId);
    } catch (e) {
      debugPrint("Error deleting member: $e");
      rethrow;
    }
  }

  // --- Expense Operations ---
  Future<List<Expense>> getExpenses() async {
    try {
      final userName = getCurrentUserName().trim().toLowerCase();
      if (userName.isEmpty) return [];

      // 1. Fetch group IDs where the current user is a member
      final membersResponse = await _supabase
          .from('members')
          .select('group_id')
          .ilike('name', userName);

      final List<String> userGroupIds = (membersResponse as List)
          .map((m) => m['group_id'] as String)
          .toList();

      if (userGroupIds.isEmpty) return [];

      // 2. Fetch expenses belonging to those groups
      final response = await _supabase
          .from('expenses')
          .select()
          .inFilter('group_id', userGroupIds);

      return (response as List).map((val) => Expense.fromMap(val)).toList();
    } catch (e) {
      debugPrint("Error fetching expenses: $e");
      return [];
    }
  }

  Future<void> saveExpense(Expense expense) async {
    try {
      await _supabase.from('expenses').upsert(expense.toSupabaseMap());
    } catch (e) {
      debugPrint("Error saving expense: $e");
      rethrow;
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    try {
      await _supabase.from('expenses').delete().eq('id', expenseId);
    } catch (e) {
      debugPrint("Error deleting expense: $e");
      rethrow;
    }
  }

  // Clear all local data and empty the remote tables (useful for reset)
  Future<void> clearAll() async {
    await _settingsBox.clear();
    try {
      // Deleting all rows from groups will cascade delete all members and expenses
      await _supabase.from('groups').delete().neq('id', 'dummy');
    } catch (e) {
      debugPrint("Error clearing remote database: $e");
    }
  }
}
