import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/features/studio/data/cdn/deploy_history.dart';

void main() {
  test('vector A keeps Studio lines newest first', () {
    const String text =
        'New Studio version-hidden at 9/14/2026 4:07:58 PM, file version: 0, 739, 0, 7390687, git hash: 0.739.0.7390687 ...Done!\n'
        '\n'
        'New Client version-hidden at 9/14/2026 4:31:45 PM, file version: 0,739,0,7390687, git hash: 0.739.0.7390687 ...Done!\n'
        '\n'
        'New StudioBeta version-637cf81b9e084588 at 1/20/2017 1:56:22 AM, file version: 0, 274, 0, 101540...Done!\n'
        'Revert Studio version-48a14a101efa4802 at 1/30/2013 4:09:49 PM...Done!\n'
        'New Studio version-a9a2351562de41c8 at 5/24/2021 3:14:21 PM, file version: 0, 480, 0, 423050, git hash: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ...Done!\n'
        'New Studio version-4c966efb76b842b0 at 6/29/2012 1:13:09 AM, file version: 0, 65, 0, 596...Done!\n'
        'New Studio version-deadbeefdeadbeef at 6/30/2012 1:13:09 AM, file version: 0, 66, 0, 600...Error!\n'
        'New Studio version-hidden at 9/8/2026 10:20:11 AM, file version: 0, 738, 0, 7381393, git hash: 0.738.0.7381393 ...Done!\n';
    final List<DeployedBuild> history = parseDeployHistory(
      text,
      product: 'Studio',
    );
    expect(history.map((DeployedBuild build) => build.version.text), <String>[
      '0.738.0.7381393',
      '0.65.0.596',
      '0.480.0.423050',
      '0.739.0.7390687',
    ]);
    expect(history[3].publishedAt, DateTime.utc(2026, 9, 14, 16, 7, 58));
    expect(history[0].publishedAt, DateTime.utc(2026, 9, 8, 10, 20, 11));
  });

  test('vector B keeps the latest line of a repeated Studio64 version', () {
    const String text =
        'New Studio64 version-older-guid at 4/14/2026 10:05:34 AM, file version: 0, 717, 0, 7170978, git hash: 0.717.0.7170978 ...\n'
        'New Studio64 version-hidden at 4/15/2026 10:08:30 AM, file version: 0, 717, 0, 7170982, git hash: 0.717.0.7170982 ...\n'
        'New Studio version-wrong-product at 4/15/2026 10:08:30 AM, file version: 0, 717, 0, 7170982, git hash: 0.717.0.7170982 ...\n'
        'New Studio64 version-recent-guid at 4/21/2026 1:46:52 PM, file version: 0, 718, 0, 7181104, git hash: 0.718.0.7181104 ...\n'
        'New Studio64 version-recent-guid at 4/21/2026 1:48:11 PM, file version: 0, 718, 0, 7181104, git hash: 0.718.0.7181104 ...\n';
    final List<DeployedBuild> history = parseDeployHistory(
      text,
      product: 'Studio64',
    );
    expect(history.map((DeployedBuild build) => build.version.text), <String>[
      '0.718.0.7181104',
      '0.717.0.7170982',
      '0.717.0.7170978',
    ]);
    expect(history.first.publishedAt, DateTime.utc(2026, 4, 21, 13, 48, 11));
  });

  test('windows line endings and noon and midnight parse', () {
    const String text =
        'New Studio64 version-a at 1/2/2026 12:00:01 AM, file version: 0, 1, 0, 1 ...\r\n'
        'New Studio64 version-b at 01/02/2026 12:30:00 PM, file version: 0, 2, 0, 1 ...\r\n';
    final List<DeployedBuild> history = parseDeployHistory(
      text,
      product: 'Studio64',
    );
    expect(history[0].publishedAt, DateTime.utc(2026, 1, 2, 12, 30));
    expect(history[1].publishedAt, DateTime.utc(2026, 1, 2, 0, 0, 1));
  });
}
