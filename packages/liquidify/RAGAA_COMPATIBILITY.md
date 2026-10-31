# Liquidify 0.1.1 local compatibility copy

Source: https://pub.dev/api/archives/liquidify-0.1.1.tar.gz

Upstream SHA256: f8577026b0fb0399455614a2f9cf17ea34ea84bd97f5832b8a4e31c8a886c6f0

The upstream package requires Dart 3.12.1; Ragaa currently uses Dart 3.11.
This local copy lowers only the pubspec SDK floor to Dart 3.11 for a tested
Windows release and preview. Focused widget tests and the complete Windows
release build passed on the project's installed SDK. Upstream Dart, native
sources and MIT license are preserved.
Use a hosted dependency after upgrading Flutter/Dart and revalidating the UI.
This change does not claim upstream support for older Dart or test iOS/macOS.
