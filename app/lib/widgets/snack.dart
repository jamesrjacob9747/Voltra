import 'package:flutter/material.dart';

/// One-line feedback at the bottom of the screen (errors, confirmations).
/// Replaces any snack already showing, so messages never queue up behind each other.
void showSnack(BuildContext context, String message) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));
