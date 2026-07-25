import 'package:flutter/material.dart';

import '../api/api_client.dart';

/// Mixin for screens that load their data from the API in [load]. Shows a
/// spinner while loading and an error message on failure. Call [refresh] to
/// reload; wrap the ready UI with [buildLoad].
mixin LoadableState<T extends StatefulWidget> on State<T> {
  bool loading = true;
  String? loadError;

  /// Fetch the screen's data (repository `load()` calls go here).
  Future<void> load();

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (!loading) setState(() => loading = true);
    loadError = null;
    try {
      await load();
    } catch (e) {
      loadError = ApiClient.messageFor(e);
    }
    if (mounted) setState(() => loading = false);
  }

  /// Runs a mutation, shows any error as a snackbar, and refreshes the UI.
  Future<void> runMutation(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.messageFor(e))),
        );
      }
    }
  }

  Widget buildLoad(Widget Function() content) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(loadError!, textAlign: TextAlign.center),
        ),
      );
    }
    return content();
  }
}
