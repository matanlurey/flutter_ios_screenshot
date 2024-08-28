import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter_driver/flutter_driver.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '_goldens.dart';

void main() async {
  // autoUpdateGoldenFiles = true;

  late final io.Directory tmpDir;
  late final FlutterDriver driver;
  late final String simulatorId;

  setUpAll(() async {
    tmpDir = await io.Directory.systemTemp.createTemp('flutter_driver');
    driver = await FlutterDriver.connect();
    simulatorId = await _iOSSimulatorId;
  });

  tearDownAll(() async {
    await tmpDir.delete(recursive: true);
    await driver.close();
  });

  test('take a screenshot using xcrun simctl', () async {
    final screenshot = await _takeScreenshot(
      simulatorId: simulatorId,
      tmpDir: tmpDir,
    );
    await expectLater(
      screenshot,
      matchesGoldenFile('xcrun_simctl_screenshot.png'),
    );
  });
}

Future<String> get _iOSSimulatorId async {
  const binary = 'xcrun';
  const args = [
    'simctl',
    'list',
    'devices',
    '--json',
  ];
  final result = await io.Process.run(binary, args);
  if (result.exitCode != 0) {
    throw const io.ProcessException(
      binary,
      args,
      'Failed to get simulator list',
    );
  }
  final json = jsonDecode(result.stdout as String) as Map<String, Object?>;
  final devices = json['devices'] as Map<String, Object?>;

  String? simulatorId;
  for (final value in devices.values) {
    final list = value as List<Object?>;
    if (list.isNotEmpty) {
      final simulator = list.first as Map<String, Object?>;
      if (simulator['isAvailable'] as bool && simulator['state'] == 'Booted') {
        if (simulatorId != null) {
          throw StateError(
            'More than one available simulator found: ${devices.keys}',
          );
        }
        simulatorId = simulator['udid'] as String;
        break;
      }
    }
  }

  if (simulatorId == null) {
    throw StateError('No available simulator found: ${devices.keys}');
  }

  return simulatorId;
}

Future<io.File> _takeScreenshot({
  required String simulatorId,
  required io.Directory tmpDir,
}) async {
  final screenshotPath = p.join(
    tmpDir.path,
    'screenshot.png',
  );
  const binary = 'xcrun';
  final args = [
    'simctl',
    'io',
    simulatorId,
    'screenshot',
    screenshotPath,
  ];
  final result = await io.Process.run(binary, args);
  if (result.exitCode != 0) {
    throw io.ProcessException(
      binary,
      args,
      'Failed to take a screenshot\n\n${result.stderr}',
      result.exitCode,
    );
  }
  return io.File(screenshotPath);
}
