/// Shared constants between the web app and the desktop wrapper that serves it.
library;

/// The fixed port the desktop wrapper serves on.
///
/// **Do not change this casually.** IndexedDB is keyed by origin, so a
/// different port looks like a different app with no habits and no completion
/// history. The launcher and any packaging must use the same value.
const desktopWrapperPort = 8731;

/// Origin of the desktop wrapper, e.g. `http://localhost:8731`.
const desktopWrapperOrigin = 'http://localhost:$desktopWrapperPort';

/// URL paths the wrapper serves.
///
/// Kept beside the port so the client and server cannot drift apart; the
/// server mirrors this as `WrapperServer.documentsPrefix`.
abstract final class WrapperPaths {
  /// Prefix for document reads/writes: `/documents/<name>`.
  static const documents = '/documents/';
}
