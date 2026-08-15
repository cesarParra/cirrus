import 'dart:io';

import 'package:cirrus/src/utils.dart';
import 'package:test/test.dart';

/// `cirrus run x | head` is an ordinary thing to type, and the reader stopping reading is not an
/// error - there is simply nobody left to write to.
void main() {
  test('a closed pipe is recognised', () {
    expect(
      isBrokenPipe(
        FileSystemException('writeFrom failed', '', OSError('Broken pipe', 32)),
      ),
      isTrue,
    );
  });

  test('a missing file is not a closed pipe', () {
    expect(
      isBrokenPipe(
        FileSystemException(
          'Cannot open file',
          'cirrus.yaml',
          OSError('No such file or directory', 2),
        ),
      ),
      isFalse,
    );
  });

  test('anything else is not a closed pipe', () {
    expect(isBrokenPipe('sf exited with code 1'), isFalse);
  });
}
