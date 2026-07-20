/// Named-document persistence, independent of where the documents live.
library;

/// Reads and writes whole documents by name (`habits`, `completions`).
///
/// Deliberately free of `dart:io` so [HabitStorageService] can compile for
/// web: the desktop app is a Flutter web build, and a single `dart:io` import
/// anywhere in the graph fails the whole web compile. Implementations live in
/// `document_store_io.dart` (files) and `document_store_web.dart`
/// (IndexedDB), selected by the conditional export in
/// `document_store_factory.dart`.
///
/// Whole-document rather than key-value because both callers already
/// serialise a complete JSON structure, and a partial write of either would
/// be worse than none.
abstract class DocumentStore {
  /// Returns the stored contents of [name], or null if nothing is stored.
  Future<String?> read(String name);

  /// Overwrites [name] with [contents].
  Future<void> write(String name, String contents);
}

/// In-memory [DocumentStore] for tests.
///
/// Lets widget tests exercise the real storage service without touching the
/// filesystem, which also keeps them fast and free of temp-directory cleanup.
class InMemoryDocumentStore implements DocumentStore {
  /// Creates a store, optionally pre-seeded with [initial] documents.
  InMemoryDocumentStore([Map<String, String>? initial])
    : _documents = {...?initial};

  final Map<String, String> _documents;

  @override
  Future<String?> read(String name) async => _documents[name];

  @override
  Future<void> write(String name, String contents) async =>
      _documents[name] = contents;
}
