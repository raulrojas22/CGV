const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("cgvDesktop", {
  getRuntime: () => ipcRenderer.invoke("cgv:get-runtime"),
  getStorageSettings: () => ipcRenderer.invoke("cgv:get-storage-settings"),
  chooseStorageRoot: () => ipcRenderer.invoke("cgv:choose-storage-root"),
  listDatasets: () => ipcRenderer.invoke("cgv:list-datasets"),
  downloadDataset: (datasetId) => ipcRenderer.invoke("cgv:download-dataset", datasetId),
  cancelDatasetDownload: (datasetId) => ipcRenderer.invoke("cgv:cancel-dataset-download", datasetId),
  removeInstalledOrganisms: () => ipcRenderer.invoke("cgv:remove-installed-organisms"),
  showStartupLog: () => ipcRenderer.invoke("cgv:show-startup-log"),
  recoverAnalysis: () => ipcRenderer.invoke("cgv:recover-analysis"),
  onStatus: (callback) => {
    ipcRenderer.on("cgv:status", (_event, payload) => callback(payload));
  },
  onDownloadProgress: (callback) => {
    ipcRenderer.on("cgv:download-progress", (_event, payload) => callback(payload));
  },
  onUpdateStatus: (callback) => {
    ipcRenderer.on("cgv:update-status", (_event, payload) => callback(payload));
  },
  installUpdate: () => ipcRenderer.invoke("cgv:install-update")
});
