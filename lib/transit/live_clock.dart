import 'dart:async';
import 'package:flutter/material.dart';

/// Refreshes time-dependent content only while visible and foregrounded.
class LiveClock extends StatefulWidget {
  const LiveClock({
    super.key,
    required this.builder,
    this.child,
    this.enabled = true,
  });
  final Widget Function(BuildContext, DateTime, Widget?) builder;
  final Widget? child;
  final bool enabled;
  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> with WidgetsBindingObserver {
  Timer? timer;
  bool visible = true;
  DateTime now = DateTime.now().toUtc();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void sync() {
    timer?.cancel();
    timer = null;
    final state = WidgetsBinding.instance.lifecycleState;
    if (!widget.enabled ||
        !visible ||
        (state != null && state != AppLifecycleState.resumed)) {
      return;
    }
    now = DateTime.now().toUtc();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => now = DateTime.now().toUtc());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    visible = TickerMode.valuesOf(context).enabled;
    sync();
  }

  @override
  void didUpdateWidget(covariant LiveClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    sync();
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, now, widget.child);
}
