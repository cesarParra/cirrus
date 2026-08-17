/// Why cirrus stopped, and what the shell sees.
///
/// The message is for whoever is watching; the status is the only part a build server can read,
/// and "your config is invalid" and "your tests failed" are different answers to that question.
/// One type carries both so that no path can report a failure without deciding which it is.
class Failure {
  final String message;

  /// What cirrus exits with.
  final int status;

  /// Cirrus could not do what was asked: the config did not load, the command does not exist, the
  /// arguments do not say anything cirrus can act on. Distinct from a command that ran and failed,
  /// which is the other thing a non-zero status can mean.
  static const couldNot = 2;

  const Failure(this.message) : status = couldNot;

  /// A command cirrus ran exited non-zero. Its status is the answer the caller wanted, and cirrus
  /// has nothing to add to it.
  const Failure.fromCommand(this.message, this.status);
}
