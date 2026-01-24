import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:another_iptv_player/controllers/tv_guide_controller.dart';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/models/epg_program.dart';
import 'package:another_iptv_player/models/tv_guide_channel.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/utils/navigate_by_content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/widgets/epg_loading_status_widget.dart';
import 'package:another_iptv_player/widgets/tv_guide/tv_guide_program_cell.dart';
import 'package:another_iptv_player/widgets/player_widget.dart';

class TvGuideScreen extends StatefulWidget {
  const TvGuideScreen({super.key});

  @override
  State<TvGuideScreen> createState() => _TvGuideScreenState();
}

class _TvGuideScreenState extends State<TvGuideScreen> {
  late TvGuideController _controller;
  late ScrollController _verticalScrollController;
  late ScrollController _horizontalScrollController;
  late ScrollController _channelScrollController;
  late ScrollController _timeHeaderScrollController;

  static const double _channelColumnWidth = 150.0;
  static const double _channelRowHeight = 60.0;
  static const double _previewPanelHeight = 200.0;

  // Preview state
  bool _autoPreview = true;
  TvGuideChannel? _selectedChannel;
  EpgProgram? _selectedProgram;
  Key? _playerKey; // Key to force player recreation when channel changes

  @override
  void initState() {
    super.initState();
    _controller = TvGuideController();
    _verticalScrollController = ScrollController();
    _horizontalScrollController = ScrollController();
    _channelScrollController = ScrollController();
    _timeHeaderScrollController = ScrollController();

    // Sync vertical scrolling between channel list and program grid
    _verticalScrollController.addListener(_syncVerticalScroll);
    _channelScrollController.addListener(_syncChannelScroll);

    // Sync horizontal scrolling between time header and program grid
    _horizontalScrollController.addListener(_syncHorizontalScroll);
    _timeHeaderScrollController.addListener(_syncTimeHeaderScroll);

    _controller.loadChannels();
  }

  void _syncVerticalScroll() {
    if (_channelScrollController.hasClients &&
        _channelScrollController.offset != _verticalScrollController.offset) {
      _channelScrollController.jumpTo(_verticalScrollController.offset);
    }
  }

  void _syncChannelScroll() {
    if (_verticalScrollController.hasClients &&
        _verticalScrollController.offset != _channelScrollController.offset) {
      _verticalScrollController.jumpTo(_channelScrollController.offset);
    }
  }

  void _syncHorizontalScroll() {
    if (_timeHeaderScrollController.hasClients &&
        _timeHeaderScrollController.offset != _horizontalScrollController.offset) {
      _timeHeaderScrollController.jumpTo(_horizontalScrollController.offset);
    }
  }

  void _syncTimeHeaderScroll() {
    if (_horizontalScrollController.hasClients &&
        _horizontalScrollController.offset != _timeHeaderScrollController.offset) {
      _horizontalScrollController.jumpTo(_timeHeaderScrollController.offset);
    }
  }

  @override
  void dispose() {
    _verticalScrollController.removeListener(_syncVerticalScroll);
    _channelScrollController.removeListener(_syncChannelScroll);
    _horizontalScrollController.removeListener(_syncHorizontalScroll);
    _timeHeaderScrollController.removeListener(_syncTimeHeaderScroll);

    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _channelScrollController.dispose();
    _timeHeaderScrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<TvGuideController>(
        builder: (context, controller, child) {
          return Scaffold(
            appBar: _buildAppBar(context, controller),
            body: _buildBody(context, controller),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, TvGuideController controller) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.loc.tv_guide),
          // Show compact EPG fetch progress in title area
          if (controller.epgFetchProgress != null)
            EpgLoadingStatusCompact(
              progress: controller.epgFetchProgress!,
              onCancel: controller.cancelEpgFetch,
            )
          else if (controller.epgStatus != null)
            Text(
              controller.epgStatus!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
      actions: [
        // Search
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => _showSearchDialog(context, controller),
        ),
        // Filter
        IconButton(
          icon: Icon(
            controller.showChannelsWithoutEpg
                ? Icons.filter_alt
                : Icons.filter_alt_outlined,
          ),
          onPressed: () => _showFilterSheet(context, controller),
        ),
        // Refresh EPG
        PopupMenuButton<String>(
          icon: (controller.isLoading || controller.isFetchingEpg)
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          enabled: !(controller.isLoading || controller.isFetchingEpg),
          onSelected: (value) {
            if (value == 'refresh') {
              controller.refresh();
            } else if (value == 'force_refresh') {
              controller.forceRefreshEpg();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: ListTile(
                leading: Icon(Icons.refresh),
                title: Text('Refresh'),
                subtitle: Text('Reload channels and programs'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'force_refresh',
              child: ListTile(
                leading: Icon(Icons.cloud_download),
                title: Text('Update EPG Data'),
                subtitle: Text('Re-download EPG from server'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        // Jump to now
        IconButton(
          icon: const Icon(Icons.access_time),
          tooltip: 'Jump to now',
          onPressed: controller.jumpToNow,
        ),
        // Auto-preview toggle
        IconButton(
          icon: Icon(
            _autoPreview ? Icons.visibility : Icons.visibility_off,
            color: _autoPreview ? Theme.of(context).colorScheme.primary : null,
          ),
          tooltip: _autoPreview ? 'Auto-preview ON' : 'Auto-preview OFF',
          onPressed: () {
            setState(() {
              _autoPreview = !_autoPreview;
              if (!_autoPreview) {
                _selectedChannel = null;
                _selectedProgram = null;
                _playerKey = null;
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, TvGuideController controller) {
    if (controller.isLoading && controller.channels.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.errorMessage != null && controller.channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(controller.errorMessage!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: controller.refresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final paginatedChannels = controller.paginatedChannels;
    final totalChannels = controller.totalFilteredChannels;

    if (totalChannels == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.tv_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              controller.searchQuery.isNotEmpty
                  ? 'No channels match your search'
                  : controller.showChannelsWithoutEpg
                      ? 'No channels available'
                      : 'No channels with EPG data',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (!controller.showChannelsWithoutEpg) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => controller.setShowChannelsWithoutEpg(true),
                child: const Text('Show all channels'),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        // Preview panel (when auto-preview is on and a channel is selected)
        if (_autoPreview && _selectedChannel != null)
          _buildPreviewPanel(context),
        // EPG loading status widget (when fetching EPG data)
        if (controller.epgFetchProgress != null)
          EpgLoadingStatusWidget(
            progress: controller.epgFetchProgress!,
            onCancel: controller.cancelEpgFetch,
          ),
        // Time navigation bar
        _buildTimeNavBar(context, controller),
        // Pagination bar
        _buildPaginationBar(context, controller),
        // Main content
        Expanded(
          child: _buildGuideGrid(context, controller, paginatedChannels),
        ),
      ],
    );
  }

  Widget _buildPreviewPanel(BuildContext context) {
    final theme = Theme.of(context);
    final channel = _selectedChannel!;
    final program = _selectedProgram ?? channel.currentProgram;

    // Create ContentItem from TvGuideChannel for player
    final contentItem = ContentItem(
      channel.streamId,
      channel.displayName,  // Use cleaned display name
      channel.icon ?? '',
      ContentType.liveStream,
      liveStream: channel.liveStream,
      m3uItem: channel.m3uItem,
      sourcePlaylistId: channel.playlistId,
      sourceType: channel.sourceType,
    );

    return Container(
      height: _previewPanelHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          // Preview video player
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: Stack(
                children: [
                  // Actual video player
                  if (_playerKey != null)
                    PlayerWidget(
                      key: _playerKey,
                      contentItem: contentItem,
                      showControls: false,
                      showInfo: false,
                    ),
                  // Live indicator overlay
                  if (program?.isLive == true)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Channel and program info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Channel name (use displayName for cleaned version)
                  Text(
                    channel.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Program info
                  if (program != null) ...[
                    Text(
                      program.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Time and progress
                    Row(
                      children: [
                        Text(
                          '${DateFormat.Hm().format(program.startTime)} - ${DateFormat.Hm().format(program.endTime)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (program.isLive) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: program.progress.clamp(0.0, 1.0),
                                backgroundColor: theme.colorScheme.surfaceContainerLow,
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${program.remainingTime.inMinutes}m left',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                    if (program.description != null && program.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          program.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ] else
                    Text(
                      'No program information',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  const Spacer(),
                  // Watch button
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () => _watchChannel(context, channel),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Watch'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedChannel = null;
                            _selectedProgram = null;
                            _playerKey = null;
                          });
                        },
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _watchChannel(BuildContext context, TvGuideChannel channel) {
    // Stop preview player before navigating to full screen
    setState(() {
      _selectedChannel = null;
      _selectedProgram = null;
      _playerKey = null;
    });

    final contentItem = ContentItem(
      channel.streamId,
      channel.displayName,  // Use cleaned display name
      channel.icon ?? '',
      ContentType.liveStream,
      liveStream: channel.liveStream,
      m3uItem: channel.m3uItem,
      sourcePlaylistId: channel.playlistId,
      sourceType: channel.sourceType,
    );
    navigateByContentType(context, contentItem);
  }

  Widget _buildPaginationBar(BuildContext context, TvGuideController controller) {
    final theme = Theme.of(context);
    final totalChannels = controller.totalFilteredChannels;
    final currentPage = controller.currentPage;
    final totalPages = controller.totalPages;
    final channelsPerPage = controller.channelsPerPage;
    final startChannel = currentPage * channelsPerPage + 1;
    final endChannel = ((currentPage + 1) * channelsPerPage).clamp(1, totalChannels);

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          // Channel count info
          Text(
            'Showing $startChannel-$endChannel of $totalChannels channels',
            style: theme.textTheme.bodySmall,
          ),
          const Spacer(),
          // Channels per page selector
          PopupMenuButton<int>(
            tooltip: 'Channels per page',
            initialValue: channelsPerPage,
            onSelected: (value) => controller.setChannelsPerPage(value),
            itemBuilder: (context) => [
              for (final count in [25, 50, 100, 150, 200, 300])
                PopupMenuItem(
                  value: count,
                  child: Text('$count per page'),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$channelsPerPage', style: theme.textTheme.bodySmall),
                  const Icon(Icons.arrow_drop_down, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Previous page button
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: controller.hasPreviousPage ? controller.previousPage : null,
            tooltip: 'Previous page',
            visualDensity: VisualDensity.compact,
          ),
          // Page indicator
          Text(
            'Page ${currentPage + 1} of $totalPages',
            style: theme.textTheme.bodySmall,
          ),
          // Next page button
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: controller.hasNextPage ? controller.nextPage : null,
            tooltip: 'Next page',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeNavBar(BuildContext context, TvGuideController controller) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMd();

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          // Previous
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => controller.scrollTimelineBy(const Duration(hours: -1)),
          ),
          // Date display
          Expanded(
            child: Center(
              child: Text(
                dateFormat.format(controller.viewStartTime),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          // Next
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => controller.scrollTimelineBy(const Duration(hours: 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideGrid(
    BuildContext context,
    TvGuideController controller,
    List<TvGuideChannel> channels,
  ) {
    final theme = Theme.of(context);
    final totalWidth = controller.totalWidth;

    return Row(
      children: [
        // Channel column
        SizedBox(
          width: _channelColumnWidth,
          child: Column(
            children: [
              // Header
              _buildChannelHeader(theme),
              // Channel list
              Expanded(
                child: ListView.builder(
                  controller: _channelScrollController,
                  itemCount: channels.length,
                  itemBuilder: (context, index) =>
                      _buildChannelRow(context, channels[index]),
                ),
              ),
            ],
          ),
        ),
        // Divider
        Container(width: 1, color: theme.dividerColor),
        // Program grid
        Expanded(
          child: Column(
            children: [
              // Time header
              _buildTimeHeader(context, controller),
              // Program rows
              Expanded(
                child: ListView.builder(
                  controller: _verticalScrollController,
                  itemCount: channels.length,
                  itemBuilder: (context, index) => _buildProgramRow(
                    context,
                    controller,
                    channels[index],
                    totalWidth,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChannelHeader(ThemeData theme) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      alignment: Alignment.center,
      child: Text(
        'Channels',
        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildChannelRow(BuildContext context, TvGuideChannel channel) {
    final theme = Theme.of(context);
    final isSelected = _selectedChannel?.streamId == channel.streamId;

    return InkWell(
      onTap: () => _onChannelTap(context, channel),
      child: Container(
        height: _channelRowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.3) : null,
          border: Border(bottom: BorderSide(color: theme.dividerColor, width: 0.5)),
        ),
        child: Row(
          children: [
            // Channel icon
            _buildChannelIcon(theme, channel),
            const SizedBox(width: 8),
            // Channel info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.displayName,
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (channel.currentProgram != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      channel.currentProgram!.title,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelIcon(ThemeData theme, TvGuideChannel channel) {
    if (channel.icon != null && channel.icon!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: channel.icon!,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
          placeholder: (context, url) => _buildIconPlaceholder(theme),
          errorWidget: (context, url, error) => _buildIconPlaceholder(theme),
        ),
      );
    }
    return _buildIconPlaceholder(theme);
  }

  Widget _buildIconPlaceholder(ThemeData theme) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.tv, size: 16, color: theme.colorScheme.onSurfaceVariant),
    );
  }

  Widget _buildTimeHeader(BuildContext context, TvGuideController controller) {
    final theme = Theme.of(context);
    final timeSlots = _generateTimeSlots(controller);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: SingleChildScrollView(
        controller: _timeHeaderScrollController,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: SizedBox(
          width: controller.totalWidth,
          child: Stack(
            children: [
              ...timeSlots.map((slot) => Positioned(
                    left: slot.offset,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: slot.isHour
                                ? theme.dividerColor
                                : theme.dividerColor.withOpacity(0.5),
                          ),
                        ),
                      ),
                      child: Text(
                        DateFormat.Hm().format(slot.time),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: slot.isHour ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  )),
              // Current time indicator
              if (_isCurrentTimeVisible(controller))
                Positioned(
                  left: controller.currentTimePosition - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: theme.colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgramRow(
    BuildContext context,
    TvGuideController controller,
    TvGuideChannel channel,
    double totalWidth,
  ) {
    final theme = Theme.of(context);
    final programs = channel.getProgramsInRange(
      controller.viewStartTime,
      controller.viewEndTime,
    );

    return Container(
      height: _channelRowHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: SingleChildScrollView(
        controller: _horizontalScrollController,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: SizedBox(
          width: totalWidth,
          child: Stack(
            children: [
              // No EPG placeholder
              if (programs.isEmpty)
                Positioned.fill(
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'No program information',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              // Programs
              ...programs.map((program) {
                final width = controller.getProgramWidth(program);
                final offset = controller.getProgramOffset(program);

                if (width <= 0) return const SizedBox.shrink();

                return Positioned(
                  left: offset,
                  top: 1,
                  child: TvGuideProgramCell(
                    program: program,
                    width: width,
                    height: _channelRowHeight - 2,
                    onTap: () => _onProgramTap(context, channel, program),
                  ),
                );
              }),
              // Current time indicator
              if (_isCurrentTimeVisible(controller))
                Positioned(
                  left: controller.currentTimePosition - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: theme.colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<_TimeSlot> _generateTimeSlots(TvGuideController controller) {
    final slots = <_TimeSlot>[];
    var current = DateTime(
      controller.viewStartTime.year,
      controller.viewStartTime.month,
      controller.viewStartTime.day,
      controller.viewStartTime.hour,
      controller.viewStartTime.minute >= 30 ? 30 : 0,
    );

    if (current.isBefore(controller.viewStartTime)) {
      current = current.add(const Duration(minutes: 30));
    }

    while (current.isBefore(controller.viewEndTime)) {
      final offset = controller.getXPositionForTime(current);
      slots.add(_TimeSlot(time: current, offset: offset, isHour: current.minute == 0));
      current = current.add(const Duration(minutes: 30));
    }

    return slots;
  }

  bool _isCurrentTimeVisible(TvGuideController controller) {
    final now = DateTime.now();
    return now.isAfter(controller.viewStartTime) && now.isBefore(controller.viewEndTime);
  }

  void _onChannelTap(BuildContext context, TvGuideChannel channel) {
    if (_autoPreview) {
      // Update preview and create new player key to force recreation
      setState(() {
        _selectedChannel = channel;
        _selectedProgram = channel.currentProgram;
        _playerKey = ValueKey('${channel.streamId}_${DateTime.now().millisecondsSinceEpoch}');
      });
    } else {
      // Navigate directly to the channel
      _watchChannel(context, channel);
    }
  }

  void _onProgramTap(BuildContext context, TvGuideChannel channel, EpgProgram program) {
    if (_autoPreview) {
      // Update preview and create new player key to force recreation
      setState(() {
        _selectedChannel = channel;
        _selectedProgram = program;
        _playerKey = ValueKey('${channel.streamId}_${DateTime.now().millisecondsSinceEpoch}');
      });
    } else {
      // Navigate directly to the channel
      _watchChannel(context, channel);
    }
  }

  void _showSearchDialog(BuildContext context, TvGuideController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Channels'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter channel or program name',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: controller.setSearchQuery,
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.clearSearch();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context, TvGuideController controller) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Options',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Show channels without EPG'),
              subtitle: const Text('Display all channels even if no program data'),
              value: controller.showChannelsWithoutEpg,
              onChanged: (value) {
                controller.setShowChannelsWithoutEpg(value);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Visible Hours: ${controller.visibleHours}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Slider(
              value: controller.visibleHours.toDouble(),
              min: 2,
              max: 12,
              divisions: 10,
              label: '${controller.visibleHours} hours',
              onChanged: (value) => controller.setVisibleHours(value.round()),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeSlot {
  final DateTime time;
  final double offset;
  final bool isHour;

  _TimeSlot({required this.time, required this.offset, required this.isHour});
}
