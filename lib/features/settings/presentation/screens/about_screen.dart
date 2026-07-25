import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/constants/app_colors.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  // Reads the version/build embedded from pubspec.yaml at build time, so this
  // always reflects the build actually installed on the device.
  final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About DistillEd'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.draw,
                size: 64,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 24),
            const Text.rich(
              TextSpan(
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
                children: [
                  TextSpan(
                    text: 'Distill',
                    style: TextStyle(color: AppColors.accent),
                  ),
                  TextSpan(
                    text: 'Ed',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<PackageInfo>(
              future: _packageInfo,
              builder: (context, snapshot) {
                final info = snapshot.data;
                final label = info == null
                    ? 'Version …'
                    : 'Version ${info.version} (build ${info.buildNumber})';
                return Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 48.0),
              child: Text(
                'A beautifully simple, infinite-canvas note-taking app with no artificial limitations.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 48),
            TextButton(
              onPressed: () async {
                final info = await _packageInfo;
                if (!context.mounted) return;
                showLicensePage(
                  context: context,
                  applicationName: 'DistillEd',
                  applicationVersion: info.version,
                );
              },
              child: const Text('View Open Source Licenses'),
            ),
          ],
        ),
      ),
    );
  }
}
