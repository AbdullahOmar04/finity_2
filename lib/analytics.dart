// lib/budget_page.dart

// ignore_for_file: deprecated_member_use

import 'package:finity_2/utlis/logo_mapper.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AnalyticsPageState createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _uid;
  List<BudgetItem> _incomes = [];
  List<BudgetItem> _fixedExpenses = [];
  List<VariableExpense> _variableExpenses = [];

  List<String> _smartTips = [];
  bool _isGeneratingTips = false;
  String _tipsError = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    if (!mounted) return;
    if (_uid == null) return;
    final doc = FirebaseFirestore.instance.collection('users').doc(_uid);
    final snap = await doc.get();
    if (!mounted) return;
    final data = snap.data() ?? {};

    final incomesData = (data['incomes'] as List<dynamic>?) ?? [];
    final fixedData = (data['fixedExpenses'] as List<dynamic>?) ?? [];
    final varData = (data['variableExpenses'] as List<dynamic>?) ?? [];

    setState(() {
      _incomes =
          incomesData
              .cast<Map<String, dynamic>>()
              .map(BudgetItem.fromMap)
              .toList();
      _fixedExpenses =
          fixedData
              .cast<Map<String, dynamic>>()
              .map(BudgetItem.fromMap)
              .toList();
      _variableExpenses =
          varData
              .cast<Map<String, dynamic>>()
              .map(VariableExpense.fromMap)
              .toList();
    });
    _generateSmartTips();
  }

  Future<void> _saveBudget() async {
    if (_uid == null) return;
    final doc = FirebaseFirestore.instance.collection('users').doc(_uid);
    if (!mounted) return;
    await doc.update({
      'incomes': _incomes.map((i) => i.toMap()).toList(),
      'fixedExpenses': _fixedExpenses.map((e) => e.toMap()).toList(),
      'variableExpenses': _variableExpenses.map((v) => v.toMap()).toList(),
    });
    _generateSmartTips();
  }

  Future<void> _generateSmartTips() async {
    // Prevent API calls if there's no data
    if (!mounted) return;

    if (_incomes.isEmpty &&
        _fixedExpenses.isEmpty &&
        _variableExpenses.isEmpty) {
      if (!mounted) return;
      setState(() {
        _smartTips = [
          "Add income and expenses to receive personalized tips! ✨",
        ];
      });
      return;
    }
    if (mounted) {
      setState(() {
        _isGeneratingTips = true;
        _tipsError = '';
        _smartTips = []; // Clear old tips
      });
    }

    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      if (mounted) {
        setState(() {
          _tipsError = 'Error: API Key is not configured.';
          _isGeneratingTips = false;
        });
      }
      return;
    }

    final model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: apiKey,
    );

    final totalIncome = _incomes.fold(0.0, (s, i) => s + i.amount);
    final totalFixed = _fixedExpenses.fold(0.0, (s, e) => s + e.amount);
    final totalVariable = _variableExpenses.fold(0.0, (s, v) => s + v.amount);
    final savings = totalIncome - totalFixed - totalVariable;

    final prompt = """
    You are a friendly and encouraging financial assistant for a mobile app called Finity.
    Analyze the following monthly budget data for a user in Jordan (currency is JOD).

    - Total Monthly Income: ${totalIncome.toStringAsFixed(2)} JOD
    - Total Fixed Expenses: ${totalFixed.toStringAsFixed(2)} JOD
    - Total Variable Expenses: ${totalVariable.toStringAsFixed(2)} JOD
    - Monthly Savings: ${savings.toStringAsFixed(2)} JOD

    Based on this data, provide 3 short, actionable, and encouraging financial tips. Use emojis.
    Each tip must be on a new line. Do not include any other text, titles, or introductions.
    For example:
    💡 Your savings rate is looking great! Keep it up.
    Consider creating a small emergency fund. 🏦
    Review your 'Dining Out' expenses to save more. 🍔
    """;

    try {
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      final generatedTips =
          response.text
              ?.split('\n')
              .where((tip) => tip.trim().isNotEmpty) // Filter out empty lines
              .toList() ??
          [];

      if (!mounted) return;
      setState(() {
        _smartTips = generatedTips;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tipsError = 'Could not generate tips. Please try again later.';
        print('Gemini API Error: $e');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isGeneratingTips = false;
      });
    }
  }

  // Enhanced dialog with blue theme
  Future<BudgetItem?> _showBudgetItemDialog({
    required String title,
    BudgetItem? initial,
  }) {
    final nameCtl = TextEditingController(text: initial?.name);
    final amtCtl = TextEditingController(
      text: initial != null ? initial.amount.toString() : '',
    );
    return showDialog<BudgetItem>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: nameCtl,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: amtCtl,
                    decoration: InputDecoration(
                      labelText: 'Amount (JD)',
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameCtl.text.trim();
                  final amt = double.tryParse(amtCtl.text.trim()) ?? 0;
                  if (name.isNotEmpty && amt > 0) {
                    Navigator.pop(ctx, BudgetItem(name: name, amount: amt));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Save'),
              ),
            ],
          ),
    );
  }

  // Income functions
  Future<void> _addIncome() async {
    if (!mounted) return;
    final result = await _showBudgetItemDialog(title: 'Add Income');
    if (result != null) {
      setState(() => _incomes.add(result));
      await _saveBudget();
    }
  }

  Future<void> _editIncome(int index) async {
    if (!mounted) return;
    final orig = _incomes[index];
    final result = await _showBudgetItemDialog(
      title: 'Edit Income',
      initial: orig,
    );
    if (result != null) {
      setState(() => _incomes[index] = result);
      await _saveBudget();
    }
  }

  Future<void> _removeIncome(int index) async {
    if (!mounted) return;
    final toRemove = _incomes[index];
    final ok = await _showConfirmDialog(
      'Delete Income?',
      'Remove "${toRemove.name}" of ${toRemove.amount.toStringAsFixed(2)} JD?',
    );
    if (ok == true) {
      setState(() => _incomes.removeAt(index));
      await _saveBudget();
    }
  }

  // Fixed expense functions
  Future<void> _addFixedExpense() async {
    if (!mounted) return;
    final result = await _showBudgetItemDialog(title: 'Add Fixed Expense');
    if (result != null) {
      setState(() => _fixedExpenses.add(result));
      await _saveBudget();
    }
  }

  Future<void> _editFixedExpense(int index) async {
    if (!mounted) return;
    final orig = _fixedExpenses[index];
    final result = await _showBudgetItemDialog(
      title: 'Edit Fixed Expense',
      initial: orig,
    );
    if (result != null) {
      setState(() => _fixedExpenses[index] = result);
      await _saveBudget();
    }
  }

  Future<void> _removeFixedExpense(int index) async {
    if (!mounted) return;
    final toRem = _fixedExpenses[index];
    final ok = await _showConfirmDialog(
      'Delete Fixed Expense?',
      'Remove "${toRem.name}" of ${toRem.amount.toStringAsFixed(2)} JD?',
    );
    if (ok == true) {
      setState(() => _fixedExpenses.removeAt(index));
      await _saveBudget();
    }
  }

  // Enhanced variable expense dialog
  Future<VariableExpense?> _showVariableDialog({VariableExpense? initial}) {
    final catCtl = TextEditingController(text: initial?.category);
    final amtCtl = TextEditingController(
      text: initial != null ? initial.amount.toString() : '',
    );
    DateTime date = initial?.date ?? DateTime.now();

    return showDialog<VariableExpense>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setState) {
              return AlertDialog(
                scrollable: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  initial == null ? 'Add Expense' : 'Edit Expense',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: catCtl,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: amtCtl,
                        decoration: InputDecoration(
                          labelText: 'Amount (JD)',
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat.yMMMd().format(date),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.calendar_today,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onPressed: () async {
                              if (!mounted) return;
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: date,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) setState(() => date = picked);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final cat = catCtl.text.trim();
                      final amt = double.tryParse(amtCtl.text.trim()) ?? 0;
                      if (cat.isNotEmpty && amt > 0) {
                        Navigator.pop(
                          ctx,
                          VariableExpense(
                            category: cat,
                            amount: amt,
                            date: date,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Save'),
                  ),
                ],
              );
            },
          ),
    );
  }

  // Variable expense functions
  Future<void> _addVariableExpense() async {
    if (!mounted) return;
    final result = await _showVariableDialog();
    if (result != null) {
      setState(() => _variableExpenses.add(result));
      await _saveBudget();
    }
  }

  Future<void> _editVariableExpense(int index) async {
    if (!mounted) return;
    final orig = _variableExpenses[index];
    final result = await _showVariableDialog(initial: orig);
    if (result != null) {
      setState(() => _variableExpenses[index] = result);
      await _saveBudget();
    }
  }

  Future<void> _removeVariableExpense(int index) async {
    if (!mounted) return;
    final toRem = _variableExpenses[index];
    final ok = await _showConfirmDialog(
      'Delete Expense?',
      'Remove ${toRem.category} of ${toRem.amount.toStringAsFixed(2)} JD?',
    );
    if (ok == true) {
      setState(() => _variableExpenses.removeAt(index));
      await _saveBudget();
    }
  }

  // Enhanced confirmation dialog
  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Delete'),
              ),
            ],
          ),
    );
  }

  // Enhanced list builder with beautiful cards
  Widget _buildList<T>({
    required List<T> items,
    required Widget Function(int index, T item) itemBuilder,
    required VoidCallback onAdd,
    required String emptyMessage,
    required IconData addIcon,
    required String addLabel,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.surface.withOpacity(0.1),
            Theme.of(context).colorScheme.onPrimary,
          ],
        ),
      ),
      child: Column(
        children: [
          if (items.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      addIcon,
                      size: 64,
                      color: Theme.of(
                        context,
                      ).colorScheme.tertiary.withOpacity(0.5),
                    ),
                    SizedBox(height: 16),
                    Text(
                      emptyMessage,
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder:
                    (ctx, i) => Container(
                      margin: EdgeInsets.only(bottom: 12),
                      child: itemBuilder(i, items[i]),
                    ),
              ),
            ),
          Container(
            padding: EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: onAdd,
              icon: Icon(addIcon),
              label: Text(addLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                minimumSize: Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced slidable card widget for list items
  Widget _buildSlidableCard({
    required String title,
    required String amount,
    String? subtitle,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    IconData? icon,
  }) {
    return Slidable(
      key: ValueKey(title + amount),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Edit',
            borderRadius: BorderRadius.circular(12),
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.onPrimary,
                Theme.of(context).colorScheme.surface.withOpacity(0.1),
              ],
            ),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.all(16),
            leading:
                icon != null
                    ? Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                    : null,
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
            subtitle:
                subtitle != null
                    ? Text(subtitle, style: TextStyle(color: Colors.grey[600]))
                    : null,
            trailing: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                amount,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalIncome = _incomes.fold(0.0, (s, i) => s + i.amount);
    final totalFixed = _fixedExpenses.fold(0.0, (s, e) => s + e.amount);
    final totalVariable = _variableExpenses.fold(0.0, (s, v) => s + v.amount);
    final savingsRate =
        totalIncome > 0
            ? (totalIncome - totalFixed - totalVariable) / totalIncome * 100
            : 0.0;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Monthly Budget',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(context).colorScheme.onPrimary,
          tabs: [
            Tab(text: 'Income', icon: Icon(Icons.attach_money)),
            Tab(text: 'Recurring', icon: Icon(Icons.home)),
            Tab(text: 'Variable', icon: Icon(Icons.shopping_cart)),
            Tab(text: 'Summary', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Income Tab
          _buildList<BudgetItem>(
            items: _incomes,
            onAdd: _addIncome,
            emptyMessage: 'No income sources yet.\nAdd your first income!',
            addIcon: Icons.add_circle,
            addLabel: 'Add Income',
            itemBuilder:
                (i, item) => _buildSlidableCard(
                  title: item.name,
                  amount: '${item.amount.toStringAsFixed(2)} JD',
                  icon: Icons.attach_money,
                  onEdit: () => _editIncome(i),
                  onDelete: () => _removeIncome(i),
                ),
          ),

          // Fixed Expenses Tab
          _buildList<BudgetItem>(
            items: _fixedExpenses,
            onAdd: _addFixedExpense,
            emptyMessage: 'No fixed expenses yet.\nAdd your monthly bills!',
            addIcon: Icons.add_circle,
            addLabel: 'Add Fixed Expense',
            itemBuilder:
                (i, item) => _buildSlidableCard(
                  title: item.name,
                  amount: '${item.amount.toStringAsFixed(2)} JD',
                  icon: iconForFixedExpense(item.name),
                  onEdit: () => _editFixedExpense(i),
                  onDelete: () => _removeFixedExpense(i),
                ),
          ),

          // Variable Expenses Tab
          _buildList<VariableExpense>(
            items: _variableExpenses,
            onAdd: _addVariableExpense,
            emptyMessage: 'No variable expenses yet.\nTrack your spending!',
            addIcon: Icons.add_circle,
            addLabel: 'Add Expense',
            itemBuilder:
                (i, item) => _buildSlidableCard(
                  title: item.category,
                  amount: '${item.amount.toStringAsFixed(2)} JD',
                  subtitle: DateFormat.yMMMd().format(item.date),
                  icon: iconForVariableExpense(item.category),
                  onEdit: () => _editVariableExpense(i),
                  onDelete: () => _removeVariableExpense(i),
                ),
          ),

          // Summary Tab
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.surface.withOpacity(0.1),
                  Theme.of(context).colorScheme.onPrimary,
                ],
              ),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Summary Cards
                  _buildSummaryCard(
                    'Total Income',
                    '${totalIncome.toStringAsFixed(2)} JD',
                    Icons.trending_up,
                    Colors.green,
                  ),
                  SizedBox(height: 12),
                  _buildSummaryCard(
                    'Fixed Expenses',
                    '${totalFixed.toStringAsFixed(2)} JD',
                    Icons.home,
                    Colors.orange,
                  ),
                  SizedBox(height: 12),
                  _buildSummaryCard(
                    'Variable Expenses',
                    '${totalVariable.toStringAsFixed(2)} JD',
                    Icons.shopping_cart,
                    Colors.blue,
                  ),
                  SizedBox(height: 12),
                  _buildSummaryCard(
                    'Savings Rate',
                    '${savingsRate.toStringAsFixed(1)}%',
                    Icons.savings,
                    savingsRate < 20 ? Colors.red : Colors.green,
                  ),
                  SizedBox(height: 24),

                  // Tips Section
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.05),
                            Theme.of(
                              context,
                            ).colorScheme.surface.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: Colors.orangeAccent,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Smart Financial Tips',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Theme.of(context).colorScheme.tertiary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),

                          if (_isGeneratingTips)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (_tipsError.isNotEmpty)
                            _buildTipItem(_tipsError, Colors.red)
                          else
                            ..._smartTips
                                .map(
                                  (tip) => _buildTipItem(
                                    tip,
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                )
                                .toList(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String amount,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.onPrimary,
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    amount,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String tip, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        tip,
        style: TextStyle(color: color.withOpacity(0.8), fontSize: 14),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class BudgetItem {
  final String name;
  final double amount;
  BudgetItem({required this.name, required this.amount});

  Map<String, dynamic> toMap() => {'name': name, 'amount': amount};

  static BudgetItem fromMap(Map<String, dynamic> m) => BudgetItem(
    name: m['name'] as String,
    amount: (m['amount'] as num).toDouble(),
  );
}

class VariableExpense {
  final String category;
  final double amount;
  final DateTime date;
  VariableExpense({
    required this.category,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'category': category,
    'amount': amount,
    'date': Timestamp.fromDate(date),
  };

  static VariableExpense fromMap(Map<String, dynamic> m) => VariableExpense(
    category: m['category'] as String,
    amount: (m['amount'] as num).toDouble(),
    date: (m['date'] as Timestamp).toDate(),
  );
}
