import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_tool/main.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recovery_tool/core/service/storage_service.dart';
import 'package:recovery_tool/core/service/recovery_service.dart';
import 'package:recovery_tool/core/bloc/locale/locale_cubit.dart';
import 'package:recovery_tool/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:recovery_tool/features/scan/bloc/scan_bloc.dart';
import 'package:recovery_tool/core/service/premium_service.dart';
import 'package:recovery_tool/core/bloc/premium/premium_cubit.dart';

class FakeStorageService implements StorageService {
  @override
  Future<String?> getLanguage() async => 'vi';
  @override
  Future<void> setLanguage(String languageCode) async {}
  @override
  Future<bool> isOnboardingComplete() async => false;
  @override
  Future<void> setOnboardingComplete(bool complete) async {}
  
  @override
  Future<void> clearCache() async {}
  @override
  Future<void> clearPremiumData() async {}
  @override
  Future<DateTime?> getPremiumExpiry() async => null;
  @override
  Future<String?> getPremiumLicenseKey() async => null;
  @override
  Future<String?> getPremiumOutputDir() async => null;
  @override
  Future<bool> getPremiumStatus() async => false;
  @override
  Future<String?> getPremiumUserId() async => null;
  @override
  Future<bool> isPremiumExpired() async => false;
  @override
  Future<void> setPremiumExpiry(DateTime? expiryDate) async {}
  @override
  Future<void> setPremiumLicenseKey(String licenseKey) async {}
  @override
  Future<void> setPremiumOutputDir(String path) async {}
  @override
  Future<void> setPremiumStatus(bool isPremium) async {}
  @override
  Future<void> setPremiumUserId(String userId) async {}
}

class FakeRecoveryService implements RecoveryService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Onboarding screen shows technical title', (tester) async {
    final storageService = FakeStorageService();
    final recoveryService = FakeRecoveryService();
    final premiumService = PremiumService(storageService);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<StorageService>.value(value: storageService),
          RepositoryProvider<RecoveryService>.value(value: recoveryService),
          RepositoryProvider<PremiumService>.value(value: premiumService),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider(create: (context) => LocaleCubit(storageService)),
            BlocProvider(create: (context) => OnboardingCubit(storageService)),
            BlocProvider(create: (context) => PremiumCubit(premiumService, storageService)),
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
