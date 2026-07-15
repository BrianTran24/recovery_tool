# recovery_tool

Flutter app for recovering files from a disk image or removable storage.

The native scanner now prioritizes filesystem metadata on exFAT images, so live files are discovered before deleted-file carving.

## Getting Started

Use the **Backup Image** flow when you already have a `.img` file. The app will scan the image in read-only mode and write recovered files to a separate output folder.

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
