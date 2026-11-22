import 'package:file_picker/file_picker.dart';

import 'package:dsa_heldenverwaltung/data/storage_directory_picker.dart';

class _IoStorageDirectoryPicker implements StorageDirectoryPicker {
  @override
  Future<String?> pickDirectory({required String dialogTitle}) {
    // Die App speichert ueber dart:io-Dateipfade. `pickDirectory()` liefert auf
    // Android eine content://-URI, die dafuer nicht nutzbar ist; die Migration
    // braucht daher ein eigenes Speicherkonzept (file_picker 13.4.0).
    // ignore: deprecated_member_use
    return FilePicker.getDirectoryPath(
      dialogTitle: dialogTitle,
      windowsOptions: const WindowsOptions(lockParentWindow: true),
      linuxOptions: const LinuxOptions(lockParentWindow: true),
    );
  }
}

StorageDirectoryPicker createStorageDirectoryPickerImpl() {
  return _IoStorageDirectoryPicker();
}
