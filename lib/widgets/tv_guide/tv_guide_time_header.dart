import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TvGuideTimeHeader extends StatelessWidget {
  final DateTime startTime;
  final int visibleHours;
  final double pixelsPerMinute;
  final ScrollController scrollController;
  final double channelColumnWidth;

  const TvGuideTimeHeader({
    super.key,
    required this.startTime,
    required this.visibleHours,
    required this.pixelsPerMinute,
    required this.scrollController,
    this.channelColumnWidth = 150,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeSlots = _generateTimeSlots();
    final totalWidth = visibleHours * 60 * pixelsPerMinute;

    return Container(
      height: 40,
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          // Channel column placeholder
          Container(
            width: channelColumnWidth,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: theme.dividerColor),
                bottom: BorderSide(color: theme.dividerColor),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'Channels',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Time slots
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Container(
                width: totalWidth,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: theme.dividerColor),
                  ),
                ),
                child: Stack(
                  children: [
                    // Time labels
                    ...timeSlots.map((slot) {
                      final offset = slot.offset;
                      return Positioned(
                        left: offset,
                        top: 0,
                        bottom: 0,
                        child: _TimeSlotLabel(
                          time: slot.time,
                          isHour: slot.isHour,
                          theme: theme,
                        ),
                      );
                    }),
                    // Current time indicator
                    _buildCurrentTimeIndicator(theme),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(ThemeData theme) {
    final now = DateTime.now();
    if (now.isBefore(startTime) || now.isAfter(startTime.add(Duration(hours: visibleHours)))) {
      return const SizedBox.shrink();
    }

    final offset = now.difference(startTime).inMinutes * pixelsPerMinute;

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

  List<_TimeSlot> _generateTimeSlots() {
    final slots = <_TimeSlot>[];

    // Round to nearest 30 minutes
    var current = DateTime(
      startTime.year,
      startTime.month,
      startTime.day,
      startTime.hour,
      startTime.minute >= 30 ? 30 : 0,
    );

    if (current.isBefore(startTime)) {
      current = current.add(const Duration(minutes: 30));
    }

    final endTime = startTime.add(Duration(hours: visibleHours));

    while (current.isBefore(endTime)) {
      final offset = current.difference(startTime).inMinutes * pixelsPerMinute;
      slots.add(_TimeSlot(
        time: current,
        offset: offset,
        isHour: current.minute == 0,
      ));
      current = current.add(const Duration(minutes: 30));
    }

    return slots;
  }
}

class _TimeSlot {
  final DateTime time;
  final double offset;
  final bool isHour;

  _TimeSlot({
    required this.time,
    required this.offset,
    required this.isHour,
  });
}

class _TimeSlotLabel extends StatelessWidget {
  final DateTime time;
  final bool isHour;
  final ThemeData theme;

  const _TimeSlotLabel({
    required this.time,
    required this.isHour,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final format = isHour ? DateFormat.Hm() : DateFormat.Hm();

    return Container(
      padding: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isHour ? theme.dividerColor : theme.dividerColor.withOpacity(0.5),
            width: isHour ? 1 : 0.5,
          ),
        ),
      ),
      child: Text(
        format.format(time),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: isHour ? FontWeight.bold : FontWeight.normal,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
