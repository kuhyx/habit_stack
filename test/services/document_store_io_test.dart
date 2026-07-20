import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_stack/services/document_store_io.dart';

/// Guarantees that belong to the file-backed store specifically.
///
/// These used to live in habit_storage_service_test, asserting against files
/// the service owned directly. Now that the service persists through a
/// [DocumentStore], the durability behaviour is this class's contract and is
/// tested here; the service's own tests cover parsing against an in-memory
/// store and no longer touch the disk.
void main() {
  late Directory tempDir;
  late FileDocumentStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('habit_stack_store_');
    store = FileDocumentStore(tempDir);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('read returns null when nothing has been written', () async {
    expect(await store.read('habits'), isNull);
  });

  test('write then read round-trips the document', () async {
    await store.write('habits', '[1,2,3]');
    expect(await store.read('habits'), '[1,2,3]');
  });

  test('write creates the parent directory when absent', () async {
    final nested = FileDocumentStore(
      Directory('${tempDir.path}/does/not/exist'),
    );
    await nested.write('habits', '[]');
    expect(await nested.read('habits'), '[]');
  });

  test('write leaves no temp file behind', () async {
    // Writes go to a temp file and are renamed into place, so a concurrent
    // reader never sees a half-written document; the temp must not survive.
    await store.write('habits', '[]');
    final entries = tempDir.listSync().map((e) => e.path);
    expect(entries, everyElement(isNot(contains('.tmp'))));
  });

  test(
    'read returns null when the file exists but is unreadable',
    () async {
      final file = File('${tempDir.path}/habits.json');
      await file.writeAsString('[]');
      await Process.run('chmod', ['000', file.path]);
      addTearDown(() => Process.runSync('chmod', ['644', file.path]));
      // Treated as absent rather than fatal, so the app still starts.
      expect(await store.read('habits'), isNull);
    },
    skip: Platform.isWindows ? 'chmod is POSIX-only' : false,
  );
}
