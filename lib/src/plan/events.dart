import 'dart:convert';
import 'dart:io';

/// The protocol a server reads: newline-delimited JSON on stdout, and nothing else on stdout.
class Events {
  static const protocol = 1;

  final StringSink _out;

  const Events(this._out);

  Events.toStdout() : _out = stdout;

  void started({
    required String product,
    required String version,
    required int steps,
  }) => _write({
    'event': 'started',
    'protocol': protocol,
    'product': product,
    'version': version,
    'steps': steps,
  });

  void stepStarted(int step, String name) =>
      _write({'event': 'step.started', 'step': step, 'name': name});

  void stepProgress(int step, String message) =>
      _write({'event': 'step.progress', 'step': step, 'message': message});

  void log(int step, String message) =>
      _write({'event': 'log', 'step': step, 'message': message});

  void stepFinished(int step, int seconds) => _write({
    'event': 'step.finished',
    'step': step,
    'status': 'ok',
    'seconds': seconds,
  });

  void stepFailed(int step, String message, Map<String, dynamic> detail) =>
      _write({
        'event': 'step.failed',
        'step': step,
        'message': message,
        'detail': detail,
      });

  void finished(String status) =>
      _write({'event': 'finished', 'status': status});

  void _write(Map<String, dynamic> event) {
    _out.writeln(jsonEncode(event));
  }
}
