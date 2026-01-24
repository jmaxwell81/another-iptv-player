import 'package:flutter/material.dart';
import '../../models/auto_combine_rule.dart';
import '../../services/auto_combine_service.dart';
import '../../services/name_tag_cleaner_service.dart';

/// Settings section for auto-combine category rules
class AutoCombineSettingsSection extends StatefulWidget {
  const AutoCombineSettingsSection({super.key});

  @override
  State<AutoCombineSettingsSection> createState() => _AutoCombineSettingsSectionState();
}

class _AutoCombineSettingsSectionState extends State<AutoCombineSettingsSection> {
  final AutoCombineService _service = AutoCombineService();
  final NameTagCleanerService _tagCleanerService = NameTagCleanerService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    await _service.initialize();
    await _tagCleanerService.initialize();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final config = _service.config;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Main enable switch
        Card(
          child: SwitchListTile(
            title: const Text('Enable Auto-Combine Rules'),
            subtitle: const Text('Automatically merge and filter categories based on rules'),
            value: config.enabled,
            onChanged: (value) async {
              await _service.updateConfig(enabled: value);
              setState(() {});
            },
            secondary: const Icon(Icons.auto_fix_high),
          ),
        ),
        const SizedBox(height: 16),

        // Built-in rules section
        Text(
          'Built-in Rules',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Kids merge rule
        Card(
          child: SwitchListTile(
            title: const Text('Merge KIDS Categories'),
            subtitle: const Text('Combine all categories containing "KIDS", "CHILDREN", etc. into a single "KIDS" category'),
            value: config.mergeKidsCategories,
            onChanged: config.enabled ? (value) async {
              await _service.updateConfig(mergeKidsCategories: value);
              setState(() {});
            } : null,
            secondary: const Icon(Icons.child_care),
          ),
        ),
        const SizedBox(height: 8),

        // Genre merge rule
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Merge Genre Categories'),
                subtitle: const Text('Combine categories by genre (DRAMA, HORROR, DOCUMENTARY, etc.)'),
                value: config.mergeGenreCategories,
                onChanged: config.enabled ? (value) async {
                  await _service.updateConfig(mergeGenreCategories: value);
                  setState(() {});
                } : null,
                secondary: const Icon(Icons.movie_filter),
              ),
              if (config.mergeGenreCategories) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: AutoCombineConfig.defaultGenreKeywords
                        .map((genre) => Chip(
                      label: Text(genre, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ))
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Hide non-English countries rule
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Hide Non-English Countries'),
                subtitle: const Text('Hide categories for non-English speaking countries/regions'),
                value: config.hideNonEnglishCountries,
                onChanged: config.enabled ? (value) async {
                  await _service.updateConfig(hideNonEnglishCountries: value);
                  setState(() {});
                } : null,
                secondary: const Icon(Icons.visibility_off),
              ),
              if (config.hideNonEnglishCountries) ...[
                const Divider(),
                ListTile(
                  title: const Text('English-Speaking Countries (Not Hidden)'),
                  subtitle: Text(
                    config.englishSpeakingCountries.join(', '),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editEnglishCountries(context),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Clean name tags rule
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Clean Name Tags'),
                subtitle: const Text('Remove language/country tags from display names'),
                value: _tagCleanerService.isEnabled,
                onChanged: config.enabled ? (value) async {
                  await _tagCleanerService.setEnabled(value);
                  setState(() {});
                } : null,
                secondary: const Icon(Icons.cleaning_services),
              ),
              if (_tagCleanerService.isEnabled) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Removes redundant tags from content and category names when all content is English/US.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: NameTagCleanerService.removableTags
                            .map((tag) => Chip(
                          label: Text(tag, style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Consolidate live channels rule
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Consolidate Live Channels'),
                subtitle: const Text('Show only one variant per channel (CBS, NBC, ESPN, etc.)'),
                value: config.consolidateLiveChannels,
                onChanged: config.enabled ? (value) async {
                  await _service.updateConfig(consolidateLiveChannels: value);
                  setState(() {});
                } : null,
                secondary: const Icon(Icons.live_tv),
              ),
              if (config.consolidateLiveChannels) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Consolidates duplicate channel variants (e.g., "CBS HD", "CBS SD", "CBS 4K") into a single entry, preferring higher quality.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: ['CBS', 'NBC', 'ABC', 'FOX', 'ESPN', 'CNN', 'HBO', 'TNT', 'TBS', 'USA', '...']
                            .map((ch) => Chip(
                          label: Text(ch, style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Custom rules section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Custom Rules',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: config.enabled ? () => _addCustomRule(context) : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Rule'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (config.customRules.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.rule,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  const Text('No custom rules'),
                  const SizedBox(height: 4),
                  Text(
                    'Add custom rules to merge or hide specific categories',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...config.customRules.map((rule) => _buildCustomRuleCard(rule)),

        const SizedBox(height: 24),

        // Info card
        Card(
          color: Theme.of(context).colorScheme.primaryContainer.withAlpha(77),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text('How it works', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Merge rules combine multiple categories into one\n'
                      '• Hide rules remove categories from the list\n'
                      '• Rules are applied in order: hide first, then merge\n'
                      '• Changes take effect after refreshing categories',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomRuleCard(AutoCombineRule rule) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          rule.type == AutoCombineRuleType.mergeByKeyword
              ? Icons.merge
              : Icons.visibility_off,
          color: rule.enabled
              ? (rule.type == AutoCombineRuleType.mergeByKeyword
              ? Colors.blue
              : Colors.orange)
              : Colors.grey,
        ),
        title: Text(rule.name),
        subtitle: Text(
          rule.type == AutoCombineRuleType.mergeByKeyword
              ? 'Merge → ${rule.targetCategoryName}'
              : 'Hide matching categories',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: rule.enabled,
              onChanged: (value) async {
                await _service.toggleRuleEnabled(rule.id, value);
                setState(() {});
              },
            ),
            PopupMenuButton<String>(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _editCustomRule(context, rule);
                } else if (value == 'delete') {
                  _deleteCustomRule(rule);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editEnglishCountries(BuildContext context) async {
    final controller = TextEditingController(
      text: _service.config.englishSpeakingCountries.join(', '),
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('English-Speaking Countries'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'US, UK, CA, AU, ...',
            helperText: 'Separate with commas',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      final countries = result
          .split(',')
          .map((s) => s.trim().toUpperCase())
          .where((s) => s.isNotEmpty)
          .toList();
      await _service.updateConfig(englishSpeakingCountries: countries);
      setState(() {});
    }
  }

  Future<void> _addCustomRule(BuildContext context) async {
    final rule = await _showRuleDialog(context, null);
    if (rule != null) {
      await _service.addCustomRule(rule);
      setState(() {});
    }
  }

  Future<void> _editCustomRule(BuildContext context, AutoCombineRule rule) async {
    final updated = await _showRuleDialog(context, rule);
    if (updated != null) {
      await _service.updateCustomRule(rule.id, updated);
      setState(() {});
    }
  }

  Future<void> _deleteCustomRule(AutoCombineRule rule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rule'),
        content: Text('Delete rule "${rule.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.removeCustomRule(rule.id);
      setState(() {});
    }
  }

  Future<AutoCombineRule?> _showRuleDialog(BuildContext context, AutoCombineRule? existing) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final patternsController = TextEditingController(text: existing?.patterns.join(', ') ?? '');
    final targetController = TextEditingController(text: existing?.targetCategoryName ?? '');
    var type = existing?.type ?? AutoCombineRuleType.mergeByKeyword;

    return showDialog<AutoCombineRule>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Edit Rule' : 'Add Custom Rule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Rule Name',
                    hintText: 'e.g., Merge Sports',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Rule Type'),
                const SizedBox(height: 8),
                SegmentedButton<AutoCombineRuleType>(
                  segments: const [
                    ButtonSegment(
                      value: AutoCombineRuleType.mergeByKeyword,
                      icon: Icon(Icons.merge),
                      label: Text('Merge'),
                    ),
                    ButtonSegment(
                      value: AutoCombineRuleType.hideByCountry,
                      icon: Icon(Icons.visibility_off),
                      label: Text('Hide'),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (selected) {
                    setDialogState(() => type = selected.first);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: patternsController,
                  decoration: const InputDecoration(
                    labelText: 'Patterns to Match',
                    hintText: 'SPORT, SPORTS, DEPORTE',
                    helperText: 'Separate with commas',
                  ),
                  maxLines: 2,
                ),
                if (type == AutoCombineRuleType.mergeByKeyword) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: targetController,
                    decoration: const InputDecoration(
                      labelText: 'Target Category Name',
                      hintText: 'e.g., SPORTS',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final patterns = patternsController.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                final target = targetController.text.trim();

                if (name.isEmpty || patterns.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name and patterns are required')),
                  );
                  return;
                }

                if (type == AutoCombineRuleType.mergeByKeyword && target.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Target category name is required for merge rules')),
                  );
                  return;
                }

                final rule = AutoCombineRule(
                  id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  type: type,
                  name: name,
                  patterns: patterns,
                  targetCategoryName: type == AutoCombineRuleType.mergeByKeyword ? target : null,
                  enabled: existing?.enabled ?? true,
                  isBuiltIn: false,
                );

                Navigator.pop(context, rule);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
