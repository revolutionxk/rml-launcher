import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/features/studio/domain/install_ids.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';

void main() {
  test('names become lowercase folder ids', () {
    expect(installIdFor('Main', <String>[]), 'main');
    expect(installIdFor('Main copy', <String>[]), 'main-copy');
    expect(installIdFor('  Legacy 0.600!! ', <String>[]), 'legacy-0-600');
  });

  test('names that leave nothing usable become studio', () {
    expect(installIdFor('🎮', <String>[]), 'studio');
    expect(installIdFor('', <String>[]), 'studio');
  });

  test('non-ascii letters are dropped', () {
    expect(installIdFor('Ação', <String>[]), 'a-o');
  });

  test('windows device names get a suffix', () {
    expect(installIdFor('con', <String>[]), 'con-studio');
    expect(installIdFor('LPT1', <String>[]), 'lpt1-studio');
  });

  test('long names are cut to forty characters', () {
    final String id = installIdFor('a' * 200, <String>[]);
    expect(id, 'a' * 40);
  });

  test('taken ids get a number', () {
    expect(installIdFor('Main', <String>['main']), 'main-2');
    expect(installIdFor('Main', <String>['main', 'main-2']), 'main-3');
    expect(installIdFor('🎮', <String>['studio']), 'studio-2');
  });

  test('found ids are stable per root', () {
    const String root = r'C:\Users\João\AppData\Local\Bloxstrap\Versions';
    final String id = foundInstallId(InstallSource.bloxstrap, root);
    expect(id, matches(RegExp(r'^bloxstrap-[0-9a-f]{8}$')));
    expect(foundInstallId(InstallSource.bloxstrap, root), id);
    expect(foundInstallId(InstallSource.bloxstrap, '$root-other'), isNot(id));
    expect(
      foundInstallId(InstallSource.macBundle, '/Applications/RobloxStudio.app'),
      startsWith('mac-'),
    );
  });

  test('found ids can ignore case for windows paths', () {
    expect(
      foundInstallId(
        InstallSource.roblox,
        r'C:\Users\A\AppData\Local\Roblox\Versions',
        ignoreCase: true,
      ),
      foundInstallId(
        InstallSource.roblox,
        r'c:\users\a\appdata\local\roblox\versions',
        ignoreCase: true,
      ),
    );
  });
}
