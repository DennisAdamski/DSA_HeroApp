/// Oeffnet eine native Ordnerauswahl fuer den Heldenspeicher.
abstract class StorageDirectoryPicker {
  /// Oeffnet einen nativen Dialog und liefert den gewaehlten Ordnerpfad.
  Future<String?> pickDirectory({required String dialogTitle});
}
