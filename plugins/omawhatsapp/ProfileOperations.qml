import QtQuick
import Quickshell.Io

// Your own WhatsApp profile, per account. Showing it reads only this
// computer; "Check with WhatsApp" is an explicit remote read, and each change
// is a WhatsApp write the panel confirms first. The helper carries every value
// to wacli on its private stdin transport, and nothing here is ever retried.
Item {
  id: root

  required property string helper
  property bool zenityAvailable: true
  // Account name -> the helper's profile answer.
  property var profiles: ({})
  // Account name -> the last error or confirmation, shown on that card.
  property var errors: ({})
  property var notices: ({})
  // Account name -> a photo chosen in the picker and not yet confirmed.
  property var photoCandidates: ({})
  property string busyAccount: ""
  property string busyAction: ""
  readonly property bool busy: busyAction !== ""
  property string pickingAccount: ""
  property var loadQueue: []
  signal profileChanged(string account)

  readonly property int nameLimit: 25
  readonly property int aboutLimit: 139

  function parseJson(raw) {
    try { return JSON.parse(String(raw || "{}")) } catch (error) { return null }
  }
  function withEntry(map, account, value) {
    var next = Object.assign({}, map)
    if (value === undefined || value === null || value === "") delete next[account]
    else next[account] = value
    return next
  }
  function profileFor(account) { return profiles[String(account || "")] || null }
  function errorFor(account) { return String(errors[String(account || "")] || "") }
  function noticeFor(account) { return String(notices[String(account || "")] || "") }
  function candidateFor(account) { return String(photoCandidates[String(account || "")] || "") }

  // Local only: the name, About text and photo this computer last saw.
  function load(account) {
    var name = String(account || "")
    if (loadProcess.running) {
      if (loadQueue.indexOf(name) < 0) loadQueue = loadQueue.concat([name])
      return true
    }
    loadProcess.account = name
    loadProcess.payload = JSON.stringify({ account: name, action: "show" })
    loadProcess.stdinEnabled = true
    loadProcess.running = true
    return true
  }

  function run(account, action, fields) {
    if (busy) return false
    var name = String(account || "")
    busyAccount = name
    busyAction = action
    errors = withEntry(errors, name, "")
    notices = withEntry(notices, name, "")
    actionProcess.account = name
    actionProcess.action = action
    actionProcess.payload = JSON.stringify(Object.assign({ account: name, action: action }, fields))
    actionProcess.stdinEnabled = true
    actionProcess.running = true
    return true
  }

  function refresh(account) {
    return run(account, "refresh", { authorization: "remote-read" })
  }

  // The panel calls these only after the user confirmed the exact change.
  function change(account, field, value) {
    if (field !== "name" && field !== "about") return false
    var text = String(value || "").trim()
    var limit = field === "name" ? nameLimit : aboutLimit
    if (text === "" || text.length > limit || /[\u0000-\u001f\u007f-\u009f]/.test(text)) {
      errors = withEntry(errors, String(account || ""), field === "name"
        ? "Your name needs 1 to " + nameLimit + " characters on one line."
        : "Your About text needs 1 to " + aboutLimit + " characters on one line.")
      return false
    }
    return run(account, field, { value: text, authorization: "whatsapp-write" })
  }
  function setPhoto(account) {
    var path = candidateFor(account)
    if (path === "") return false
    if (!run(account, "photo", { path: path, authorization: "whatsapp-write" })) return false
    photoCandidates = withEntry(photoCandidates, String(account || ""), "")
    return true
  }
  function removePhoto(account) {
    return run(account, "remove-photo", { authorization: "destructive" })
  }

  function pickPhoto(account) {
    var name = String(account || "")
    if (pickerProcess.running || busy) return false
    if (!zenityAvailable) {
      errors = withEntry(errors, name, "Choosing a photo needs zenity (omarchy pkg add zenity).")
      return false
    }
    pickingAccount = name
    pickerProcess.running = true
    return true
  }
  function choosePhoto(account, path) {
    var value = String(path || "").trim().split("\n")[0]
    if (value.charAt(0) !== "/" || !/\.(jpe?g|png)$/i.test(value)) {
      if (value !== "") errors = withEntry(errors, String(account || ""), "A profile photo must be a JPEG or PNG image.")
      return false
    }
    errors = withEntry(errors, String(account || ""), "")
    photoCandidates = withEntry(photoCandidates, String(account || ""), value)
    return true
  }
  function discardPhoto(account) {
    photoCandidates = withEntry(photoCandidates, String(account || ""), "")
  }

  function finishLoad(account, exitCode, text) {
    var payload = parseJson(text)
    if (exitCode === 0 && payload && payload.ok === true)
      profiles = withEntry(profiles, account, payload)
    if (loadQueue.length > 0) {
      var next = loadQueue[0]
      loadQueue = loadQueue.slice(1)
      load(next)
    }
  }

  function finishAction(account, action, exitCode, text, errorText) {
    busyAccount = ""
    busyAction = ""
    var payload = parseJson(text)
    if (exitCode !== 0 || !payload || payload.ok !== true) {
      errors = withEntry(errors, account, (payload && payload.error)
        || String(errorText || "").trim() || "WhatsApp did not accept that.")
      return false
    }
    profiles = withEntry(profiles, account, payload)
    var done = {
      refresh: payload.photo_failed === true ? "Checked with WhatsApp; the photo could not be downloaded"
        : "Checked with WhatsApp",
      name: "Your name was changed",
      about: "Your About text was changed",
      photo: "Your photo was changed",
      "remove-photo": "Your photo was removed"
    }
    notices = withEntry(notices, account, done[action] || "")
    profileChanged(account)
    return true
  }

  Process {
    id: loadProcess
    property string payload: ""
    property string account: ""
    command: [root.helper, "profile"]
    stdinEnabled: true
    stdout: StdioCollector { id: loadOutput }
    stderr: StdioCollector { }
    onStarted: { write(payload + "\n"); payload = ""; stdinEnabled = false }
    onExited: function(exitCode) { root.finishLoad(account, exitCode, loadOutput.text) }
  }

  Process {
    id: actionProcess
    objectName: "profileActionProcess"
    property string payload: ""
    property string account: ""
    property string action: ""
    command: [root.helper, "profile"]
    stdinEnabled: true
    stdout: StdioCollector { id: actionOutput }
    stderr: StdioCollector { id: actionError }
    onStarted: { write(payload + "\n"); payload = ""; stdinEnabled = false }
    onExited: function(exitCode) {
      root.finishAction(account, action, exitCode, actionOutput.text, actionError.text)
    }
  }

  Process {
    id: pickerProcess
    objectName: "profilePhotoPicker"
    command: ["/usr/bin/zenity", "--file-selection", "--title=Choose a profile photo",
      "--file-filter=Photos | *.jpg *.jpeg *.png *.JPG *.JPEG *.PNG"]
    stdout: StdioCollector { id: pickerOutput }
    onExited: function(exitCode) {
      var account = root.pickingAccount
      root.pickingAccount = ""
      if (exitCode === 0) root.choosePhoto(account, pickerOutput.text)
    }
  }
}
