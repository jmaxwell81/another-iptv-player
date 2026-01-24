import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/screens/xtream-codes/xtream_code_data_loader_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../controllers/playlist_controller.dart';
import '../../../../models/api_configuration_model.dart';
import '../../../../models/playlist_model.dart';
import '../../../../repositories/iptv_repository.dart';
import '../../../../services/url_failover_service.dart';

class NewXtreamCodePlaylistScreen extends StatefulWidget {
  final Playlist? editPlaylist;

  const NewXtreamCodePlaylistScreen({super.key, this.editPlaylist});

  @override
  NewXtreamCodePlaylistScreenState createState() =>
      NewXtreamCodePlaylistScreenState();
}

class NewXtreamCodePlaylistScreenState
    extends State<NewXtreamCodePlaylistScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  bool _obscurePassword = true;
  bool _isFormValid = false;
  bool _showAdvancedUrls = false;
  List<String> _additionalUrls = [];
  final UrlFailoverService _failoverService = UrlFailoverService();

  bool get _isEditing => widget.editPlaylist != null;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing values if editing
    _nameController = TextEditingController(
      text: widget.editPlaylist?.name ?? 'Playlist-1',
    );
    _urlController = TextEditingController(
      text: widget.editPlaylist?.url ?? '',
    );
    _usernameController = TextEditingController(
      text: widget.editPlaylist?.username ?? '',
    );
    _passwordController = TextEditingController(
      text: widget.editPlaylist?.password ?? '',
    );

    // Load additional URLs if editing
    if (widget.editPlaylist != null) {
      _additionalUrls = List.from(widget.editPlaylist!.additionalUrls);
      if (_additionalUrls.isNotEmpty) {
        _showAdvancedUrls = true;
      }
    }

    _nameController.addListener(_validateForm);
    _urlController.addListener(_validateForm);
    _usernameController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);

    // Validate immediately for edit mode
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _validateForm());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateForm() {
    setState(() {
      _isFormValid =
          _nameController.text.trim().isNotEmpty &&
          _urlController.text.trim().isNotEmpty &&
          _usernameController.text.trim().isNotEmpty &&
          _passwordController.text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Playlist' : 'XStream Playlist')),
      body: Consumer<PlaylistController>(
        builder: (context, controller, child) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(colorScheme),
                  SizedBox(height: 32),
                  _buildPlaylistNameField(colorScheme),
                  SizedBox(height: 20),
                  _buildUrlField(colorScheme),
                  SizedBox(height: 12),
                  _buildBackupUrlsSection(colorScheme),
                  SizedBox(height: 20),
                  _buildUsernameField(colorScheme),
                  SizedBox(height: 20),
                  _buildPasswordField(colorScheme),
                  SizedBox(height: 32),
                  _buildSaveButton(controller, colorScheme),
                  if (controller.error != null) ...[
                    SizedBox(height: 20),
                    _buildErrorCard(controller.error!, colorScheme),
                  ],
                  SizedBox(height: 20),
                  _buildInfoCard(colorScheme),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Icon(
            _isEditing ? Icons.edit : Icons.stream,
            size: 30,
            color: colorScheme.onPrimary,
          ),
        ),
        SizedBox(height: 16),
        Text(
          _isEditing ? 'Edit XStream Playlist' : 'XStream Code Playlist',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 8),
        Text(
          _isEditing
              ? 'Update the playlist credentials below'
              : context.loc.xtream_code_description,
          style: TextStyle(
            fontSize: 16,
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistNameField(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.loc.playlist_name,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: context.loc.playlist_name_placeholder,
            prefixIcon: Icon(Icons.playlist_add, color: colorScheme.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            filled: true,
            fillColor: colorScheme.surface,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return context.loc.playlist_name_required;
            }
            if (value.trim().length < 2) {
              return context.loc.playlist_name_min_2;
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildUrlField(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.loc.api_url,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: _urlController,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: 'http://example.com:8080',
            prefixIcon: Icon(Icons.link, color: colorScheme.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            filled: true,
            fillColor: colorScheme.surface,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return context.loc.api_url_required;
            }

            final uri = Uri.tryParse(value.trim());
            if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
              return context.loc.url_format_validate_error;
            }

            if (!['http', 'https'].contains(uri.scheme)) {
              return context.loc.url_format_validate_error;
            }

            return null;
          },
        ),
      ],
    );
  }

  Widget _buildBackupUrlsSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle button for advanced URLs
        InkWell(
          onTap: () {
            setState(() {
              _showAdvancedUrls = !_showAdvancedUrls;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _showAdvancedUrls
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  'Backup URLs (optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.primary,
                  ),
                ),
                if (_additionalUrls.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_additionalUrls.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Backup URLs editor
        if (_showAdvancedUrls) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add backup server URLs that will be used if the primary URL is offline.',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 16),

                // List of backup URLs
                ..._buildBackupUrlFields(colorScheme),

                // Add backup URL button
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addBackupUrl,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Backup URL'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(color: colorScheme.outline),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildBackupUrlFields(ColorScheme colorScheme) {
    final widgets = <Widget>[];

    for (var i = 0; i < _additionalUrls.length; i++) {
      final controller = TextEditingController(text: _additionalUrls[i]);

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: 'http://backup-server.com:8080',
                    prefixIcon: Icon(Icons.backup, color: colorScheme.outline),
                    labelText: 'Backup URL ${i + 1}',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    _additionalUrls[i] = value;
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Check health button
              IconButton(
                onPressed: () => _checkBackupUrlHealth(i),
                icon: const Icon(Icons.network_check, size: 20),
                tooltip: 'Check connection',
                style: IconButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                ),
              ),
              // Remove button
              IconButton(
                onPressed: () => _removeBackupUrl(i),
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                tooltip: 'Remove',
                style: IconButton.styleFrom(
                  foregroundColor: colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  void _addBackupUrl() {
    setState(() {
      _additionalUrls.add('');
    });
  }

  void _removeBackupUrl(int index) {
    setState(() {
      _additionalUrls.removeAt(index);
    });
  }

  Future<void> _checkBackupUrlHealth(int index) async {
    final url = _additionalUrls[index];
    if (url.isEmpty) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    final result = await _failoverService.checkUrlHealth(
      url,
      username: username.isNotEmpty ? username : null,
      password: password.isNotEmpty ? password : null,
      type: PlaylistType.xtream,
      useCache: false,
    );

    if (!mounted) return;

    final statusText = result.isHealthy
        ? 'Online (${result.responseTimeMs}ms)'
        : 'Offline: ${result.error ?? 'Unknown error'}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Backup URL ${index + 1}: $statusText'),
        backgroundColor: result.isHealthy ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildUsernameField(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.loc.username,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: _usernameController,
          decoration: InputDecoration(
            hintText: context.loc.username_placeholder,
            prefixIcon: Icon(Icons.person, color: colorScheme.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            filled: true,
            fillColor: colorScheme.surface,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return context.loc.username_required;
            }
            if (value.trim().length < 3) {
              return context.loc.username_min_3;
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.loc.password,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: context.loc.password_placeholder,
            prefixIcon: Icon(Icons.lock, color: colorScheme.primary),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            filled: true,
            fillColor: colorScheme.surface,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return context.loc.password_required;
            }
            if (value.length < 3) {
              return context.loc.password_min_3;
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSaveButton(
    PlaylistController controller,
    ColorScheme colorScheme,
  ) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: controller.isLoading
            ? null
            : (_isFormValid ? _savePlaylist : null),
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.onSurface.withOpacity(0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: controller.isLoading ? 0 : 2,
        ),
        child: controller.isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    context.loc.submitting,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save, size: 20),
                  SizedBox(width: 8),
                  Text(
                    _isEditing ? 'Save Changes' : context.loc.submit_create_playlist,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorCard(String error, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.loc.error_occurred,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  error,
                  style: TextStyle(
                    color: colorScheme.onErrorContainer,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                context.loc.info,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '${context.loc.all_datas_are_stored_in_device}\n${context.loc.url_format_validate_message}',
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _savePlaylist() async {
    if (_formKey.currentState!.validate()) {
      final controller = Provider.of<PlaylistController>(
        context,
        listen: false,
      );

      controller.clearError();

      final repository = IptvRepository(
        ApiConfig(
          baseUrl: _urlController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text.trim(),
        ),
        _nameController.text.trim(),
      );

      var playerInfo = await repository.getPlayerInfo(forceRefresh: true);

      if (playerInfo == null) {
        controller.setError(context.loc.invalid_credentials);
        return;
      }

      // Filter out empty backup URLs
      final validBackupUrls = _additionalUrls
          .map((u) => u.trim())
          .where((u) => u.isNotEmpty)
          .toList();

      if (_isEditing) {
        // Update existing playlist
        final updatedPlaylist = Playlist(
          id: widget.editPlaylist!.id,
          name: _nameController.text.trim(),
          type: PlaylistType.xtream,
          url: _urlController.text.trim(),
          additionalUrls: validBackupUrls,
          username: _usernameController.text.trim(),
          password: _passwordController.text.trim(),
          createdAt: widget.editPlaylist!.createdAt,
          activeUrlIndex: widget.editPlaylist!.activeUrlIndex,
        );

        final success = await controller.updatePlaylist(updatedPlaylist);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Playlist updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate update
        }
      } else {
        // Create new playlist
        final playlist = await controller.createPlaylist(
          name: _nameController.text.trim(),
          type: PlaylistType.xtream,
          url: _urlController.text.trim(),
          additionalUrls: validBackupUrls,
          username: _usernameController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (playlist != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  XtreamCodeDataLoaderScreen(playlist: playlist),
            ),
          );
        }
      }
    }
  }
}
