import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../services/connectivity_service.dart';

class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityAsync = ref.watch(connectivityStateProvider);

    return connectivityAsync.when(
      data: (isConnected) {
        // Only show banner when offline
        if (isConnected) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context);
        final isRTL = Directionality.of(context) == TextDirection.rtl;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: 48,
          color: Colors.red.shade700,
          child: SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.wifi_off,
                    color: AppColors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      l10n.noInternetConnection,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}


