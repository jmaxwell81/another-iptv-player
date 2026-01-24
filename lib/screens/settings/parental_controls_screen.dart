import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/parental_control.dart';
import '../../services/parental_control_service.dart';
import '../../widgets/section_title_widget.dart';

class ParentalControlsScreen extends StatefulWidget {
  const ParentalControlsScreen({super.key});

  @override
  State<ParentalControlsScreen> createState() => _ParentalControlsScreenState();
}

class _ParentalControlsScreenState extends State<ParentalControlsScreen> {
  final ParentalControlService _service = ParentalControlService();
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    await _service.initialize();
    await _service.refresh();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showSetPinDialog() async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              decoration: const InputDecoration(
                labelText: 'Enter 4-digit PIN',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                labelText: 'Confirm PIN',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (pinController.text.length != 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN must be 4 digits')),
                );
                return;
              }
              if (pinController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PINs do not match')),
                );
                return;
              }
              Navigator.pop(context, pinController.text);
            },
            child: const Text('Set PIN'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _service.setPin(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN set successfully')),
        );
        setState(() {});
      }
    }
  }

  Future<bool> _verifyPin() async {
    if (!_service.hasPin) return true;

    final pinController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter PIN'),
        content: TextField(
          controller: pinController,
          decoration: const InputDecoration(
            labelText: 'Enter your PIN',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          obscureText: true,
          autofocus: true,
          onSubmitted: (value) async {
            final isValid = await _service.verifyPin(value);
            Navigator.pop(context, isValid);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final isValid = await _service.verifyPin(pinController.text);
              Navigator.pop(context, isValid);
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    if (result == true) {
      return true;
    } else if (result == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect PIN')),
        );
      }
    }
    return false;
  }

  Future<void> _toggleEnabled(bool value) async {
    if (value && !_service.hasPin) {
      await _showSetPinDialog();
      if (!_service.hasPin) return;
    }

    if (!value) {
      final verified = await _verifyPin();
      if (!verified) return;
    }

    if (value) {
      await _service.enable();
    } else {
      await _service.disable();
    }
    setState(() {});
  }

  Future<void> _toggleUnlock() async {
    if (_service.isUnlocked) {
      await _service.lock();
    } else {
      final verified = await _verifyPin();
      if (verified) {
        await _service.unlock();
      }
    }
    setState(() {});
  }

  Future<void> _addKeyword() async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) return;

    await _service.addBlockedKeyword(keyword);
    _keywordController.clear();
    setState(() {});
  }

  Future<void> _removeKeyword(String keyword) async {
    await _service.removeBlockedKeyword(keyword);
    setState(() {});
  }

  Future<void> _removeBlockedCategory(String categoryId) async {
    await _service.removeBlockedCategory(categoryId);
    setState(() {});
  }

  Future<void> _removeBlockedItem(ParentalBlockedItem item) async {
    await _service.removeBlockedItem(item.id, item.contentType);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Parental Controls')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parental Controls'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Enable/Disable
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.lock),
                  title: const Text('Enable Parental Controls'),
                  subtitle: const Text('Hide content matching blocked keywords and selections'),
                  value: _service.isEnabled,
                  onChanged: _toggleEnabled,
                ),
                if (_service.isEnabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      _service.isUnlocked ? Icons.lock_open : Icons.lock,
                      color: _service.isUnlocked ? Colors.green : Colors.red,
                    ),
                    title: Text(_service.isUnlocked ? 'Content Unlocked' : 'Content Locked'),
                    subtitle: Text(
                      _service.isUnlocked
                          ? 'Parental content is visible at the end of category lists'
                          : 'Parental content is hidden',
                    ),
                    trailing: FilledButton(
                      onPressed: _toggleUnlock,
                      child: Text(_service.isUnlocked ? 'Lock' : 'Unlock'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // PIN Management
          if (_service.isEnabled) ...[
            const SectionTitleWidget(title: 'PIN Settings'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.pin),
                    title: const Text('Change PIN'),
                    subtitle: const Text('Update your parental control PIN'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final verified = await _verifyPin();
                      if (verified) {
                        await _showSetPinDialog();
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.timer),
                    title: const Text('Auto-lock Timeout'),
                    subtitle: Text('${_service.settings.lockTimeoutMinutes} minutes'),
                    trailing: DropdownButton<int>(
                      value: _service.settings.lockTimeoutMinutes,
                      items: const [
                        DropdownMenuItem(value: 5, child: Text('5 min')),
                        DropdownMenuItem(value: 15, child: Text('15 min')),
                        DropdownMenuItem(value: 30, child: Text('30 min')),
                        DropdownMenuItem(value: 60, child: Text('1 hour')),
                        DropdownMenuItem(value: 120, child: Text('2 hours')),
                      ],
                      onChanged: (value) async {
                        if (value != null) {
                          await _service.setLockTimeout(value);
                          setState(() {});
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Blocked Keywords
            const SectionTitleWidget(title: 'Blocked Keywords'),
            Card(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _keywordController,
                            decoration: const InputDecoration(
                              labelText: 'Add keyword',
                              hintText: 'e.g., adult, xxx, etc.',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _addKeyword(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _addKeyword,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                  if (_service.settings.blockedKeywords.isNotEmpty) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _service.settings.blockedKeywords.map((keyword) {
                          return Chip(
                            label: Text(keyword),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () => _removeKeyword(keyword),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  if (_service.settings.blockedKeywords.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No blocked keywords. Add keywords to automatically hide matching content.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Blocked Categories
            const SectionTitleWidget(title: 'Blocked Categories'),
            Card(
              child: Column(
                children: [
                  if (_service.blockedCategories.isNotEmpty) ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _service.blockedCategories.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final category = _service.blockedCategories[index];
                        return ListTile(
                          leading: const Icon(Icons.folder),
                          title: Text(category.name),
                          subtitle: Text(category.contentType.name),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            color: Colors.red,
                            onPressed: () => _removeBlockedCategory(category.id),
                          ),
                        );
                      },
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No blocked categories. Long-press a category in the main view to block it.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Blocked Items
            const SectionTitleWidget(title: 'Blocked Items'),
            Card(
              child: Column(
                children: [
                  if (_service.settings.blockedItems.isNotEmpty) ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _service.settings.blockedItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _service.settings.blockedItems[index];
                        return ListTile(
                          leading: item.imagePath != null && item.imagePath!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    item.imagePath!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.movie),
                                  ),
                                )
                              : const Icon(Icons.movie),
                          title: Text(item.name),
                          subtitle: Text(item.contentType.name),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            color: Colors.red,
                            onPressed: () => _removeBlockedItem(item),
                          ),
                        );
                      },
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No blocked items. Long-press an item in the main view to block it.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }
}
