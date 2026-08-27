const path = require("path");

// The visible product name changed in 1.2.0, but existing settings, caches,
// installed datasets, logs, and updater state must remain in the original
// CGV Desktop directory on every supported operating system.
const LEGACY_USER_DATA_DIRECTORY = "CGV Desktop";

function legacyUserDataPath({ platform, localAppData, appData }) {
  const base = platform === "win32" && localAppData ? localAppData : appData;
  if (!base) throw new Error("Cannot resolve the legacy CGV Desktop user-data directory.");
  return path.join(base, LEGACY_USER_DATA_DIRECTORY);
}

module.exports = { LEGACY_USER_DATA_DIRECTORY, legacyUserDataPath };
