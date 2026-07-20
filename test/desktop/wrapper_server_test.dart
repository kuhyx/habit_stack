import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_stack/desktop/wrapper_server.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late WrapperServer server;
  late String base;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('habit_wrapper');
    final webRoot = Directory(p.join(root.path, 'web'))..createSync();
    File(
      p.join(webRoot.path, 'index.html'),
    ).writeAsStringSync('<h1>habits</h1>');
    File(p.join(webRoot.path, 'main.dart.js')).writeAsStringSync('console;');
    File(p.join(webRoot.path, 'canvaskit.wasm')).writeAsStringSync('binary');

    server = WrapperServer(
      webRoot: webRoot.path,
      dataDir: p.join(root.path, 'data'),
    );
    // Port 0 lets the OS pick, so tests never collide with a running app.
    await server.start(0);
    base = 'http://localhost:${server.port}';
  });

  tearDown(() async {
    await server.stop();
    root.deleteSync(recursive: true);
  });

  test('serves index.html at the root', () async {
    final response = await http.get(Uri.parse('$base/'));
    expect(response.statusCode, 200);
    expect(response.body, contains('habits'));
  });

  test('serves assets and 404s unknown paths', () async {
    expect((await http.get(Uri.parse('$base/main.dart.js'))).statusCode, 200);
    expect((await http.get(Uri.parse('$base/nope.js'))).statusCode, 404);
  });

  test('labels wasm and js correctly', () async {
    // CanvasKit refuses a .wasm served as anything else, and the app then
    // renders nothing at all.
    final wasm = await http.get(Uri.parse('$base/canvaskit.wasm'));
    expect(wasm.headers['content-type'], contains('application/wasm'));
    final js = await http.get(Uri.parse('$base/main.dart.js'));
    expect(js.headers['content-type'], contains('javascript'));
  });

  test('POST then GET round-trips a document to disk', () async {
    final posted = await http.post(
      Uri.parse('$base/documents/habits'),
      body: jsonEncode([
        {'id': 'h1'},
      ]),
    );
    expect(posted.statusCode, 204);

    // The on-disk copy is the whole point: without sync, it is the only thing
    // standing between a cleared browser profile and total data loss.
    final onDisk = File(p.join(root.path, 'data', 'habits.json'));
    expect(onDisk.existsSync(), isTrue);
    expect(onDisk.readAsStringSync(), contains('h1'));

    final fetched = await http.get(Uri.parse('$base/documents/habits'));
    expect(fetched.statusCode, 200);
    expect(fetched.body, contains('h1'));
  });

  test('GET on a document that does not exist yet 404s', () async {
    expect(
      (await http.get(Uri.parse('$base/documents/completions'))).statusCode,
      404,
    );
  });

  test('rejects unsupported methods on a document', () async {
    final response = await http.delete(Uri.parse('$base/documents/habits'));
    expect(response.statusCode, 405);
  });

  test('rejects document names that could escape the data directory', () async {
    // Names become file names, so anything path-like must not be honoured.
    // A bare ".." is not tested here: Dart's HttpServer normalises it away
    // before any handler runs, so the request arrives as "/" and is served the
    // index page — it never reaches the documents branch at all.
    // 400 (our guard) and 404 (the path decoded into something with no
    // document) are both fine — what matters is that nothing is served.
    for (final name in ['a.b', 'nested%2Fname', 'x%2e%2e']) {
      final response = await http.get(Uri.parse('$base/documents/$name'));
      expect(
        response.statusCode,
        anyOf(400, 404),
        reason: 'name "$name" must not resolve to a file',
      );
    }

    // Seed a file next to the data directory and confirm no request can read
    // it — the property that actually matters.
    final secret = File(p.join(root.path, 'secret.json'))
      ..writeAsStringSync('do not serve me');
    addTearDown(secret.deleteSync);
    final probe = await http.get(Uri.parse('$base/documents/secret'));
    expect(probe.body, isNot(contains('do not serve me')));
  });

  test('a failing write reports a server error rather than crashing', () async {
    // Parent path is a regular file, so creating the data directory throws.
    // The serve loop must survive it and keep answering requests.
    final blocked = Directory(p.join(root.path, 'blocked'))..createSync();
    File(p.join(blocked.path, 'wall')).writeAsStringSync('');
    final wedged = WrapperServer(
      webRoot: p.join(root.path, 'web'),
      dataDir: p.join(blocked.path, 'wall', 'nested'),
    );
    await wedged.start(0);
    addTearDown(wedged.stop);

    final response = await http.post(
      Uri.parse('http://localhost:${wedged.port}/documents/habits'),
      body: 'x',
    );
    expect(response.statusCode, 500);

    final after = await http.get(Uri.parse('http://localhost:${wedged.port}/'));
    expect(after.statusCode, 200);
  });

  test('contentTypeFor covers the asset kinds the build emits', () {
    String kind(String name) => WrapperServer.contentTypeFor(name).mimeType;

    expect(kind('a.html'), 'text/html');
    expect(kind('a.json'), 'application/json');
    expect(kind('a.css'), 'text/css');
    expect(kind('a.png'), 'image/png');
    expect(kind('a.svg'), 'image/svg+xml');
    expect(kind('a.ttf'), 'font/ttf');
    expect(kind('a.otf'), 'font/otf');
    expect(kind('a.woff2'), 'font/woff2');
    expect(kind('a.mjs'), 'text/javascript');
    expect(kind('a.bin'), 'application/octet-stream');
  });
}
