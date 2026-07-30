import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/theme/ink_colors.dart';

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
        backgroundColor: context.ink.surface,
        foregroundColor: context.ink.textPrimary,
        elevation: 0,
      ),
      backgroundColor: context.ink.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: context.ink.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.draw,
                size: 64,
                color: context.ink.accent,
              ),
            ),
            const SizedBox(height: 24),
            Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
                children: [
                  TextSpan(
                    text: 'Distill',
                    style: TextStyle(color: context.ink.accent),
                  ),
                  TextSpan(
                    text: 'Ed',
                    style: TextStyle(color: context.ink.textPrimary),
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
                  style: TextStyle(
                    fontSize: 16,
                    color: context.ink.textSecondary,
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: Text(
                'A beautifully simple, infinite-canvas note-taking app with no artificial limitations.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: context.ink.textSecondary,
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
