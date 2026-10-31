import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/family_provider.dart';
import '../providers/financial_provider.dart';
import '../providers/lookup_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tracking_provider.dart';
import 'signalr_sync_service.dart';

class DataSyncCoordinator extends StatefulWidget {
  final Widget child;

  const DataSyncCoordinator({super.key, required this.child});

  @override
  State<DataSyncCoordinator> createState() => _DataSyncCoordinatorState();
}

class _DataSyncCoordinatorState extends State<DataSyncCoordinator> {
  StreamSubscription<Set<String>>? _subscription;
  Timer? _debounceTimer;
  final Set<String> _pendingTables = {};

  @override
  void initState() {
    super.initState();
    _subscription = SignalRSyncService.instance.onTablesChanged.listen(_onTablesChanged);
  }

  void _onTablesChanged(Set<String> tables) {
    _pendingTables.addAll(tables.map((t) => t.toLowerCase()));
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 120), _dispatchPendingUpdates);
  }

  void _dispatchPendingUpdates() {
    if (!mounted || _pendingTables.isEmpty) return;

    final tables = Set<String>.from(_pendingTables);
    _pendingTables.clear();

    final isAll = tables.contains('*');

    // 1. الأسر والأفراد
    if (isAll ||
        tables.contains('osra') ||
        tables.contains('person') ||
        tables.contains('areas') ||
        tables.contains('streets')) {
      try {
        context.read<FamilyProvider>().refreshSilently();
      } catch (_) {}
    }

    // 2. الثوابت والقوائم المرجعية
    if (isAll ||
        tables.contains('areas') ||
        tables.contains('streets') ||
        tables.contains('fathers') ||
        tables.contains('karaba') ||
        tables.contains('mostwa') ||
        tables.contains('hala_egtimaia') ||
        tables.contains('hala_sehia') ||
        tables.contains('e_s') ||
        tables.contains('stage') ||
        tables.contains('khdma')) {
      try {
        context.read<LookupProvider>().refreshSilently();
      } catch (_) {}
    }

    // 3. الافتقاد والاعترافات والمناسبات
    if (isAll ||
        tables.contains('eatraf') ||
        tables.contains('visits') ||
        tables.contains('monasba') ||
        tables.contains('osra') ||
        tables.contains('person')) {
      try {
        context.read<TrackingProvider>().refreshSilently();
      } catch (_) {}
    }

    // 4. المساعدات والمصروفات
    if (isAll ||
        tables.contains('count_aid') ||
        tables.contains('count_2') ||
        tables.contains('masrofat')) {
      try {
        context.read<FinancialProvider>().refreshSilently();
      } catch (_) {}
    }

    // 5. المستخدمين والصلاحيات
    if (isAll ||
        tables.contains('users') ||
        tables.contains('inter_icon') ||
        tables.contains('icon')) {
      try {
        context.read<AuthProvider>().refreshSilently();
      } catch (_) {}
    }

    // 6. الإعدادات
    if (isAll || tables.contains('settings')) {
      try {
        context.read<SettingsProvider>().loadSettings();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
