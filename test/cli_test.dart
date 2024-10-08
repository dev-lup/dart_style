// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'utils.dart';

void main() {
  compileFormatter();

  test('formats a directory', () async {
    await d.dir('code', [
      d.file('a.dart', unformattedSource),
      d.file('b.dart', formattedSource),
      d.file('c.dart', unformattedSource)
    ]).create();

    var process = await runFormatterOnDir();
    expect(await process.stdout.next, 'Formatted ${p.join('code', 'a.dart')}');
    expect(await process.stdout.next, 'Formatted ${p.join('code', 'c.dart')}');
    expect(await process.stdout.next,
        startsWith(r'Formatted 3 files (2 changed)'));
    await process.shouldExit(0);

    // Overwrites the files.
    await d.dir('code', [d.file('a.dart', formattedSource)]).validate();
    await d.dir('code', [d.file('c.dart', formattedSource)]).validate();
  });

  test('formats multiple paths', () async {
    await d.dir('code', [
      d.dir('subdir', [
        d.file('a.dart', unformattedSource),
      ]),
      d.file('b.dart', unformattedSource),
      d.file('c.dart', unformattedSource)
    ]).create();

    var process = await runFormatter(
        [p.join('code', 'subdir'), p.join('code', 'c.dart')]);
    expect(await process.stdout.next,
        'Formatted ${p.join('code', 'subdir', 'a.dart')}');
    expect(await process.stdout.next, 'Formatted ${p.join('code', 'c.dart')}');
    expect(await process.stdout.next,
        startsWith(r'Formatted 2 files (2 changed)'));
    await process.shouldExit(0);

    // Overwrites the selected files.
    await d.dir('code', [
      d.dir('subdir', [
        d.file('a.dart', formattedSource),
      ]),
      d.file('b.dart', unformattedSource),
      d.file('c.dart', formattedSource)
    ]).validate();
  });

  test('exits with 64 on a command line argument error', () async {
    var process = await runFormatter(['-wat']);
    await process.shouldExit(64);
  });

  test('exits with 65 on a parse error', () async {
    await d.dir('code', [d.file('a.dart', 'herp derp i are a dart')]).create();

    var process = await runFormatterOnDir();
    await process.shouldExit(65);
  });

  group('--show', () {
    test('all shows all files', () async {
      await d.dir('code', [
        d.file('a.dart', unformattedSource),
        d.file('b.dart', formattedSource),
        d.file('c.dart', unformattedSource)
      ]).create();

      var process = await runFormatterOnDir(['--show=all']);
      expect(
          await process.stdout.next, 'Formatted ${p.join('code', 'a.dart')}');
      expect(
          await process.stdout.next, 'Unchanged ${p.join('code', 'b.dart')}');
      expect(
          await process.stdout.next, 'Formatted ${p.join('code', 'c.dart')}');
      expect(await process.stdout.next,
          startsWith(r'Formatted 3 files (2 changed)'));
      await process.shouldExit(0);
    });

    test('none shows nothing', () async {
      await d.dir('code', [
        d.file('a.dart', unformattedSource),
        d.file('b.dart', formattedSource),
        d.file('c.dart', unformattedSource)
      ]).create();

      var process = await runFormatterOnDir(['--show=none']);
      expect(await process.stdout.next,
          startsWith(r'Formatted 3 files (2 changed)'));
      await process.shouldExit(0);
    });

    test('changed shows changed files', () async {
      await d.dir('code', [
        d.file('a.dart', unformattedSource),
        d.file('b.dart', formattedSource),
        d.file('c.dart', unformattedSource)
      ]).create();

      var process = await runFormatterOnDir(['--show=changed']);
      expect(
          await process.stdout.next, 'Formatted ${p.join('code', 'a.dart')}');
      expect(
          await process.stdout.next, 'Formatted ${p.join('code', 'c.dart')}');
      expect(await process.stdout.next,
          startsWith(r'Formatted 3 files (2 changed)'));
      await process.shouldExit(0);
    });
  });

  group('--output', () {
    group('show', () {
      test('prints only formatted output by default', () async {
        await d.dir('code', [
          d.file('a.dart', unformattedSource),
          d.file('b.dart', formattedSource)
        ]).create();

        var process = await runFormatterOnDir(['--output=show']);
        expect(await process.stdout.next, formattedOutput);
        expect(await process.stdout.next, formattedOutput);
        expect(await process.stdout.next,
            startsWith(r'Formatted 2 files (1 changed)'));
        await process.shouldExit(0);

        // Does not overwrite files.
        await d.dir('code', [d.file('a.dart', unformattedSource)]).validate();
      });

      test('with --show=all prints all files and names first', () async {
        await d.dir('code', [
          d.file('a.dart', unformattedSource),
          d.file('b.dart', formattedSource)
        ]).create();

        var process = await runFormatterOnDir(['--output=show', '--show=all']);
        expect(
            await process.stdout.next, 'Changed ${p.join('code', 'a.dart')}');
        expect(await process.stdout.next, formattedOutput);
        expect(
            await process.stdout.next, 'Unchanged ${p.join('code', 'b.dart')}');
        expect(await process.stdout.next, formattedOutput);
        expect(await process.stdout.next,
            startsWith(r'Formatted 2 files (1 changed)'));
        await process.shouldExit(0);

        // Does not overwrite files.
        await d.dir('code', [d.file('a.dart', unformattedSource)]).validate();
      });

      test('with --show=changed prints only changed files', () async {
        await d.dir('code', [
          d.file('a.dart', unformattedSource),
          d.file('b.dart', formattedSource)
        ]).create();

        var process =
            await runFormatterOnDir(['--output=show', '--show=changed']);
        expect(
            await process.stdout.next, 'Changed ${p.join('code', 'a.dart')}');
        expect(await process.stdout.next, formattedOutput);
        expect(await process.stdout.next,
            startsWith(r'Formatted 2 files (1 changed)'));
        await process.shouldExit(0);

        // Does not overwrite files.
        await d.dir('code', [d.file('a.dart', unformattedSource)]).validate();
      });
    });

    group('json', () {
      test('writes each output as json', () async {
        await d.dir('code', [
          d.file('a.dart', unformattedSource),
          d.file('b.dart', unformattedSource)
        ]).create();

        var jsonA = jsonEncode({
          'path': p.join('code', 'a.dart'),
          'source': formattedSource,
          'selection': {'offset': -1, 'length': -1}
        });

        var jsonB = jsonEncode({
          'path': p.join('code', 'b.dart'),
          'source': formattedSource,
          'selection': {'offset': -1, 'length': -1}
        });

        var process = await runFormatterOnDir(['--output=json']);

        expect(await process.stdout.next, jsonA);
        expect(await process.stdout.next, jsonB);
        await process.shouldExit();
      });

      test('errors if the summary is not none', () async {
        var process =
            await runFormatterOnDir(['--output=json', '--summary=line']);
        await process.shouldExit(64);
      });
    });

    group('none', () {
      test('with --show=all prints only names', () async {
        await d.dir('code', [
          d.file('a.dart', unformattedSource),
          d.file('b.dart', formattedSource)
        ]).create();

        var process = await runFormatterOnDir(['--output=none', '--show=all']);
        expect(
            await process.stdout.next, 'Changed ${p.join('code', 'a.dart')}');
        expect(
            await process.stdout.next, 'Unchanged ${p.join('code', 'b.dart')}');
        expect(await process.stdout.next,
            startsWith(r'Formatted 2 files (1 changed)'));
        await process.shouldExit(0);

        // Does not overwrite files.
        await d.dir('code', [d.file('a.dart', unformattedSource)]).validate();
      });

      test('with --show=changed prints only changed names', () async {
        await d.dir('code', [
          d.file('a.dart', unformattedSource),
          d.file('b.dart', formattedSource)
        ]).create();

        var process =
            await runFormatterOnDir(['--output=none', '--show=changed']);
        expect(
            await process.stdout.next, 'Changed ${p.join('code', 'a.dart')}');
        expect(await process.stdout.next,
            startsWith(r'Formatted 2 files (1 changed)'));
        await process.shouldExit(0);

        // Does not overwrite files.
        await d.dir('code', [d.file('a.dart', unformattedSource)]).validate();
      });
    });
  });

  group('--summary', () {
    test('line', () async {
      await d.dir('code', [
        d.file('a.dart', unformattedSource),
        d.file('b.dart', formattedSource)
      ]).create();

      var process = await runFormatterOnDir(['--summary=line']);
      expect(
          await process.stdout.next, 'Formatted ${p.join('code', 'a.dart')}');
      expect(await process.stdout.next,
          matches(r'Formatted 2 files \(1 changed\) in \d+\.\d+ seconds.'));
      await process.shouldExit(0);
    });
  });

  test('--version prints the version number', () async {
    var process = await runFormatter(['--version']);

    // Match something roughly semver-like.
    expect(await process.stdout.next, matches(RegExp(r'\d+\.\d+\.\d+.*')));
    await process.shouldExit(0);
  });

  group('--help', () {
    test('non-verbose shows description and common options', () async {
      var process = await runFormatter(['--help']);
      expect(
          await process.stdout.next, 'Idiomatically format Dart source code.');
      await expectLater(process.stdout, emitsThrough(contains('-o, --output')));
      await expectLater(process.stdout, neverEmits(contains('--summary')));
      await process.shouldExit(0);
    });

    test('verbose shows description and all options', () async {
      var process = await runFormatter(['--help', '--verbose']);
      expect(
          await process.stdout.next, 'Idiomatically format Dart source code.');
      await expectLater(process.stdout, emitsThrough(contains('-o, --output')));
      await expectLater(process.stdout, emitsThrough(contains('--show')));
      await expectLater(process.stdout, emitsThrough(contains('--summary')));
      await process.shouldExit(0);
    });
  });

  test('--verbose errors if not used with --help', () async {
    var process = await runFormatterOnDir(['--verbose']);
    expect(await process.stderr.next, 'Can only use --verbose with --help.');
    await process.shouldExit(64);
  });

  group('--indent', () {
    test('sets the leading indentation of the output', () async {
      var process = await runFormatter(['--indent=3']);
      process.stdin.writeln("main() {'''");
      process.stdin.writeln("a flush left multi-line string''';}");
      await process.stdin.close();

      expect(await process.stdout.next, '   main() {');
      expect(await process.stdout.next, "     '''");
      expect(await process.stdout.next, "a flush left multi-line string''';");
      expect(await process.stdout.next, '   }');
      await process.shouldExit(0);
    });

    test('errors if the indent is not a non-negative number', () async {
      var process = await runFormatter(['--indent=notanum']);
      await process.shouldExit(64);

      process = await runFormatter(['--indent=-4']);
      await process.shouldExit(64);
    });
  });

  group('--set-exit-if-changed', () {
    test('gives exit code 0 if there are no changes', () async {
      await d.dir('code', [d.file('a.dart', formattedSource)]).create();

      var process = await runFormatterOnDir(['--set-exit-if-changed']);
      await process.shouldExit(0);
    });

    test('gives exit code 1 if there are changes', () async {
      await d.dir('code', [d.file('a.dart', unformattedSource)]).create();

      var process = await runFormatterOnDir(['--set-exit-if-changed']);
      await process.shouldExit(1);
    });

    test('gives exit code 1 if there are changes when not writing', () async {
      await d.dir('code', [d.file('a.dart', unformattedSource)]).create();

      var process =
          await runFormatterOnDir(['--set-exit-if-changed', '--show=none']);
      await process.shouldExit(1);
    });
  });

  group('--selection', () {
    test('errors if given path', () async {
      var process = await runFormatter(['--selection', 'path']);
      await process.shouldExit(64);
    });

    test('errors on wrong number of components', () async {
      var process = await runFormatter(['--selection', '1']);
      await process.shouldExit(64);

      process = await runFormatter(['--selection', '1:2:3']);
      await process.shouldExit(64);
    });

    test('errors on non-integer component', () async {
      var process = await runFormatter(['--selection', '1:2.3']);
      await process.shouldExit(64);
    });

    test('updates selection', () async {
      var process = await runFormatter(['--output=json', '--selection=6:10']);
      process.stdin.writeln(unformattedSource);
      await process.stdin.close();

      var json = jsonEncode({
        'path': 'stdin',
        'source': formattedSource,
        'selection': {'offset': 5, 'length': 9}
      });

      expect(await process.stdout.next, json);
      await process.shouldExit();
    });
  });

  group('--stdin-name', () {
    test('errors if also given path', () async {
      var process = await runFormatter(['--stdin-name=name', 'path']);
      await process.shouldExit(64);
    });

    test('infers language version from surrounding package', () async {
      // The package config sets the language version to 3.1, but the switch
      // case uses a syntax which is valid in earlier versions of Dart but an
      // error in 3.0 and later. Verify that the error is reported.
      await d.dir('foo', [
        packageConfig('foo', 2, 19),
      ]).create();

      var process = await runFormatter(
          ['--enable-experiment=tall-style', '--stdin-name=foo/main.dart']);
      // Write a switch whose syntax is valid in 2.19, but an error in later
      // versions.
      process.stdin.writeln('main() { switch (o) { case 1 + 2: break; } }');
      await process.stdin.close();

      expect(await process.stdout.next, 'main() {');
      expect(await process.stdout.next, '  switch (o) {');
      expect(await process.stdout.next, '    case 1 + 2:');
      expect(await process.stdout.next, '      break;');
      expect(await process.stdout.next, '  }');
      expect(await process.stdout.next, '}');
      await process.shouldExit(0);
    });

    test('no package search if language version is specified', () async {
      // Put the stdin-name in a directory with a malformed package config. If
      // we search for it, we should get an error.
      await d.dir('foo', [
        d.dir('.dart_tool', [
          d.file('package_config.json', 'this no good json is bad json'),
        ]),
        d.file('main.dart', 'main(){    }'),
      ]).create();

      var process = await runFormatter([
        '--language-version=2.19',
        '--enable-experiment=tall-style',
        '--stdin-name=foo/main.dart'
      ]);

      // Write a switch whose syntax is valid in 2.19, but an error in later
      // versions.
      process.stdin.writeln('main() { switch (o) { case 1 + 2: break; } }');
      await process.stdin.close();

      expect(await process.stdout.next, 'main() {');
      expect(await process.stdout.next, '  switch (o) {');
      expect(await process.stdout.next, '    case 1 + 2:');
      expect(await process.stdout.next, '      break;');
      expect(await process.stdout.next, '  }');
      expect(await process.stdout.next, '}');
      await process.shouldExit(0);
    });
  });

  group('language version', () {
    // It's hard to validate that the formatter uses the *exact* latest
    // language version supported by the formatter, but at least test that a
    // new-ish language feature can be parsed.
    const extensionTypeBefore = '''
extension type Meters(int value) {
  Meters operator+(Meters other) => Meters(value+other.value);
}''';

    const extensionTypeAfter = '''
extension type Meters(int value) {
  Meters operator +(Meters other) => Meters(value + other.value);
}
''';

    test('defaults to latest language version if omitted', () async {
      await d.dir('code', [d.file('a.dart', extensionTypeBefore)]).create();

      var process = await runFormatterOnDir();
      await process.shouldExit(0);

      await d.dir('code', [d.file('a.dart', extensionTypeAfter)]).validate();
    });

    test('uses the given language version', () async {
      const before = 'main() { switch (o) { case 1+2: break; } }';

      const after = '''
main() {
  switch (o) {
    case 1 + 2:
      break;
  }
}
''';

      await d.dir('code', [d.file('a.dart', before)]).create();

      // Use an older language version where `1 + 2` was still a valid switch
      // case.
      var process = await runFormatterOnDir(['--language-version=2.19']);
      await process.shouldExit(0);

      await d.dir('code', [d.file('a.dart', after)]).validate();
    });

    test('uses the latest language version if "latest"', () async {
      await d.dir('code', [d.file('a.dart', extensionTypeBefore)]).create();

      var process = await runFormatterOnDir(['--language-version=latest']);
      await process.shouldExit(0);

      await d.dir('code', [d.file('a.dart', extensionTypeAfter)]).validate();
    });

    test("errors if the language version can't be parsed", () async {
      var process = await runFormatter(['--language-version=123']);
      await process.shouldExit(64);
    });
  });

  group('--enable-experiment', () {
    test('passes experiment flags to parser', () async {
      var process =
          await runFormatter(['--enable-experiment=test-experiment,variance']);
      process.stdin.writeln('class Writer<in T> {}');
      await process.stdin.close();

      // The formatter doesn't actually support formatting variance annotations,
      // but we want to test that the experiment flags are passed all the way
      // to the parser, so just test that it parses the variance annotation
      // without errors and then fails to format.
      expect(await process.stderr.next,
          'Hit a bug in the formatter when formatting stdin.');
      expect(await process.stderr.next,
          'Please report at: github.com/dart-lang/dart_style/issues');
      expect(await process.stderr.next,
          'The formatter produced unexpected output. Input was:');
      expect(await process.stderr.next, 'class Writer<in T> {}');
      expect(await process.stderr.next, '');
      expect(await process.stderr.next, 'Which formatted to:');
      expect(await process.stderr.next, 'class Writer<T> {}');
      await process.shouldExit(70);
    });
  });

  group('with no paths', () {
    test('errors on --output=write', () async {
      var process = await runFormatter(['--output=write']);
      await process.shouldExit(64);
    });

    test('exits with 65 on parse error', () async {
      var process = await runFormatter();
      process.stdin.writeln('herp derp i are a dart');
      await process.stdin.close();
      await process.shouldExit(65);
    });

    test('reads from stdin', () async {
      var process = await runFormatter();
      process.stdin.writeln(unformattedSource);
      await process.stdin.close();

      // No trailing newline at the end.
      expect(await process.stdout.next, formattedOutput);
      await process.shouldExit(0);
    });

    test('allows specifying stdin path name', () async {
      var path = p.join('some', 'path.dart');
      var process = await runFormatter(['--stdin-name=$path']);
      process.stdin.writeln('herp');
      await process.stdin.close();

      expect(await process.stderr.next,
          'Could not format because the source could not be parsed:');
      expect(await process.stderr.next, '');
      expect(await process.stderr.next, contains(path));
      await process.stderr.cancel();
      await process.shouldExit(65);
    });
  });

  group('package config', () {
    // TODO(rnystrom): Remove this test when the experiment ships.
    test('no package search if experiment is off', () async {
      // Put the file in a directory with a malformed package config. If we
      // search for it, we should get an error.
      await d.dir('foo', [
        d.dir('.dart_tool', [
          d.file('package_config.json', 'this no good json is bad json'),
        ]),
        d.file('main.dart', 'main(){    }'),
      ]).create();

      var process = await runFormatterOnDir();
      await process.shouldExit(0);

      // Should format the file without any error reading the package config.
      await d.dir('foo', [d.file('main.dart', 'main() {}\n')]).validate();
    });

    test('no package search if language version is specified', () async {
      // Put the file in a directory with a malformed package config. If we
      // search for it, we should get an error.
      await d.dir('foo', [
        d.dir('.dart_tool', [
          d.file('package_config.json', 'this no good json is bad json'),
        ]),
        d.file('main.dart', 'main(){    }'),
      ]).create();

      var process = await runFormatterOnDir(
          ['--language-version=latest', '--enable-experiment=tall-style']);
      await process.shouldExit(0);

      // Should format the file without any error reading the package config.
      await d.dir('foo', [d.file('main.dart', 'main() {}\n')]).validate();
    });

    test('default to language version of surrounding package', () async {
      // The package config sets the language version to 3.1, but the switch
      // case uses a syntax which is valid in earlier versions of Dart but an
      // error in 3.0 and later. Verify that the error is reported.
      await d.dir('foo', [
        packageConfig('foo', 3, 1),
        d.file('main.dart', 'main() { switch (o) { case 1 + 2: break; } }'),
      ]).create();

      var path = p.join(d.sandbox, 'foo', 'main.dart');
      // TODO(rnystrom): Remove experiment flag when it ships.
      var process =
          await runFormatter([path, '--enable-experiment=tall-style']);

      expect(await process.stderr.next,
          'Could not format because the source could not be parsed:');
      expect(await process.stderr.next, '');
      expect(await process.stderr.next, contains('main.dart'));
      await process.shouldExit(65);
    });

    test('language version comment overrides package default', () async {
      // The package config sets the language version to 3.1, but the switch
      // case uses a syntax which is valid in earlier versions of Dart but an
      // error in 3.0 and later. Verify that no error is reported since this
      // file opts to the older version.
      await d.dir('foo', [
        packageConfig('foo', 3, 1),
        d.file('main.dart', '''
          // @dart=2.19
          main() { switch (obj) { case 1 + 2: // Error in 3.1.
            } }
          '''),
      ]).create();

      var process = await runFormatterOnDir();
      await process.shouldExit(0);

      // Formats the file.
      await d.dir('foo', [
        d.file('main.dart', '''
// @dart=2.19
main() {
  switch (obj) {
    case 1 + 2: // Error in 3.1.
  }
}
''')
      ]).validate();
    });

    test('malformed', () async {
      await d.dir('foo', [
        d.dir('.dart_tool', [
          d.file('package_config.json', 'this no good json is bad json'),
        ]),
        d.file('main.dart', 'main() {}'),
      ]).create();

      var path = p.join(d.sandbox, 'foo', 'main.dart');
      // TODO(rnystrom): Remove experiment flag when it ships.
      var process =
          await runFormatter([path, '--enable-experiment=tall-style']);

      expect(
          await process.stderr.next,
          allOf(startsWith('Could not read package configuration for'),
              contains(p.join('foo', 'main.dart'))));
      await process.shouldExit(65);
    });
  });
}
