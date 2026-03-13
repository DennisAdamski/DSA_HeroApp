import 'package:file_picker/file_picker.dart';

import 'package:dsa_heldenverwaltung/data/storage_directory_picker.dart';

class _IoStorageDirectoryPicker implements StorageDirectoryPicker {
  @override
  Future<String?> pickDirectory({required String dialogTitle}) {
    return FilePicker.platform.getDirectoryPath(
      dialogTitle: dialogTitle,
      lockParentWindow: true,
    );
  }
}

StorageDirectoryPicker createStorageDirectoryPickerImpl() {
  return _IoStorageDirectoryPicker();
}
