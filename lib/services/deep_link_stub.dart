/// Stub implementation for non-web platforms (Android/iOS/desktop).
/// These functions are no-ops outside the browser environment.
library;

String? getShareParamFromUrl() => null;
void cleanShareParamFromUrl() {}
bool webCanShare() => false;
void listenWebLaunchQueue(void Function(String shareId) onShare) {}
