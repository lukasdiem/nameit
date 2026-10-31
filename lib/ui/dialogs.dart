import 'package:flutter/material.dart';

import '../l10n/strings.dart';

/// Small reusable dialogs.
Future<String?> askText(BuildContext context, {required String title, String initial = '', String? hint}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('cancel'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(ctx.tr('save'))),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, {required String title, String? message, String? action}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('cancel'))),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
            minimumSize: const Size(64, 40),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action ?? ctx.tr('delete')),
        ),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}
