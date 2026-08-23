/// Returns consistent mutation-failure copy without accepting or interpolating
/// backend exception text. [action] must be a hard-coded product phrase.
String userSafeActionError(String action) {
  return 'Could not $action. Check your connection and try again.';
}
