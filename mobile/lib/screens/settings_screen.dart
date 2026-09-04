import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionLabel('Appearance'),
          SwitchListTile(
            title: const Text('Dark mode'),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: isDark,
            onChanged: (v) => ref.read(themeModeProvider.notifier).setDarkMode(v),
          ),
          const Divider(),
          const _SectionLabel('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Vick Mpesa'),
            subtitle: Text('Version 1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.security_outlined),
            title: Text('Security'),
            subtitle: Text(
                'This app communicates with Safaricom Daraja via a secure backend. '
                'Your M-PESA PIN is never collected or stored.'),
          ),
          const ListTile(
            leading: Icon(Icons.dns_outlined),
            title: Text('Backend'),
            subtitle: Text(AppConfig.apiBaseUrl),
          ),
          const ListTile(
            leading: Icon(Icons.warning_amber_outlined),
            title: Text('Limitations'),
            subtitle: Text(
                'Balance and full transaction history require Safaricom production onboarding. '
                'Only transactions initiated through this app are shown.'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.8)),
    );
  }
}
