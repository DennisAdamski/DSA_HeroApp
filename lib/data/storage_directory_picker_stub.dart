import 'package:dsa_heldenverwaltung/data/storage_directory_picker.dart';

class _UnsupportedStorageDirectoryPicker implements StorageDirectoryPicker {
  @override
  Future<String?> pickDirectory({required String dialogTitle}) async {
    throw UnsupportedError(
      'Die Ordnerauswahl wird auf dieser Plattform nicht unterstuetzt.',
    );
  }
}

StorageDirectoryPicker createStorageDirectoryPickerImpl() {
  return _UnsupportedStorageDirectoryPicker();
}
