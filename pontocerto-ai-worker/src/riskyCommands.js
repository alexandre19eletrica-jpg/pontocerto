/** Espelha heuristica do backend Functions — segunda linha de defesa local. */
export function commandNeedsLocalApproval(commandLine) {
  const c = commandLine.toLowerCase();
  const needles = [
    'firebase deploy',
    'firebase hosting',
    'firebase functions',
    'firebase firestore',
    'firebase logout',
    'npm publish',
    'git push',
    ' git reset --hard',
    ' git clean ',
    'flutter build appbundle',
    'flutter build apk',
    'gradlew',
    'gradle ',
    'adb ',
    'fastlane',
    'remove-item',
    'rimraf',
    'format-volume',
  ];
  return needles.some((n) => c.includes(n));
}
