import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/epg_channel.dart';
import '../models/epg_program.dart';

class XmltvParseResult {
  final List<EpgChannel> channels;
  final List<EpgProgram> programs;
  final int parseErrors;
  final String? errorMessage;

  XmltvParseResult({
    required this.channels,
    required this.programs,
    this.parseErrors = 0,
    this.errorMessage,
  });

  bool get hasData => channels.isNotEmpty || programs.isNotEmpty;
  bool get hasErrors => parseErrors > 0 || errorMessage != null;
}

class XmltvParser {
  /// Parse XMLTV content and return channels and programs
  static Future<XmltvParseResult> parse(String xmlContent, String playlistId) async {
    final channels = <EpgChannel>[];
    final programs = <EpgProgram>[];
    int parseErrors = 0;

    try {
      final document = XmlDocument.parse(xmlContent);
      final tv = document.findElements('tv').firstOrNull;

      if (tv == null) {
        return XmltvParseResult(
          channels: [],
          programs: [],
          errorMessage: 'Invalid XMLTV format: no <tv> element found',
        );
      }

      // Parse channels
      for (final channelElement in tv.findElements('channel')) {
        try {
          final channel = _parseChannel(channelElement, playlistId);
          if (channel != null) {
            channels.add(channel);
          }
        } catch (e) {
          parseErrors++;
        }
      }

      // Parse programs
      for (final programElement in tv.findElements('programme')) {
        try {
          final program = _parseProgram(programElement, playlistId);
          if (program != null) {
            programs.add(program);
          }
        } catch (e) {
          parseErrors++;
        }
      }

      return XmltvParseResult(
        channels: channels,
        programs: programs,
        parseErrors: parseErrors,
      );
    } catch (e) {
      return XmltvParseResult(
        channels: [],
        programs: [],
        errorMessage: 'Failed to parse XMLTV: $e',
      );
    }
  }

  /// Parse from URL (handles gzip) with progress and cancellation support
  ///
  /// [connectionTimeout] - Max time to wait for initial connection (default: 15s)
  /// [downloadTimeout] - Max time for the entire download (default: 2min)
  /// [onProgress] - Callback for download progress (bytesDownloaded, totalBytes)
  /// [isCancelled] - Function that returns true if operation should be cancelled
  static Future<XmltvParseResult> parseFromUrl(
    String url,
    String playlistId, {
    Duration connectionTimeout = const Duration(seconds: 15),
    Duration downloadTimeout = const Duration(minutes: 2),
    void Function(int downloaded, int? total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final client = http.Client();
    try {
      // Build request
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Accept-Encoding'] = 'gzip, deflate';
      request.headers['User-Agent'] = 'IPTV Player';

      // Send request with connection timeout
      final http.StreamedResponse response;
      try {
        response = await client.send(request).timeout(connectionTimeout);
      } on TimeoutException {
        return XmltvParseResult(
          channels: [],
          programs: [],
          errorMessage: 'Connection timeout - server not responding',
        );
      } on SocketException catch (e) {
        return XmltvParseResult(
          channels: [],
          programs: [],
          errorMessage: 'Connection failed: ${e.message}',
        );
      }

      if (response.statusCode != 200) {
        return XmltvParseResult(
          channels: [],
          programs: [],
          errorMessage: 'HTTP error ${response.statusCode}',
        );
      }

      // Get content length for progress tracking
      final contentLength = response.contentLength;
      final bytes = <int>[];
      int downloaded = 0;

      // Report initial progress
      onProgress?.call(0, contentLength);

      // Stream download with progress reporting
      try {
        await for (final chunk in response.stream.timeout(downloadTimeout)) {
          // Check for cancellation
          if (isCancelled?.call() == true) {
            return XmltvParseResult(
              channels: [],
              programs: [],
              errorMessage: 'Cancelled',
            );
          }

          bytes.addAll(chunk);
          downloaded += chunk.length;
          onProgress?.call(downloaded, contentLength);
        }
      } on TimeoutException {
        return XmltvParseResult(
          channels: [],
          programs: [],
          errorMessage: 'Download timeout - transfer too slow',
        );
      }

      // Check for cancellation before parsing
      if (isCancelled?.call() == true) {
        return XmltvParseResult(
          channels: [],
          programs: [],
          errorMessage: 'Cancelled',
        );
      }

      // Decompress if needed
      String content;
      final bodyBytes = bytes;

      // Check for gzip magic bytes
      if (bodyBytes.length >= 2 &&
          bodyBytes[0] == 0x1f &&
          bodyBytes[1] == 0x8b) {
        try {
          final decompressed = gzip.decode(bodyBytes);
          content = utf8.decode(decompressed);
        } catch (e) {
          content = utf8.decode(bodyBytes, allowMalformed: true);
        }
      } else {
        content = utf8.decode(bodyBytes, allowMalformed: true);
      }

      return await parse(content, playlistId);
    } catch (e) {
      // Check if this looks like a connection/network error
      final errorMessage = e.toString().toLowerCase();
      final isOffline = errorMessage.contains('socket') ||
          errorMessage.contains('connection') ||
          errorMessage.contains('timeout') ||
          errorMessage.contains('network');

      return XmltvParseResult(
        channels: [],
        programs: [],
        errorMessage: isOffline
            ? 'Connection failed: Server offline or unreachable'
            : 'Failed to fetch XMLTV: $e',
      );
    } finally {
      client.close();
    }
  }

  /// Parse XMLTV date format: "20250118120000 +0000" or "20250118120000"
  static DateTime? parseXmltvDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;

    try {
      // Remove any whitespace
      dateStr = dateStr.trim();

      // Extract timezone offset if present
      String datePart = dateStr;
      int timezoneOffset = 0;

      final spaceIndex = dateStr.indexOf(' ');
      if (spaceIndex > 0) {
        datePart = dateStr.substring(0, spaceIndex);
        final tzPart = dateStr.substring(spaceIndex + 1).trim();
        timezoneOffset = _parseTimezoneOffset(tzPart);
      }

      // Parse the date part: YYYYMMDDHHMMSS
      if (datePart.length < 14) return null;

      final year = int.parse(datePart.substring(0, 4));
      final month = int.parse(datePart.substring(4, 6));
      final day = int.parse(datePart.substring(6, 8));
      final hour = int.parse(datePart.substring(8, 10));
      final minute = int.parse(datePart.substring(10, 12));
      final second = int.parse(datePart.substring(12, 14));

      // Create UTC datetime
      final utcTime = DateTime.utc(year, month, day, hour, minute, second);

      // Apply timezone offset
      return utcTime.subtract(Duration(minutes: timezoneOffset));
    } catch (e) {
      return null;
    }
  }

  static int _parseTimezoneOffset(String tzPart) {
    try {
      // Handle formats like "+0000", "-0500", "+0530"
      if (tzPart.isEmpty) return 0;

      final sign = tzPart[0] == '-' ? -1 : 1;
      final tzNumbers = tzPart.replaceAll(RegExp(r'[^0-9]'), '');

      if (tzNumbers.length < 4) return 0;

      final hours = int.parse(tzNumbers.substring(0, 2));
      final minutes = int.parse(tzNumbers.substring(2, 4));

      return sign * (hours * 60 + minutes);
    } catch (e) {
      return 0;
    }
  }

  static EpgChannel? _parseChannel(XmlElement element, String playlistId) {
    final channelId = element.getAttribute('id');
    if (channelId == null || channelId.isEmpty) return null;

    // Get display name - try different common patterns
    String displayName = '';
    final displayNameElements = element.findElements('display-name');
    if (displayNameElements.isNotEmpty) {
      displayName = displayNameElements.first.innerText.trim();
    }

    if (displayName.isEmpty) {
      displayName = channelId;
    }

    // Get icon
    String? icon;
    final iconElements = element.findElements('icon');
    if (iconElements.isNotEmpty) {
      icon = iconElements.first.getAttribute('src');
    }

    return EpgChannel(
      channelId: channelId,
      playlistId: playlistId,
      displayName: displayName,
      icon: icon,
      lastUpdated: DateTime.now(),
    );
  }

  static EpgProgram? _parseProgram(XmlElement element, String playlistId) {
    final channelId = element.getAttribute('channel');
    final startStr = element.getAttribute('start');
    final stopStr = element.getAttribute('stop');

    if (channelId == null || startStr == null || stopStr == null) {
      return null;
    }

    final startTime = parseXmltvDate(startStr);
    final endTime = parseXmltvDate(stopStr);

    if (startTime == null || endTime == null) {
      return null;
    }

    // Get title
    String title = '';
    final titleElements = element.findElements('title');
    if (titleElements.isNotEmpty) {
      title = titleElements.first.innerText.trim();
    }

    if (title.isEmpty) {
      title = 'Unknown Program';
    }

    // Get description
    String? description;
    final descElements = element.findElements('desc');
    if (descElements.isNotEmpty) {
      description = descElements.first.innerText.trim();
      if (description.isEmpty) description = null;
    }

    // Get category
    String? category;
    final categoryElements = element.findElements('category');
    if (categoryElements.isNotEmpty) {
      category = categoryElements.first.innerText.trim();
      if (category.isEmpty) category = null;
    }

    // Get icon/poster
    String? icon;
    final iconElements = element.findElements('icon');
    if (iconElements.isNotEmpty) {
      icon = iconElements.first.getAttribute('src');
    }

    final id = EpgProgram.generateId(channelId, startTime, playlistId);

    return EpgProgram(
      id: id,
      channelId: channelId,
      playlistId: playlistId,
      title: title,
      description: description,
      category: category,
      icon: icon,
      startTime: startTime,
      endTime: endTime,
    );
  }
}
