import 'dart:io';

import 'package:fpdart/fpdart.dart';

extension IterableExtestons<T> on Iterable<T> {
  Option<T> firstWhereOrOption(Function(T) f) {
    for (final current in this) {
      if (f(current)) return Some(current);
    }

    return None();
  }
}

/// Whether [error] is the write that failed because whatever was reading has stopped - `cirrus run
/// x | head`, or a pager the reader quit. Nothing is wrong; there is nobody left to write to.
///
/// The codes are what the platform calls EPIPE: 32 on Linux and macOS, and the two Windows spells
/// it (ERROR_BROKEN_PIPE, ERROR_NO_DATA).
bool isBrokenPipe(Object error) =>
    error is FileSystemException &&
    const [32, 109, 232].contains(error.osError?.errorCode);
