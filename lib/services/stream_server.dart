import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../models/content_type.dart';
import 'app_state.dart';
import 'player_state.dart';

class StreamInfo {
  final String? title;
  final String? type;
  final String? imagePath;
  final String url;
  final Map<String, String>? headers;

  StreamInfo({
    this.title,
    this.type,
    this.imagePath,
    required this.url,
    this.headers,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'type': type,
    'image': imagePath,
  };
}

class StreamServer {
  static const int defaultPort = 8080;
  static const int maxPort = 8090;

  HttpServer? _server;
  StreamInfo? _currentStream;
  String? _localIpAddress;
  int _port = defaultPort;
  final List<String> _connectedClients = [];

  bool get isRunning => _server != null;
  int get port => _port;
  String get localIpAddress => _localIpAddress ?? 'unknown';
  String get serverUrl => 'http://$localIpAddress:$_port/stream';
  String get infoUrl => 'http://$localIpAddress:$_port/info';
  List<String> get connectedClients => List.unmodifiable(_connectedClients);

  Future<String?> _getLocalIpAddress() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();
      if (wifiIP != null && wifiIP.isNotEmpty) {
        return wifiIP;
      }

      // Fallback: try to get IP from network interfaces
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        // Prefer interfaces that look like local network
        if (interface.name.toLowerCase().contains('en') ||
            interface.name.toLowerCase().contains('eth') ||
            interface.name.toLowerCase().contains('wlan')) {
          for (final addr in interface.addresses) {
            if (!addr.isLoopback && addr.address.startsWith('192.168.') ||
                addr.address.startsWith('10.') ||
                addr.address.startsWith('172.')) {
              return addr.address;
            }
          }
        }
      }

      // Last resort: return first non-loopback IPv4
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('Error getting local IP: $e');
    }
    return null;
  }

  Future<void> start([int port = defaultPort]) async {
    if (_server != null) {
      await stop();
    }

    _localIpAddress = await _getLocalIpAddress();
    if (_localIpAddress == null) {
      throw Exception('Could not determine local IP address');
    }

    final router = Router();

    // Health check endpoint
    router.get('/health', (Request request) {
      return Response.ok('OK', headers: _corsHeaders());
    });

    // Debug endpoint - shows current stream URL
    router.get('/debug', (Request request) {
      final debugInfo = {
        'hasStream': _currentStream != null,
        'streamUrl': _currentStream?.url,
        'title': _currentStream?.title,
        'type': _currentStream?.type,
        'serverRunning': isRunning,
        'localIp': _localIpAddress,
        'port': _port,
      };
      return Response.ok(
        jsonEncode(debugInfo),
        headers: _corsHeaders({'content-type': 'application/json'}),
      );
    });

    // Stream info endpoint
    router.get('/info', (Request request) {
      if (_currentStream == null) {
        return Response.notFound(
          jsonEncode({'error': 'No active stream'}),
          headers: _corsHeaders({'content-type': 'application/json'}),
        );
      }
      return Response.ok(
        jsonEncode(_currentStream!.toJson()),
        headers: _corsHeaders({'content-type': 'application/json'}),
      );
    });

    // Stream proxy endpoint
    router.get('/stream', _handleStreamRequest);
    router.get('/stream.m3u8', _handleStreamRequest);

    // HLS segment proxy
    router.get('/segment/<segment>', _handleSegmentRequest);

    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware())
        .addHandler(router.call);

    // Try ports in range
    for (var tryPort = port; tryPort <= maxPort; tryPort++) {
      try {
        _server = await shelf_io.serve(
          handler,
          InternetAddress.anyIPv4,
          tryPort,
        );
        _port = tryPort;
        print('Stream server started at http://$_localIpAddress:$_port');
        return;
      } catch (e) {
        if (tryPort == maxPort) {
          throw Exception('Could not bind to any port between $port and $maxPort');
        }
        print('Port $tryPort in use, trying next...');
      }
    }
  }

  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      _connectedClients.clear();
      print('Stream server stopped');
    }
  }

  void setCurrentStream(String url, {Map<String, String>? headers}) {
    final currentContent = PlayerState.currentContent;
    _currentStream = StreamInfo(
      url: url,
      headers: headers,
      title: currentContent?.name ?? PlayerState.title,
      type: currentContent?.contentType.name ?? 'unknown',
      imagePath: currentContent?.imagePath,
    );
  }

  void updateFromPlayerState() {
    final currentContent = PlayerState.currentContent;
    if (currentContent == null) return;

    // Priority: 1) originalStreamUrl, 2) content.url, 3) rebuild from playlist
    String? url = PlayerState.originalStreamUrl;

    // If original URL is not valid, try content URL
    if (url == null || url.isEmpty || url.startsWith('error://')) {
      url = currentContent.url;
    }

    // If still an error URL, try to rebuild it from playlist credentials
    if (url.startsWith('error://') || url.isEmpty) {
      url = _rebuildStreamUrl(currentContent);
    }

    // Still invalid? Don't update
    if (url.startsWith('error://') || url.isEmpty) {
      return;
    }

    _currentStream = StreamInfo(
      url: url,
      title: currentContent.name,
      type: currentContent.contentType.name,
      imagePath: currentContent.imagePath,
    );
  }

  /// Try to rebuild the stream URL from playlist credentials
  String _rebuildStreamUrl(dynamic content) {
    try {
      // Try source playlist first
      final playlistId = content.sourcePlaylistId;
      var playlist = playlistId != null ? AppState.getPlaylist(playlistId) : null;
      playlist ??= AppState.currentPlaylist;

      if (playlist == null ||
          playlist.url == null ||
          playlist.username == null ||
          playlist.password == null) {
        return 'error://no-playlist';
      }

      final contentId = content.id;
      final contentType = content.contentType as ContentType;
      final extension = content.containerExtension ?? 'ts';

      switch (contentType) {
        case ContentType.liveStream:
          return '${playlist.url}/${playlist.username}/${playlist.password}/$contentId';
        case ContentType.vod:
          return '${playlist.url}/movie/${playlist.username}/${playlist.password}/$contentId.$extension';
        case ContentType.series:
          return '${playlist.url}/series/${playlist.username}/${playlist.password}/$contentId.$extension';
      }
    } catch (e) {
      return 'error://rebuild-failed';
    }
  }

  void clearCurrentStream() {
    _currentStream = null;
  }

  Map<String, String> _corsHeaders([Map<String, String>? additional]) {
    final headers = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Range',
      'Access-Control-Expose-Headers': 'Content-Length, Content-Range',
    };
    if (additional != null) {
      headers.addAll(additional);
    }
    return headers;
  }

  Middleware _corsMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders());
        }
        final response = await handler(request);
        return response.change(headers: _corsHeaders());
      };
    };
  }

  Future<Response> _handleStreamRequest(Request request) async {
    // Only update if we don't have a valid stream yet
    if (_currentStream == null || _currentStream!.url.startsWith('error://')) {
      updateFromPlayerState();
    }

    if (_currentStream == null || _currentStream!.url.startsWith('error://')) {
      return Response.notFound(
        'No active stream. Make sure content is playing in the desktop app.',
        headers: _corsHeaders(),
      );
    }

    final clientIp = request.headers['x-forwarded-for'] ??
        request.context['shelf.io.connection_info'];
    if (clientIp != null && !_connectedClients.contains(clientIp.toString())) {
      _connectedClients.add(clientIp.toString());
    }

    try {
      final streamUrl = _currentStream!.url;
      final streamHeaders = Map<String, String>.from(_currentStream!.headers ?? {});

      // Add standard headers that IPTV servers expect
      streamHeaders['User-Agent'] ??= 'VLC/3.0.18 LibVLC/3.0.18';
      streamHeaders['Accept'] ??= '*/*';
      streamHeaders['Connection'] ??= 'keep-alive';

      // Add range header if present
      final rangeHeader = request.headers['range'];
      if (rangeHeader != null) {
        streamHeaders['Range'] = rangeHeader;
      }

      // Create HTTP client request
      final client = http.Client();
      final streamRequest = http.Request('GET', Uri.parse(streamUrl));
      streamHeaders.forEach((key, value) {
        streamRequest.headers[key] = value;
      });

      final streamResponse = await client.send(streamRequest);

      // Determine content type
      var contentType = streamResponse.headers['content-type'] ?? 'video/mp2t';
      if (streamUrl.contains('.m3u8')) {
        contentType = 'application/vnd.apple.mpegurl';
      } else if (streamUrl.contains('.ts')) {
        contentType = 'video/mp2t';
      }

      final responseHeaders = {
        'content-type': contentType,
        ..._corsHeaders(),
      };

      // Copy relevant headers from upstream
      if (streamResponse.headers['content-length'] != null) {
        responseHeaders['content-length'] = streamResponse.headers['content-length']!;
      }
      if (streamResponse.headers['content-range'] != null) {
        responseHeaders['content-range'] = streamResponse.headers['content-range']!;
      }

      // For HLS, rewrite playlist URLs to go through our proxy
      if (contentType.contains('mpegurl')) {
        final body = await streamResponse.stream.bytesToString();
        final rewrittenBody = _rewriteHlsPlaylist(body, streamUrl);
        return Response.ok(
          rewrittenBody,
          headers: responseHeaders,
        );
      }

      return Response(
        streamResponse.statusCode,
        body: streamResponse.stream,
        headers: responseHeaders,
      );
    } catch (e) {
      print('Stream proxy error: $e');
      return Response.internalServerError(
        body: 'Error proxying stream: $e',
        headers: _corsHeaders(),
      );
    }
  }

  String _rewriteHlsPlaylist(String playlist, String baseUrl) {
    final baseUri = Uri.parse(baseUrl);
    final lines = playlist.split('\n');
    final rewritten = <String>[];

    for (final line in lines) {
      if (line.isEmpty || line.startsWith('#')) {
        rewritten.add(line);
      } else {
        // This is a segment URL
        Uri segmentUri;
        if (line.startsWith('http://') || line.startsWith('https://')) {
          segmentUri = Uri.parse(line);
        } else if (line.startsWith('/')) {
          segmentUri = baseUri.replace(path: line);
        } else {
          // Relative URL
          final basePath = baseUri.path.substring(0, baseUri.path.lastIndexOf('/') + 1);
          segmentUri = baseUri.replace(path: basePath + line);
        }
        // Rewrite to go through our proxy
        final encodedUrl = Uri.encodeComponent(segmentUri.toString());
        rewritten.add('/segment/$encodedUrl');
      }
    }

    return rewritten.join('\n');
  }

  Future<Response> _handleSegmentRequest(Request request) async {
    final segment = request.params['segment'];
    if (segment == null) {
      return Response.notFound('Segment not specified');
    }

    try {
      final segmentUrl = Uri.decodeComponent(segment);
      final headers = Map<String, String>.from(_currentStream?.headers ?? {});

      // Add standard headers
      headers['User-Agent'] ??= 'VLC/3.0.18 LibVLC/3.0.18';
      headers['Accept'] ??= '*/*';
      headers['Connection'] ??= 'keep-alive';

      final client = http.Client();
      final segmentRequest = http.Request('GET', Uri.parse(segmentUrl));
      headers.forEach((key, value) {
        segmentRequest.headers[key] = value;
      });

      final segmentResponse = await client.send(segmentRequest);

      var contentType = segmentResponse.headers['content-type'] ?? 'video/mp2t';
      if (segmentUrl.contains('.m3u8')) {
        contentType = 'application/vnd.apple.mpegurl';
        final body = await segmentResponse.stream.bytesToString();
        final rewrittenBody = _rewriteHlsPlaylist(body, segmentUrl);
        return Response.ok(
          rewrittenBody,
          headers: {'content-type': contentType, ..._corsHeaders()},
        );
      }

      return Response(
        segmentResponse.statusCode,
        body: segmentResponse.stream,
        headers: {
          'content-type': contentType,
          if (segmentResponse.headers['content-length'] != null)
            'content-length': segmentResponse.headers['content-length']!,
          ..._corsHeaders(),
        },
      );
    } catch (e) {
      print('Segment proxy error: $e');
      return Response.internalServerError(
        body: 'Error proxying segment: $e',
        headers: _corsHeaders(),
      );
    }
  }
}
