import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Local HTTP server backing the desktop app.
///
/// The desktop app is a Flutter **web** build (Flutter's Linux embedder manages
/// only ~20fps at 4K), so it runs in a browser and cannot touch the filesystem.
/// This process is the other half of it: it serves the build and owns an
/// on-disk copy of every document.
///
/// That disk copy is not optional here. habit_stack has no sync yet, so
/// IndexedDB would otherwise be the *only* copy of the user's habits and
/// completion history, and clearing the browser profile would destroy both
/// irrecoverably.
///
/// Binds to loopback only: the document endpoints read and overwrite files in
/// the user's home directory with no authentication, so exposing them on a
/// routable address would let anything on the network rewrite them.
class WrapperServer {
  /// Creates a server serving [webRoot] and storing documents in [dataDir].
  WrapperServer({required this.webRoot, required this.dataDir});

  /// Directory holding the built Flutter web assets.
  final String webRoot;

  /// Directory holding `<name>.json` for each document.
  final String dataDir;

  /// Path prefix for document reads/writes.
  static const documentsPrefix = '/documents/';

  HttpServer? _server;

  /// Port the server is listening on, once [start] has completed.
  int get port => _server!.port;

  /// Binds to loopback on [requestedPort] and begins serving.
  ///
  /// Pass 0 to let the OS choose (tests do this); the launcher passes the fixed
  /// port, because the browser keys IndexedDB by origin — a changing port would
  /// silently hide the user's data behind an origin they no longer visit.
  Future<void> start(int requestedPort) async {
    _server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      requestedPort,
    );
    unawaited(_serve(_server!));
  }

  /// Stops serving and releases the port.
  Future<void> stop() async => _server?.close(force: true);

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      try {
        await _handle(request);
      } on Exception {
        request.response.statusCode = HttpStatus.internalServerError;
      }
      await request.response.close();
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    if (path.startsWith(documentsPrefix)) {
      final name = path.substring(documentsPrefix.length);
      // Document names become file names, so anything path-like is rejected
      // rather than allowed to escape dataDir.
      if (name.isEmpty || name.contains('/') || name.contains('.')) {
        request.response.statusCode = HttpStatus.badRequest;
        return;
      }
      return _document(request, p.join(dataDir, '$name.json'));
    }
    return _static(request, path);
  }

  /// GET returns the document (404 when absent); POST overwrites it.
  Future<void> _document(HttpRequest request, String filePath) async {
    final file = File(filePath);
    if (request.method == 'POST') {
      await file.parent.create(recursive: true);
      await file.writeAsString(await utf8.decodeStream(request));
      request.response.statusCode = HttpStatus.noContent;
      return;
    }
    if (request.method != 'GET') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      return;
    }
    if (!file.existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
      return;
    }
    request.response.headers.contentType = ContentType.text;
    request.response.write(await file.readAsString());
  }

  Future<void> _static(HttpRequest request, String path) async {
    final relative = path == '/' ? 'index.html' : path.substring(1);
    final resolved = p.normalize(p.join(webRoot, relative));
    // coverage:ignore-start
    // Defence in depth, and currently unreachable: Dart's HttpServer decodes
    // and normalises the path before a handler runs, so even `%2e%2e` arrives
    // already collapsed. Kept so the guarantee does not depend on that.
    if (!p.isWithin(webRoot, resolved) && resolved != p.normalize(webRoot)) {
      request.response.statusCode = HttpStatus.forbidden;
      return;
    }
    // coverage:ignore-end
    final file = File(resolved);
    if (!file.existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
      return;
    }
    request.response.headers.contentType = contentTypeFor(resolved);
    await request.response.addStream(file.openRead());
  }

  /// Content type for [filePath].
  ///
  /// Flutter web is strict here: CanvasKit refuses to instantiate a `.wasm`
  /// served as anything but `application/wasm`, and the app then silently
  /// fails to render.
  static ContentType contentTypeFor(String filePath) {
    switch (p.extension(filePath).toLowerCase()) {
      case '.html':
        return ContentType.html;
      case '.js' || '.mjs':
        return ContentType('text', 'javascript', charset: 'utf-8');
      case '.json':
        return ContentType.json;
      case '.wasm':
        return ContentType('application', 'wasm');
      case '.css':
        return ContentType('text', 'css', charset: 'utf-8');
      case '.png':
        return ContentType('image', 'png');
      case '.svg':
        return ContentType('image', 'svg+xml');
      case '.ttf':
        return ContentType('font', 'ttf');
      case '.otf':
        return ContentType('font', 'otf');
      case '.woff2':
        return ContentType('font', 'woff2');
      default:
        return ContentType.binary;
    }
  }
}
