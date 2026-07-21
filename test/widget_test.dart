import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_tool/main.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recovery_tool/core/service/storage_service.dart';
import 'package:recovery_tool/core/service/recovery_service.dart';
import 'package:recovery_tool/core/bloc/locale/locale_cubit.dart';
import 'package:recovery_tool/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:recovery_tool/features/scan/bloc/scan_bloc.dart';

import 'package:flutter/material.dart';

class FakeStorageService implements StorageService {
  @override
  Future<String?> getLanguage() async => 'vi';
  @override
  Future<void> setLanguage(String languageCode) async {}
  @override
  Future<bool> isOnboardingComplete() async => false;
  @override
  Future<void> setOnboardingComplete(bool complete) async {}
}

class FakeRecoveryService implements RecoveryService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Onboarding screen shows technical title', (tester) async {
    final storageService = FakeStorageService();
    final recoveryService = FakeRecoveryService();

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<StorageService>.value(value: storageService),
          RepositoryProvider<RecoveryService>.value(value: recoveryService),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider(create: (context) => LocaleCubit(storageService)),
            BlocProvider(create: (context) => OnboardingCubit(storageService)),
            BlocProvider(create: (context) => ScanBloc(recoveryService)),
          ],
          child: const MyApp(),
        ),
      ),
    );
    
    // Initial pump for loading state
    await tester.pump();
    // Pump again to process the future
    await tester.pump();

    expect(find.text('RECOVERY SD TOOL'), findsOneWidget);
    expect(find.text('BỎ QUA'), findsOneWidget);
  });
}
