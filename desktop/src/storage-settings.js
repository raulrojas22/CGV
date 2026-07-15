function parseDesktopSettings(raw) {
  try {
    const value = typeof raw === "string" ? JSON.parse(raw) : raw;
    if (!value || value.schemaVersion !== 1 || typeof value.storageRoot !== "string") return {};
    const storageRoot = value.storageRoot.trim();
    return storageRoot ? { schemaVersion: 1, storageRoot } : {};
  } catch (_) {
    return {};
  }
}

function needsInitialStorageSelection({ platform, isPackaged, env, storageRoot }) {
  if (platform !== "win32" || !isPackaged) return false;
  if (String(storageRoot || "").trim()) return false;
  const hasDataOverride = Boolean(env.CGV_DESKTOP_DATA_ROOT || env.CGV_DATA_ROOT);
  const hasCacheOverride = Boolean(env.CGV_DESKTOP_CACHE_ROOT || env.CGV_CACHE_DIR);
  return !(hasDataOverride && hasCacheOverride);
}

module.exports = {
  needsInitialStorageSelection,
  parseDesktopSettings
};
