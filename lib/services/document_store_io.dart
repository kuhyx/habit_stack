import 'dart:io';

import 'package:habit_stack/services/document_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// [DocumentStore] backed by one JSON file per document (Android).
class FileDocumentStore implements DocumentStore {
  /// Creates a store keeping its documents under [directory].
  FileDocumentStore(this.directory);

  /// Directory holding `<name>.json`.
  final Directory directory;

  File _fileFor(String name) => File(p.join(directory.path, '$name.json'));

  @override
  Future<String?> read(String name) async {
    final file = _fileFor(name);
    if (!file.existsSync()) return null;
    try {
      return await file.readAsString();
    } on FileSystemException {
      // An unreadable file is treated as absent; callers fall back to empty
      // rather than failing to start.
      return null;
    }
  }

  /// Writes to a per-process temp file then atomically renames it over the
  /// real one, so a concurrent reader never observes a half-written document.
  @override
  Future<void> write(String name, String contents) async {
    final file = _fileFor(name);
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.$pid.tmp');
    await tmp.writeAsString(contents);
    await tmp.rename(file.path);
  }
}

/// Opens the platform document store (the app's documents directory).
Future<DocumentStore> openDocumentStore() async =>
    FileDocumentStore(await getApplicationDocumentsDirectory());
