/// What happened when we handed the calendar file to the device.
enum IcsDeliveryResult {
  /// A calendar app opened it. The user confirms the import there.
  opened,

  /// The browser downloaded it. The user opens it to import.
  downloaded,

  /// The phone has no app that can open calendar files.
  noApp,

  /// Something else went wrong.
  failed,
}
