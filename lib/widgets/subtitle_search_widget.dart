import 'package:flutter/material.dart';
import 'package:another_iptv_player/services/opensubtitles_service.dart';
import 'package:another_iptv_player/services/service_locator.dart';
import 'package:another_iptv_player/services/player_state.dart';
import 'package:another_iptv_player/repositories/user_preferences.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;

/// Widget for searching and downloading subtitles from OpenSubtitles
class SubtitleSearchWidget extends StatefulWidget {
  final String contentName;
  final String contentId;
  final String contentType; // 'vod', 'series', 'live'
  final String? imdbId;
  final int? tmdbId;
  final int? seasonNumber;
  final int? episodeNumber;
  final VoidCallback? onSubtitleLoaded;

  const SubtitleSearchWidget({
    super.key,
    required this.contentName,
    required this.contentId,
    required this.contentType,
    this.imdbId,
    this.tmdbId,
    this.seasonNumber,
    this.episodeNumber,
    this.onSubtitleLoaded,
  });

  @override
  State<SubtitleSearchWidget> createState() => _SubtitleSearchWidgetState();
}

class _SubtitleSearchWidgetState extends State<SubtitleSearchWidget> {
  final OpenSubtitlesService _subtitleService = getIt<OpenSubtitlesService>();
  final TextEditingController _searchController = TextEditingController();

  List<SubtitleSearchResult> _results = [];
  bool _isSearching = false;
  bool _isDownloading = false;
  String? _errorMessage;
  String _selectedLanguage = 'en';
  String? _downloadingId;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.contentName;
    _loadPreferredLanguage();
  }

  Future<void> _loadPreferredLanguage() async {
    final lang = await UserPreferences.getPreferredSubtitleLanguage();
    if (mounted) {
      setState(() {
        _selectedLanguage = lang;
      });
      // Auto-search if configured
      _search();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (!_subtitleService.isConfigured) {
      setState(() {
        _errorMessage = 'OpenSubtitles API key not configured.\nGo to Settings to add your API key.';
        _results = [];
      });
      return;
    }

    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      List<SubtitleSearchResult> results;

      // Try searching by IMDB ID first if available
      if (widget.imdbId != null && widget.imdbId!.isNotEmpty) {
        results = await _subtitleService.searchByImdbId(
          imdbId: widget.imdbId!,
          language: _selectedLanguage,
          seasonNumber: widget.seasonNumber,
          episodeNumber: widget.episodeNumber,
        );
      } else if (widget.tmdbId != null) {
        results = await _subtitleService.searchByTmdbId(
          tmdbId: widget.tmdbId!,
          language: _selectedLanguage,
          type: widget.contentType == 'series' ? 'episode' : 'movie',
          seasonNumber: widget.seasonNumber,
          episodeNumber: widget.episodeNumber,
        );
      } else {
        // Fall back to query search
        results = await _subtitleService.searchByQuery(
          query: query,
          language: _selectedLanguage,
          type: widget.contentType == 'series' ? 'episode' : 'movie',
          seasonNumber: widget.seasonNumber,
          episodeNumber: widget.episodeNumber,
        );
      }

      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
          if (results.isEmpty) {
            _errorMessage = 'No subtitles found for "$query" in ${_getLanguageName(_selectedLanguage)}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Search failed: $e';
        });
      }
    }
  }

  Future<void> _downloadSubtitle(SubtitleSearchResult result) async {
    final fileId = result.primaryFileId;
    if (fileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No subtitle file available')),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadingId = result.id;
    });

    try {
      final filePath = await _subtitleService.downloadSubtitle(
        fileId: fileId,
        contentId: widget.contentId,
        contentName: widget.contentName,
        contentType: widget.contentType,
        language: result.language,
        languageName: result.languageName,
        format: result.format,
      );

      if (filePath != null && mounted) {
        // Load the subtitle into the player
        final subtitleTrack = SubtitleTrack.uri(filePath, title: result.languageName);
        PlayerState.subtitles.add(subtitleTrack);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subtitle downloaded: ${result.languageName}'),
            backgroundColor: Colors.green,
          ),
        );

        widget.onSubtitleLoaded?.call();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to download subtitle'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadingId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 500),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search bar and language selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search subtitles...',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: _search,
                            ),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                // Language dropdown
                DropdownButton<String>(
                  value: _selectedLanguage,
                  items: _languages.map((lang) {
                    return DropdownMenuItem(
                      value: lang.$1,
                      child: Text(lang.$2),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedLanguage = value;
                      });
                      _search();
                    }
                  },
                ),
              ],
            ),
          ),

          // Error message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Results list
          if (_results.isNotEmpty)
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final result = _results[index];
                  final isDownloading = _downloadingId == result.id;

                  return ListTile(
                    leading: Icon(
                      result.hearingImpaired ? Icons.hearing_disabled : Icons.subtitles,
                      color: result.hearingImpaired ? Colors.orange : null,
                    ),
                    title: Text(
                      result.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${result.languageName} • ${result.format.toUpperCase()} • ${result.downloadCount} downloads',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (result.releaseInfo != null)
                          Text(
                            result.releaseInfo!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                    trailing: isDownloading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: _isDownloading ? null : () => _downloadSubtitle(result),
                          ),
                    isThreeLine: result.releaseInfo != null,
                  );
                },
              ),
            ),

          // Empty state
          if (_results.isEmpty && !_isSearching && _errorMessage == null)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.subtitles_off,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Search for subtitles',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter a movie or series name to find subtitles',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getLanguageName(String code) {
    for (final lang in _languages) {
      if (lang.$1 == code) return lang.$2;
    }
    return code.toUpperCase();
  }

  static const List<(String, String)> _languages = [
    ('en', 'English'),
    ('es', 'Spanish'),
    ('fr', 'French'),
    ('de', 'German'),
    ('it', 'Italian'),
    ('pt', 'Portuguese'),
    ('ru', 'Russian'),
    ('zh', 'Chinese'),
    ('ja', 'Japanese'),
    ('ko', 'Korean'),
    ('ar', 'Arabic'),
    ('tr', 'Turkish'),
    ('nl', 'Dutch'),
    ('pl', 'Polish'),
    ('sv', 'Swedish'),
  ];
}

/// Show subtitle search dialog
Future<void> showSubtitleSearchDialog(
  BuildContext context, {
  required String contentName,
  required String contentId,
  required String contentType,
  String? imdbId,
  int? tmdbId,
  int? seasonNumber,
  int? episodeNumber,
  VoidCallback? onSubtitleLoaded,
}) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Download Subtitles'),
      content: SubtitleSearchWidget(
        contentName: contentName,
        contentId: contentId,
        contentType: contentType,
        imdbId: imdbId,
        tmdbId: tmdbId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        onSubtitleLoaded: onSubtitleLoaded,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
