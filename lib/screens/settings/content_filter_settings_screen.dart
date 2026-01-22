import 'package:flutter/material.dart';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/models/language_country_mapping.dart';
import 'package:another_iptv_player/services/content_filter_service.dart';
import 'package:another_iptv_player/services/content_normalization_service.dart';

/// Main settings screen for content filtering options
class ContentFilterSettingsScreen extends StatefulWidget {
  const ContentFilterSettingsScreen({super.key});

  @override
  State<ContentFilterSettingsScreen> createState() => _ContentFilterSettingsScreenState();
}

class _ContentFilterSettingsScreenState extends State<ContentFilterSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _filterService = ContentFilterService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _filterService.initialize();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.content_filters),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.loc.language_filter, icon: const Icon(Icons.language)),
            Tab(text: context.loc.filter_rules, icon: const Icon(Icons.filter_list)),
            Tab(text: context.loc.tag_mappings, icon: const Icon(Icons.translate)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _LanguageFilterTab(filterService: _filterService),
                _FilterRulesTab(filterService: _filterService),
                _TagMappingsTab(filterService: _filterService),
              ],
            ),
    );
  }
}

/// Tab for language-based filtering
class _LanguageFilterTab extends StatefulWidget {
  final ContentFilterService filterService;

  const _LanguageFilterTab({required this.filterService});

  @override
  State<_LanguageFilterTab> createState() => _LanguageFilterTabState();
}

class _LanguageFilterTabState extends State<_LanguageFilterTab> {
  late LanguageFilterSettings _settings;

  // Available languages with display names
  static const Map<String, String> _availableLanguages = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'tr': 'Turkish',
    'ar': 'Arabic',
    'nl': 'Dutch',
    'pl': 'Polish',
    'el': 'Greek',
    'hi': 'Hindi',
    'ja': 'Japanese',
    'ko': 'Korean',
    'zh': 'Chinese',
    'hy': 'Armenian',
  };

  @override
  void initState() {
    super.initState();
    _settings = widget.filterService.languageSettings;
  }

  Future<void> _updateSettings(LanguageFilterSettings newSettings) async {
    setState(() => _settings = newSettings);
    await widget.filterService.updateLanguageSettings(newSettings);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Enable/disable language filtering
        SwitchListTile(
          title: Text(context.loc.enable_language_filter),
          subtitle: Text(context.loc.enable_language_filter_desc),
          value: _settings.enabled,
          onChanged: (value) {
            _updateSettings(_settings.copyWith(enabled: value));
          },
        ),
        const Divider(),

        // Hide content with unknown language
        if (_settings.enabled) ...[
          SwitchListTile(
            title: Text(context.loc.hide_unknown_language),
            subtitle: Text(context.loc.hide_unknown_language_desc),
            value: _settings.hideUnknownLanguage,
            onChanged: (value) {
              _updateSettings(_settings.copyWith(hideUnknownLanguage: value));
            },
          ),
          const Divider(),

          // Preferred languages
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              context.loc.preferred_languages,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(
            context.loc.preferred_languages_desc,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          // Language chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableLanguages.entries.map((entry) {
              final isSelected = _settings.preferredLanguages.contains(entry.key);
              return FilterChip(
                label: Text(entry.value),
                selected: isSelected,
                onSelected: (selected) {
                  final newLanguages = Set<String>.from(_settings.preferredLanguages);
                  if (selected) {
                    newLanguages.add(entry.key);
                  } else {
                    newLanguages.remove(entry.key);
                  }
                  _updateSettings(_settings.copyWith(preferredLanguages: newLanguages));
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Info card about tags that map to selected languages
          if (_settings.preferredLanguages.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          context.loc.matching_tags,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getMatchingTagsDescription(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  String _getMatchingTagsDescription() {
    final normService = ContentNormalizationService();
    final tagsByLanguage = <String, List<String>>{};

    for (final langCode in _settings.preferredLanguages) {
      final tags = normService.getTagsForLanguage(langCode);
      if (tags.isNotEmpty) {
        tagsByLanguage[_availableLanguages[langCode] ?? langCode] = tags;
      }
    }

    if (tagsByLanguage.isEmpty) {
      return 'No tags configured for selected languages';
    }

    return tagsByLanguage.entries
        .map((e) => '${e.key}: ${e.value.join(", ")}')
        .join('\n');
  }
}

/// Tab for managing filter rules
class _FilterRulesTab extends StatefulWidget {
  final ContentFilterService filterService;

  const _FilterRulesTab({required this.filterService});

  @override
  State<_FilterRulesTab> createState() => _FilterRulesTabState();
}

class _FilterRulesTabState extends State<_FilterRulesTab> {
  @override
  Widget build(BuildContext context) {
    final rules = widget.filterService.filterRules;

    return Column(
      children: [
        // Add rule button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showAddRuleDialog(context),
            icon: const Icon(Icons.add),
            label: Text(context.loc.add_filter_rule),
          ),
        ),

        // Rules list
        Expanded(
          child: rules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.filter_list_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        context.loc.no_filter_rules,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.loc.no_filter_rules_desc,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: rules.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final rule = rules[index];
                    return _FilterRuleCard(
                      rule: rule,
                      onToggle: () async {
                        await widget.filterService.toggleFilterRule(rule.id);
                        setState(() {});
                      },
                      onEdit: () => _showEditRuleDialog(context, rule),
                      onDelete: () async {
                        await widget.filterService.removeFilterRule(rule.id);
                        setState(() {});
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showAddRuleDialog(BuildContext context) async {
    final result = await showDialog<ContentFilterRule>(
      context: context,
      builder: (context) => _FilterRuleDialog(filterService: widget.filterService),
    );

    if (result != null) {
      setState(() {});
    }
  }

  Future<void> _showEditRuleDialog(BuildContext context, ContentFilterRule rule) async {
    final result = await showDialog<ContentFilterRule>(
      context: context,
      builder: (context) => _FilterRuleDialog(
        filterService: widget.filterService,
        existingRule: rule,
      ),
    );

    if (result != null) {
      setState(() {});
    }
  }
}

/// Card widget for displaying a filter rule
class _FilterRuleCard extends StatelessWidget {
  final ContentFilterRule rule;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FilterRuleCard({
    required this.rule,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Switch(
          value: rule.isEnabled,
          onChanged: (_) => onToggle(),
        ),
        title: Text(
          rule.pattern,
          style: TextStyle(
            fontFamily: 'monospace',
            color: rule.isEnabled ? null : Colors.grey,
          ),
        ),
        subtitle: Text(
          _getRuleDescription(context, rule),
          style: TextStyle(
            color: rule.isEnabled ? null : Colors.grey,
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 20),
                  const SizedBox(width: 8),
                  Text(context.loc.edit),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete, size: 20, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(context.loc.delete, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRuleDescription(BuildContext context, ContentFilterRule rule) {
    final parts = <String>[];

    if (rule.isRegex) {
      parts.add('Regex');
    } else {
      parts.add('Wildcard');
    }

    if (rule.hideMatching) {
      parts.add('Hide matching');
    } else {
      parts.add('Show only matching');
    }

    if (rule.appliesToCategories) {
      parts.add('Categories');
    }
    if (rule.appliesToContent) {
      parts.add('Content');
    }

    return parts.join(' | ');
  }
}

/// Dialog for adding/editing filter rules
class _FilterRuleDialog extends StatefulWidget {
  final ContentFilterService filterService;
  final ContentFilterRule? existingRule;

  const _FilterRuleDialog({
    required this.filterService,
    this.existingRule,
  });

  @override
  State<_FilterRuleDialog> createState() => _FilterRuleDialogState();
}

class _FilterRuleDialogState extends State<_FilterRuleDialog> {
  late TextEditingController _patternController;
  bool _isRegex = false;
  bool _hideMatching = true;
  bool _appliesToCategories = false;
  bool _appliesToContent = true;

  @override
  void initState() {
    super.initState();
    final rule = widget.existingRule;
    _patternController = TextEditingController(text: rule?.pattern ?? '');
    if (rule != null) {
      _isRegex = rule.isRegex;
      _hideMatching = rule.hideMatching;
      _appliesToCategories = rule.appliesToCategories;
      _appliesToContent = rule.appliesToContent;
    }
  }

  @override
  void dispose() {
    _patternController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingRule != null;

    return AlertDialog(
      title: Text(isEditing ? context.loc.edit_filter_rule : context.loc.add_filter_rule),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _patternController,
              decoration: InputDecoration(
                labelText: context.loc.pattern,
                hintText: _isRegex ? '.*movie.*' : '*movie*',
                helperText: _isRegex
                    ? context.loc.pattern_regex_help
                    : context.loc.pattern_wildcard_help,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: Text(context.loc.use_regex),
              subtitle: Text(context.loc.use_regex_desc),
              value: _isRegex,
              onChanged: (value) => setState(() => _isRegex = value),
              contentPadding: EdgeInsets.zero,
            ),

            SwitchListTile(
              title: Text(context.loc.hide_matching),
              subtitle: Text(_hideMatching
                  ? context.loc.hide_matching_desc
                  : context.loc.show_only_matching_desc),
              value: _hideMatching,
              onChanged: (value) => setState(() => _hideMatching = value),
              contentPadding: EdgeInsets.zero,
            ),

            const Divider(),
            Text(
              context.loc.apply_to,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),

            CheckboxListTile(
              title: Text(context.loc.content_items),
              value: _appliesToContent,
              onChanged: (value) => setState(() => _appliesToContent = value ?? true),
              contentPadding: EdgeInsets.zero,
            ),

            CheckboxListTile(
              title: Text(context.loc.category_names),
              value: _appliesToCategories,
              onChanged: (value) => setState(() => _appliesToCategories = value ?? false),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.loc.cancel),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(context.loc.save),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final pattern = _patternController.text.trim();
    if (pattern.isEmpty) return;

    if (widget.existingRule != null) {
      final updated = widget.existingRule!.copyWith(
        pattern: pattern,
        isRegex: _isRegex,
        hideMatching: _hideMatching,
        appliesToCategories: _appliesToCategories,
        appliesToContent: _appliesToContent,
      );
      await widget.filterService.updateFilterRule(updated);
      if (mounted) Navigator.pop(context, updated);
    } else {
      final rule = await widget.filterService.addFilterRule(
        pattern: pattern,
        isRegex: _isRegex,
        hideMatching: _hideMatching,
        appliesToCategories: _appliesToCategories,
        appliesToContent: _appliesToContent,
      );
      if (mounted) Navigator.pop(context, rule);
    }
  }
}

/// Tab for managing tag-to-language mappings
class _TagMappingsTab extends StatefulWidget {
  final ContentFilterService filterService;

  const _TagMappingsTab({required this.filterService});

  @override
  State<_TagMappingsTab> createState() => _TagMappingsTabState();
}

class _TagMappingsTabState extends State<_TagMappingsTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final allMappings = widget.filterService.getAllMappings();

    // Filter by search
    final filteredMappings = _searchQuery.isEmpty
        ? allMappings
        : allMappings.where((m) =>
            m.tag.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            m.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            m.languageCode.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();

    // Group by language code
    final byLanguage = <String, List<LanguageCountryMapping>>{};
    for (final mapping in filteredMappings) {
      byLanguage.putIfAbsent(mapping.languageCode, () => []).add(mapping);
    }

    return Column(
      children: [
        // Search and Add
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: context.loc.search_mappings,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showAddMappingDialog(context),
                icon: const Icon(Icons.add),
                label: Text(context.loc.add),
              ),
            ],
          ),
        ),

        // Mappings list
        Expanded(
          child: ListView.builder(
            itemCount: byLanguage.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final langCode = byLanguage.keys.elementAt(index);
              final mappings = byLanguage[langCode]!;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  title: Text(_getLanguageName(langCode)),
                  subtitle: Text('${mappings.length} tags'),
                  children: mappings.map((mapping) {
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        child: Text(
                          mapping.tag.substring(0, mapping.tag.length.clamp(0, 2)),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      title: Text(mapping.tag),
                      subtitle: Text(
                        mapping.isCountryCode ? 'Country code' : 'Language code',
                      ),
                      trailing: mapping.isBuiltIn
                          ? const Chip(label: Text('Built-in'))
                          : IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await widget.filterService.removeUserMapping(mapping.tag);
                                setState(() {});
                              },
                            ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _getLanguageName(String code) {
    const names = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'tr': 'Turkish',
      'ar': 'Arabic',
      'nl': 'Dutch',
      'pl': 'Polish',
      'el': 'Greek',
      'hi': 'Hindi',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
      'hy': 'Armenian',
    };
    return names[code] ?? code.toUpperCase();
  }

  Future<void> _showAddMappingDialog(BuildContext context) async {
    final tagController = TextEditingController();
    String selectedLanguage = 'en';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.loc.add_tag_mapping),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tagController,
                decoration: InputDecoration(
                  labelText: context.loc.tag,
                  hintText: 'e.g., US, GB, EN',
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedLanguage,
                decoration: InputDecoration(
                  labelText: context.loc.language,
                  border: const OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'es', child: Text('Spanish')),
                  DropdownMenuItem(value: 'fr', child: Text('French')),
                  DropdownMenuItem(value: 'de', child: Text('German')),
                  DropdownMenuItem(value: 'it', child: Text('Italian')),
                  DropdownMenuItem(value: 'pt', child: Text('Portuguese')),
                  DropdownMenuItem(value: 'ru', child: Text('Russian')),
                  DropdownMenuItem(value: 'tr', child: Text('Turkish')),
                  DropdownMenuItem(value: 'ar', child: Text('Arabic')),
                  DropdownMenuItem(value: 'nl', child: Text('Dutch')),
                  DropdownMenuItem(value: 'pl', child: Text('Polish')),
                  DropdownMenuItem(value: 'el', child: Text('Greek')),
                  DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                  DropdownMenuItem(value: 'ja', child: Text('Japanese')),
                  DropdownMenuItem(value: 'ko', child: Text('Korean')),
                  DropdownMenuItem(value: 'zh', child: Text('Chinese')),
                  DropdownMenuItem(value: 'hy', child: Text('Armenian')),
                ],
                onChanged: (value) {
                  setDialogState(() => selectedLanguage = value ?? 'en');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.loc.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final tag = tagController.text.trim().toUpperCase();
                if (tag.isEmpty) return;

                await widget.filterService.addUserMapping(
                  LanguageCountryMapping(
                    tag: tag,
                    languageCode: selectedLanguage,
                    displayName: tag,
                    isCountryCode: tag.length == 2,
                  ),
                );
                if (context.mounted) Navigator.pop(context, true);
              },
              child: Text(context.loc.add),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() {});
    }
  }
}
