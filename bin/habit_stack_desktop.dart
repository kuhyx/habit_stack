// coverage:ignore-file
// Entry point for the desktop wrapper: resolves real paths, starts the server,
// and launches the browser. The serving logic it delegates to is covered by
// test/desktop/wrapper_server_test.dart.
import 'dart:io';

import 'package:habit_stack/desktop/wrapper_server.dart';
import 'package:habit_stack/services/desktop_wrapper.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final home = Platform.environment['HOME'];
  if (home == null) {
    stderr.writeln('HOME is not set; cannot resolve the data directory.');
    exit(1);
  }

  // `dart build cli` emits bundle/bin/<exe> alongside bundle/lib/, so the
  // installed layout puts the web assets one level up. --web-root overrides for
  // development runs straight out of the repo.
  final webRoot =
      _argValue(args, '--web-root') ??
      p.normalize(p.join(p.dirname(Platform.resolvedExecutable), '..', 'web'));
  if (!Directory(webRoot).existsSync()) {
    stderr.writeln('web assets not found at $webRoot');
    exit(1);
  }

  // Overridable so a test run cannot point at the real habit data.
  final dataDir =
      _argValue(args, '--data-dir') ??
      p.join(home, '.local', 'share', 'habit-stack-desktop');

  final server = WrapperServer(webRoot: webRoot, dataDir: dataDir);
  await server.start(desktopWrapperPort);
  stdout.writeln('habit_stack serving on $desktopWrapperOrigin');

  if (!args.contains('--no-browser')) {
    final ranLongEnough = await _launchBrowser(home);
    if (!ranLongEnough) {
      // Chrome exits immediately when it hands the URL to an instance that
      // already owns the profile directory, or when a stale SingletonLock is
      // left behind. Shutting down here would pull the server out from under a
      // window that is still open, so keep serving instead.
      stdout.writeln(
        'Browser returned immediately (handed off to an existing window). '
        'Still serving on $desktopWrapperOrigin — Ctrl-C to stop.',
      );
      return;
    }
    await server.stop();
  }
}

/// Returns true when the browser ran long enough to have owned the session.
Future<bool> _launchBrowser(String home) async {
  // Deliberately broad: this machine runs Thorium behind /opt/google/chrome and
  // has a policy that uninstalls the `chromium` package, so assuming any single
  // browser is wrong. HABIT_STACK_BROWSER overrides.
  final candidates = [
    Platform.environment['HABIT_STACK_BROWSER'] ?? '',
    '/opt/google/chrome/chrome',
    '/opt/thorium-browser/thorium-browser',
    '/usr/bin/google-chrome-stable',
    '/usr/bin/chromium',
    '/usr/bin/brave',
  ];
  final browser = candidates.firstWhere(
    (path) => path.isNotEmpty && File(path).existsSync(),
    orElse: () => '',
  );
  if (browser.isEmpty) {
    stderr.writeln(
      'No Chrome-family browser found; open '
      '$desktopWrapperOrigin manually.',
    );
    return false;
  }

  // The profile directory must stay stable: IndexedDB (every habit and
  // completion) lives inside it, so a changing path silently hides the data.
  final profile = p.join(
    home,
    '.local',
    'share',
    'habit-stack-desktop',
    'profile',
  );
  final process = await Process.start(browser, [
    '--app=$desktopWrapperOrigin',
    '--user-data-dir=$profile',
    // Sets WM_CLASS so a .desktop entry's StartupWMClass can match, otherwise
    // the taskbar shows a browser icon.
    '--class=habit_stack',
    '--no-first-run',
  ]);

  final started = DateTime.now();
  await process.exitCode;
  return DateTime.now().difference(started) > const Duration(seconds: 5);
}

String? _argValue(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}
