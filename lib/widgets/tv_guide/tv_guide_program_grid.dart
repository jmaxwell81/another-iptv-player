import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/epg_program.dart';
import 'package:another_iptv_player/models/tv_guide_channel.dart';
import 'package:another_iptv_player/widgets/tv_guide/tv_guide_program_cell.dart';

class TvGuideProgramGrid extends StatelessWidget {
  final List<TvGuideChannel> channels;
  final DateTime viewStartTime;
  final DateTime viewEndTime;
  final double pixelsPerMinute;
  final double channelHeight;
  final ScrollController horizontalScrollController;
  final ScrollController verticalScrollController;
  final void Function(TvGuideChannel, EpgProgram)? onProgramTap;

  const TvGuideProgramGrid({
    super.key,
    required this.channels,
    required this.viewStartTime,
    required this.viewEndTime,
    required this.pixelsPerMinute,
    required this.horizontalScrollController,
    required this.verticalScrollController,
    this.channelHeight = 60,
    this.onProgramTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMinutes = viewEndTime.difference(viewStartTime).inMinutes;
    final totalWidth = totalMinutes * pixelsPerMinute;

    return ListView.builder(
      controller: verticalScrollController,
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return Container(
          height: channelHeight,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor, width: 0.5),
            ),
          ),
          child: SingleChildScrollView(
            controller: horizontalScrollController,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: totalWidth,
              child: _buildProgramRow(context, channel, theme),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgramRow(BuildContext context, TvGuideChannel channel, ThemeData theme) {
    final programs = channel.getProgramsInRange(viewStartTime, viewEndTime);

    if (programs.isEmpty) {
      // Show "No EPG Data" placeholder
      return Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          'No program information available',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Current time indicator
        _buildCurrentTimeIndicator(theme),
        // Programs
        ...programs.map((program) {
          final width = _getProgramWidth(program);
          final offset = _getProgramOffset(program);

          if (width <= 0) return const SizedBox.shrink();

          return Positioned(
            left: offset,
            top: 0,
            bottom: 0,
            child: TvGuideProgramCell(
              program: program,
              width: width,
              height: channelHeight - 2,
              onTap: onProgramTap != null
                  ? () => onProgramTap!(channel, program)
                  : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCurrentTimeIndicator(ThemeData theme) {
    final now = DateTime.now();
    if (now.isBefore(viewStartTime) || now.isAfter(viewEndTime)) {
      return const SizedBox.shrink();
    }

    final offset = now.difference(viewStartTime).inMinutes * pixelsPerMinute;

    return Positioned(
      left: offset - 1,
      top: 0,
      bottom: 0,
      child: Container(
        width: 2,
        color: theme.colorScheme.error,
      ),
    );
  }

  double _getProgramWidth(EpgProgram program) {
    // Clamp to visible range
    final effectiveStart = program.startTime.isBefore(viewStartTime)
        ? viewStartTime
        : program.startTime;
    final effectiveEnd = program.endTime.isAfter(viewEndTime)
        ? viewEndTime
        : program.endTime;

    final duration = effectiveEnd.difference(effectiveStart).inMinutes;
    return duration * pixelsPerMinute;
  }

  double _getProgramOffset(EpgProgram program) {
    final effectiveStart = program.startTime.isBefore(viewStartTime)
        ? viewStartTime
        : program.startTime;
    return effectiveStart.difference(viewStartTime).inMinutes * pixelsPerMinute;
  }
}

/// A more optimized version using a single scroll view with positioned items
class TvGuideProgramGridOptimized extends StatelessWidget {
  final List<TvGuideChannel> channels;
  final DateTime viewStartTime;
  final DateTime viewEndTime;
  final double pixelsPerMinute;
  final double channelHeight;
  final ScrollController? horizontalScrollController;
  final ScrollController? verticalScrollController;
  final void Function(TvGuideChannel, EpgProgram)? onProgramTap;

  const TvGuideProgramGridOptimized({
    super.key,
    required this.channels,
    required this.viewStartTime,
    required this.viewEndTime,
    required this.pixelsPerMinute,
    this.channelHeight = 60,
    this.horizontalScrollController,
    this.verticalScrollController,
    this.onProgramTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMinutes = viewEndTime.difference(viewStartTime).inMinutes;
    final totalWidth = totalMinutes * pixelsPerMinute;
    final totalHeight = channels.length * channelHeight;

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: EdgeInsets.zero,
      minScale: 1.0,
      maxScale: 1.0,
      child: SizedBox(
        width: totalWidth,
        height: totalHeight,
        child: Stack(
          children: [
            // Background grid lines
            ..._buildGridLines(theme, totalWidth),
            // Current time indicator
            _buildCurrentTimeIndicator(theme, totalHeight),
            // Programs
            ..._buildAllPrograms(theme),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGridLines(ThemeData theme, double totalWidth) {
    final lines = <Widget>[];

    // Horizontal lines (between channels)
    for (int i = 0; i <= channels.length; i++) {
      lines.add(Positioned(
        left: 0,
        right: 0,
        top: i * channelHeight,
        child: Container(
          height: 0.5,
          color: theme.dividerColor.withOpacity(0.5),
        ),
      ));
    }

    // Vertical lines (every 30 minutes)
    var current = DateTime(
      viewStartTime.year,
      viewStartTime.month,
      viewStartTime.day,
      viewStartTime.hour,
      viewStartTime.minute >= 30 ? 30 : 0,
    );

    if (current.isBefore(viewStartTime)) {
      current = current.add(const Duration(minutes: 30));
    }

    while (current.isBefore(viewEndTime)) {
      final offset = current.difference(viewStartTime).inMinutes * pixelsPerMinute;
      final isHour = current.minute == 0;

      lines.add(Positioned(
        left: offset,
        top: 0,
        bottom: 0,
        child: Container(
          width: isHour ? 1 : 0.5,
          color: theme.dividerColor.withOpacity(isHour ? 0.5 : 0.3),
        ),
      ));

      current = current.add(const Duration(minutes: 30));
    }

    return lines;
  }

  Widget _buildCurrentTimeIndicator(ThemeData theme, double totalHeight) {
    final now = DateTime.now();
    if (now.isBefore(viewStartTime) || now.isAfter(viewEndTime)) {
      return const SizedBox.shrink();
    }

    final offset = now.difference(viewStartTime).inMinutes * pixelsPerMinute;

    return Positioned(
      left: offset - 1,
      top: 0,
      height: totalHeight,
      child: Container(
        width: 2,
        color: theme.colorScheme.error,
      ),
    );
  }

  List<Widget> _buildAllPrograms(ThemeData theme) {
    final widgets = <Widget>[];

    for (int channelIndex = 0; channelIndex < channels.length; channelIndex++) {
      final channel = channels[channelIndex];
      final programs = channel.getProgramsInRange(viewStartTime, viewEndTime);
      final top = channelIndex * channelHeight;

      if (programs.isEmpty) {
        // No EPG data placeholder
        widgets.add(Positioned(
          left: 8,
          top: top,
          height: channelHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'No program information',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.3),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ));
        continue;
      }

      for (final program in programs) {
        final width = _getProgramWidth(program);
        final offset = _getProgramOffset(program);

        if (width <= 0) continue;

        widgets.add(Positioned(
          left: offset,
          top: top + 1,
          child: TvGuideProgramCell(
            program: program,
            width: width,
            height: channelHeight - 2,
            onTap: onProgramTap != null
                ? () => onProgramTap!(channel, program)
                : null,
          ),
        ));
      }
    }

    return widgets;
  }

  double _getProgramWidth(EpgProgram program) {
    final effectiveStart = program.startTime.isBefore(viewStartTime)
        ? viewStartTime
        : program.startTime;
    final effectiveEnd = program.endTime.isAfter(viewEndTime)
        ? viewEndTime
        : program.endTime;

    final duration = effectiveEnd.difference(effectiveStart).inMinutes;
    return duration * pixelsPerMinute;
  }

  double _getProgramOffset(EpgProgram program) {
    final effectiveStart = program.startTime.isBefore(viewStartTime)
        ? viewStartTime
        : program.startTime;
    return effectiveStart.difference(viewStartTime).inMinutes * pixelsPerMinute;
  }
}
