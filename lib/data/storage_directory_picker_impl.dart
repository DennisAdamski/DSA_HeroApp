import 'storage_directory_picker.dart';
import 'storage_directory_picker_stub.dart'
    if (dart.library.io) 'storage_directory_picker_io.dart';

/// Erstellt den plattformspezifischen Ordnerpicker.
StorageDirectoryPicker createStorageDirectoryPicker() {
  return createStorageDirectoryPickerImpl();
}
