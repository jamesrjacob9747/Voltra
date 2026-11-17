import 'package:flutter/material.dart';

/// One-line feedback at the bottom of the screen (errors, confirmations).
/// Replaces the snack showing and drops any still queued, so only the latest message appears.
void showSnack(BuildContext context, String message) => ScaffoldMessenger.of(context)
  ..clearSnackBars()
  ..showSnackBar(SnackBar(content: Text(message)));
