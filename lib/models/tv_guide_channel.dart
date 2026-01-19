import 'package:another_iptv_player/models/epg_program.dart';
import 'package:another_iptv_player/models/live_stream.dart';
import 'package:another_iptv_player/models/m3u_item.dart';
import 'package:another_iptv_player/models/playlist_model.dart';

class TvGuideChannel {
  final String streamId;
  final String name;
  final String playlistId;
  final String? icon;
  final String? epgChannelId;
  final PlaylistType sourceType;
  final List<EpgProgram> programs;
  final LiveStream? liveStream;
  final M3uItem? m3uItem;

  TvGuideChannel({
    required this.streamId,
    required this.name,
    required this.playlistId,
    this.icon,
    this.epgChannelId,
    required this.sourceType,
    this.programs = const [],
    this.liveStream,
    this.m3uItem,
  });

  bool get hasEpgData => programs.isNotEmpty;

  EpgProgram? get currentProgram {
    try {
      return programs.firstWhere((p) => p.isLive);
    } catch (_) {
      return null;
    }
  }

  EpgProgram? get nextProgram {
    final now = DateTime.now();
    try {
      return programs.firstWhere((p) => p.startTime.isAfter(now));
    } catch (_) {
      return null;
    }
  }

  List<EpgProgram> getProgramsInRange(DateTime from, DateTime to) {
    return programs.where((p) {
      return p.endTime.isAfter(from) && p.startTime.isBefore(to);
    }).toList();
  }

  factory TvGuideChannel.fromLiveStream(
    LiveStream stream, {
    List<EpgProgram>? programs,
  }) {
    return TvGuideChannel(
      streamId: stream.streamId,
      name: stream.name,
      playlistId: stream.playlistId ?? '',
      icon: stream.streamIcon,
      epgChannelId: stream.epgChannelId.isNotEmpty ? stream.epgChannelId : null,
      sourceType: PlaylistType.xtream,
      programs: programs ?? [],
      liveStream: stream,
    );
  }

  factory TvGuideChannel.fromM3uItem(
    M3uItem item, {
    List<EpgProgram>? programs,
  }) {
    return TvGuideChannel(
      streamId: item.id,
      name: item.name ?? 'Unknown',
      playlistId: item.playlistId,
      icon: item.tvgLogo,
      epgChannelId: item.tvgId,
      sourceType: PlaylistType.m3u,
      programs: programs ?? [],
      m3uItem: item,
    );
  }

  TvGuideChannel copyWith({
    String? streamId,
    String? name,
    String? playlistId,
    String? icon,
    String? epgChannelId,
    PlaylistType? sourceType,
    List<EpgProgram>? programs,
    LiveStream? liveStream,
    M3uItem? m3uItem,
  }) {
    return TvGuideChannel(
      streamId: streamId ?? this.streamId,
      name: name ?? this.name,
      playlistId: playlistId ?? this.playlistId,
      icon: icon ?? this.icon,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      sourceType: sourceType ?? this.sourceType,
      programs: programs ?? this.programs,
      liveStream: liveStream ?? this.liveStream,
      m3uItem: m3uItem ?? this.m3uItem,
    );
  }

  @override
  String toString() {
    return 'TvGuideChannel(name: $name, streamId: $streamId, epgChannelId: $epgChannelId, programs: ${programs.length})';
  }
}
