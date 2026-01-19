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

  /// Parse from URL (handles gzip)
  static Future<XmltvParseResult> parseFromUrl(String url, String playlistId) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept-Encoding': 'gzip, deflate',
          'User-Agent': 'IPTV Player',
        },
      ).timeout(const Duration(minutes: 2));

      if (response.statusCode != 200) {
        return XmltvParseResult(
          channels: [],
          programs: [],
          errorMessage: 'HTTP error ${response.statusCode}',
        );
      }

      String content;

      // Check if response is gzip compressed
      final contentEncoding = response.headers['content-encoding'];
      if (contentEncoding == 'gzip') {
        try {
          final decompressed = gzip.decode(response.bodyBytes);
          content = utf8.decode(decompressed);
        } catch (e) {
          // Try to decode as plain text if gzip fails
          content = utf8.decode(response.bodyBytes, allowMalformed: true);
        }
      } else {
        // Check if content starts with gzip magic bytes
        if (response.bodyBytes.length >= 2 &&
            response.bodyBytes[0] == 0x1f &&
            response.bodyBytes[1] == 0x8b) {
          try {
            final decompressed = gzip.decode(response.bodyBytes);
            content = utf8.decode(decompressed);
          } catch (e) {
            content = utf8.decode(response.bodyBytes, allowMalformed: true);
          }
        } else {
          content = utf8.decode(response.bodyBytes, allowMalformed: true);
        }
      }

      return await parse(content, playlistId);
    } catch (e) {
      return XmltvParseResult(
        channels: [],
        programs: [],
        errorMessage: 'Failed to fetch XMLTV: $e',
      );
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
