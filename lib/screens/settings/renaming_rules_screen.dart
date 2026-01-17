import 'package:flutter/material.dart';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/models/renaming_rule.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:another_iptv_player/services/renaming_service.dart';

class RenamingRulesScreen extends StatefulWidget {
  const RenamingRulesScreen({super.key});

  @override
  State<RenamingRulesScreen> createState() => _RenamingRulesScreenState();
}

class _RenamingRulesScreenState extends State<RenamingRulesScreen> {
  List<RenamingRule> _rules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    final rules = await UserPreferences.getRenamingRules();
    setState(() {
      _rules = rules;
      _isLoading = false;
    });
  }

  Future<void> _addRule() async {
    final result = await showDialog<RenamingRule>(
      context: context,
      builder: (context) => const RuleEditorDialog(),
    );
    if (result != null) {
      await UserPreferences.addRenamingRule(result);
      RenamingService().invalidateCache();
      await RenamingService().loadRules();
      _loadRules();
    }
  }

  Future<void> _editRule(RenamingRule rule) async {
    final result = await showDialog<RenamingRule>(
      context: context,
      builder: (context) => RuleEditorDialog(rule: rule),
    );
    if (result != null) {
      await UserPreferences.updateRenamingRule(result);
      RenamingService().invalidateCache();
      await RenamingService().loadRules();
      _loadRules();
    }
  }

  Future<void> _deleteRule(RenamingRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.loc.delete),
        content: const Text('Delete this renaming rule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.loc.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await UserPreferences.deleteRenamingRule(rule.id);
      RenamingService().invalidateCache();
      await RenamingService().loadRules();
      _loadRules();
    }
  }

  Future<void> _toggleRule(RenamingRule rule) async {
    await UserPreferences.toggleRenamingRule(rule.id);
    RenamingService().invalidateCache();
    await RenamingService().loadRules();
    _loadRules();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Renaming Rules'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRule,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rules.isEmpty
              ? _buildEmptyState()
              : _buildRulesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.find_replace, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No renaming rules yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create a rule',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rules.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final rule = _rules[index];
        return _buildRuleCard(rule, index);
      },
    );
  }

  Widget _buildRuleCard(RenamingRule rule, int index) {
    return Card(
      key: ValueKey(rule.id),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          rule.isEnabled ? Icons.check_circle : Icons.circle_outlined,
          color: rule.isEnabled ? Colors.green : Colors.grey,
        ),
        title: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              TextSpan(
                text: '"${rule.findText}"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' → '),
              TextSpan(
                text: rule.replaceText.isEmpty
                    ? '(remove)'
                    : '"${rule.replaceText}"',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: rule.replaceText.isEmpty ? Colors.red : null,
                ),
              ),
            ],
          ),
        ),
        subtitle: Text(
          '${_getAppliesToLabel(rule.appliesTo)}${rule.fullWordsOnly ? ' • Full words only' : ''}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _editRule(rule),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              onPressed: () => _deleteRule(rule),
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            ),
          ],
        ),
        onTap: () => _toggleRule(rule),
      ),
    );
  }

  String _getAppliesToLabel(RuleAppliesTo appliesTo) {
    switch (appliesTo) {
      case RuleAppliesTo.all:
        return 'All content';
      case RuleAppliesTo.categories:
        return 'Categories';
      case RuleAppliesTo.liveStream:
        return 'Live streams';
      case RuleAppliesTo.vod:
        return 'Movies';
      case RuleAppliesTo.series:
        return 'Series';
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final rule = _rules.removeAt(oldIndex);
      _rules.insert(newIndex, rule);
    });
    await UserPreferences.setRenamingRules(_rules);
    RenamingService().invalidateCache();
    await RenamingService().loadRules();
  }
}

/// Dialog for creating/editing a renaming rule
class RuleEditorDialog extends StatefulWidget {
  final RenamingRule? rule;

  const RuleEditorDialog({super.key, this.rule});

  @override
  State<RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<RuleEditorDialog> {
  late TextEditingController _findController;
  late TextEditingController _replaceController;
  late bool _fullWordsOnly;
  late RuleAppliesTo _appliesTo;

  bool get _isEditing => widget.rule != null;

  @override
  void initState() {
    super.initState();
    _findController = TextEditingController(text: widget.rule?.findText ?? '');
    _replaceController =
        TextEditingController(text: widget.rule?.replaceText ?? '');
    _fullWordsOnly = widget.rule?.fullWordsOnly ?? false;
    _appliesTo = widget.rule?.appliesTo ?? RuleAppliesTo.all;
  }

  @override
  void dispose() {
    _findController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  void _save() {
    if (_findController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Find text is required')),
      );
      return;
    }

    final rule = RenamingRule(
      id: widget.rule?.id ?? RenamingRule.generateId(),
      findText: _findController.text,
      replaceText: _replaceController.text,
      fullWordsOnly: _fullWordsOnly,
      appliesTo: _appliesTo,
      isEnabled: widget.rule?.isEnabled ?? true,
      createdAt: widget.rule?.createdAt,
    );

    Navigator.pop(context, rule);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Rule' : 'Add Rule'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _findController,
              decoration: const InputDecoration(
                labelText: 'Find text',
                hintText: 'e.g., (%DATE%) or [%WORD%]',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Pattern placeholders', style: TextStyle(fontSize: 13)),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                _buildPlaceholderHelp('%DATE%', 'Matches 4-digit year (2022)'),
                _buildPlaceholderHelp('%NUM%', 'Matches any number'),
                _buildPlaceholderHelp('%WORD%', 'Matches a single word'),
                _buildPlaceholderHelp('%ANY%', 'Matches anything'),
                const SizedBox(height: 4),
                Text(
                  'Example: "(%DATE%)" removes "(2022)"',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _replaceController,
              decoration: const InputDecoration(
                labelText: 'Replace with',
                hintText: 'Leave empty to remove',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Full words only'),
              subtitle: const Text('Match whole words only'),
              value: _fullWordsOnly,
              onChanged: (v) => setState(() => _fullWordsOnly = v ?? false),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            const Text('Applies to:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<RuleAppliesTo>(
              value: _appliesTo,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: RuleAppliesTo.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getAppliesToLabel(type)),
                );
              }).toList(),
              onChanged: (v) =>
                  setState(() => _appliesTo = v ?? RuleAppliesTo.all),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.loc.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  String _getAppliesToLabel(RuleAppliesTo appliesTo) {
    switch (appliesTo) {
      case RuleAppliesTo.all:
        return 'All content';
      case RuleAppliesTo.categories:
        return 'Categories only';
      case RuleAppliesTo.liveStream:
        return 'Live streams only';
      case RuleAppliesTo.vod:
        return 'Movies only';
      case RuleAppliesTo.series:
        return 'Series only';
    }
  }

  Widget _buildPlaceholderHelp(String placeholder, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              placeholder,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}
