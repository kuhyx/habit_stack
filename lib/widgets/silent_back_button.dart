/// Back arrow without the stock "Back" tooltip (textgate).
library;

import 'package:material_ui/material_ui.dart';

/// The AppBar leading for every screen: a back arrow when the route can
/// pop, nothing on the root route.
///
/// Material's [BackButton] always attaches a localized tooltip, which pops
/// up the word "Back" on long-press or hover. This keeps the arrow and the
/// spoken label but paints no word.
Widget? silentBackButton(BuildContext context) {
  if (!(ModalRoute.of(context)?.canPop ?? false)) return null;
  return Semantics(
    label: MaterialLocalizations.of(context).backButtonTooltip,
    button: true,
    excludeSemantics: true,
    child: IconButton(
      key: const Key('backButton'),
      icon: const BackButtonIcon(),
      onPressed: () => Navigator.maybePop(context),
    ),
  );
}
