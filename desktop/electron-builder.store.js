const packageJson = require("./package.json");

function requiredEnvironment(name) {
  const value = String(process.env[name] || "").trim();
  if (!value) throw new Error(`${name} is required for a Microsoft Store build.`);
  return value;
}

module.exports = {
  ...packageJson.build,
  win: {
    ...packageJson.build.win,
    target: [{ target: "appx", arch: ["x64"] }]
  },
  appx: {
    applicationId: "CGVDesktop",
    identityName: requiredEnvironment("WINDOWS_STORE_IDENTITY_NAME"),
    publisher: requiredEnvironment("WINDOWS_STORE_PUBLISHER"),
    publisherDisplayName: requiredEnvironment("WINDOWS_STORE_PUBLISHER_DISPLAY_NAME"),
    displayName: "CGeV Desktop",
    backgroundColor: "transparent",
    languages: ["en-US", "es-CL"],
    showNameOnTiles: true,
    artifactName: "CGeV-Desktop-${version}-Windows-${arch}-Store.${ext}"
  },
  publish: null
};
