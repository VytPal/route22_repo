enum UserEntryStatus {
  waitingForConfirmation,
  confirmed,
}

Map<UserEntryStatus, String> userEntryStatusStrings = {
  UserEntryStatus.waitingForConfirmation: 'waitingForConfirmation',
  UserEntryStatus.confirmed: 'confirmed',
};
