import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';
import '../theme.dart';

/// One destination of the bottom navigation bar.
class ShellTab {
  const ShellTab({required this.label, required this.icon, required this.selectedIcon, required this.builder});

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Builds the tab's screen. [visit] goes up by one each time the tab is opened again, so a
  /// screen can reload when the user comes back to it (see `didUpdateWidget` in the screens).
  final Widget Function(BuildContext context, int visit) builder;
}

/// The app's home frame: a bottom navigation bar over tabs that keep their state.
///
/// A tab is built the first time it is opened and then kept alive, so scroll positions and
/// loaded data survive switching. The incoming tab fades and settles into place.
class TabShell extends StatefulWidget {
  const TabShell({super.key, required this.tabs});

  final List<ShellTab> tabs;

  /// Lets a screen inside the shell jump to another tab: `TabShell.of(context)?.goTo(0)`.
  static TabShellState? of(BuildContext context) => context.findAncestorStateOfType<TabShellState>();

  @override
  State<TabShell> createState() => TabShellState();
}

class TabShellState extends State<TabShell> {
  int _index = 0;
  late final List<int> _visits = List.filled(widget.tabs.length, 0);
  late final Set<int> _opened = {0};

  int get index => _index;

  void goTo(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _index = index;
      _opened.add(index);
      _visits[index]++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final still = Motion.reduced(context);
    return PopScope(
      // Back from any other tab returns Home first; back on Home leaves the app.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goTo(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            for (final (i, tab) in widget.tabs.indexed)
              if (!_opened.contains(i))
                const SizedBox.shrink()
              else
                AnimatedOpacity(
                  opacity: i == _index ? 1 : 0,
                  duration: still ? Duration.zero : Motion.medium,
                  curve: Motion.enter,
                  child: AnimatedScale(
                    scale: i == _index || still ? 1 : 0.98,
                    duration: still ? Duration.zero : Motion.medium,
                    curve: Motion.enter,
                    child: tab.builder(context, _visits[i]),
                  ),
                ),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.vc.border)),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: goTo,
            destinations: [
              for (final tab in widget.tabs)
                NavigationDestination(icon: Icon(tab.icon), selectedIcon: Icon(tab.selectedIcon), label: tab.label),
            ],
          ),
        ),
      ),
    );
  }
}
