const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("LSDesktop", {
  getAppInfo: () => ipcRenderer.invoke("ls:getAppInfo"),
  checkOtaParity: () => ipcRenderer.invoke("ls:checkOtaParity"),
  fetchAdminData: () => ipcRenderer.invoke("ls:fetchAdminData"),
  runCommand: (cmdKey) => ipcRenderer.invoke("ls:runCommand", cmdKey),
  openExternal: (url) => ipcRenderer.invoke("ls:openExternal", url),
  openFolder: (which) => ipcRenderer.invoke("ls:openFolder", which),
  exportCsv: (filename, content) => ipcRenderer.invoke("ls:exportCsv", { filename, content }),
  notify: (title, body) => ipcRenderer.invoke("ls:notify", { title, body }),
  onLog: (cb) => ipcRenderer.on("ls:log", (_ev, data) => cb(data))
});
