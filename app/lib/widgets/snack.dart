import 'package:flutter/material.dart';

/// One-line feedback at the bottom of the screen (errors, confirmations).
void showSnack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
