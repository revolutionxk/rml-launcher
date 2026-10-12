import 'dart:ffi';

import 'package:rml_launcher/core/platform/app_paths.dart';

enum CdnPlatform {
  windows(binaryTarget: 'WindowsStudio64', product: 'Studio64', folder: ''),
  macArm64(binaryTarget: 'MacStudio', product: 'Studio', folder: 'mac/arm64/'),
  macX64(binaryTarget: 'MacStudio', product: 'Studio', folder: 'mac/');

  const CdnPlatform({
    required this.binaryTarget,
    required this.product,
    required this.folder,
  });

  final String binaryTarget;
  final String product;
  final String folder;

  bool get isMac => this != windows;

  static CdnPlatform? forHost(HostOs os, Abi abi) => switch (os) {
    HostOs.windows => windows,
    HostOs.macos => abi == Abi.macosArm64 ? macArm64 : macX64,
    HostOs.linux => null,
  };
}

final class CdnEndpoints {
  const CdnEndpoints({
    required this.setup,
    required this.clientSettings,
    required this.ledger,
  });

  factory CdnEndpoints.local(Uri base) => CdnEndpoints(
    setup: base.resolve('setup/'),
    clientSettings: base.resolve('client-version/'),
    ledger: base.resolve('ledger.json'),
  );

  static final CdnEndpoints roblox = CdnEndpoints(
    setup: Uri.parse('https://setup.rbxcdn.com/'),
    clientSettings: Uri.parse(
      'https://clientsettingscdn.roblox.com/v2/client-version/',
    ),
    ledger: Uri.parse(
      'https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/refs/heads/roblox/version-history.json',
    ),
  );

  final Uri setup;
  final Uri clientSettings;
  final Uri ledger;
}
