import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Settings → Profile: your own name, About text and photo for each linked
// account. Every change waits for a second, explicit confirmation that names
// the exact new value; demo mode edits synthetic profiles in memory only.
Column {
  id: panel
  objectName: "profilePanel"

  property var operations: null
  property var accounts: []
  property bool demoMode: false
  property color foreground: Commons.Color.foreground
  property color background: Commons.Color.background
  property color accent: Commons.Color.accent
  property color urgent: Commons.Color.urgent
  property color dim: foreground
  property string fontFamily: Style.font.family

  spacing: Style.space(10)

  readonly property bool live: !demoMode && !!operations
  readonly property int nameLimit: 25
  readonly property int aboutLimit: 139
  readonly property var linkedAccounts: demoMode ? demoAccounts
    : Array.prototype.filter.call(accounts || [], function(entry) {
      return !!entry && entry.authenticated === true
    })
  readonly property bool multi: linkedAccounts.length > 1

  // Synthetic profiles for demo captures; nothing here is this machine's.
  readonly property var demoAccounts: [
    { account: "work", label: "work", authenticated: true, online: true },
    { account: "personal", label: "personal", authenticated: true, online: true }
  ]
  property var demoProfiles: ({
    work: { name: "Jordan Lee", about: "Building calm software", phone: "+1 555 010 4477",
            photo_path: "__demo_avatar__", checked_at: 1787540000, linked: true },
    personal: { name: "Jordan", about: "Out hiking until Monday", phone: "+1 555 010 9921",
                photo_path: "", checked_at: 1787540000, linked: true }
  })
  property var demoCandidates: ({})
  property var demoNotices: ({})

  // One editor and one pending confirmation at a time, each for one account.
  property string editingAccount: ""
  property string editingField: ""
  property string draft: ""
  property string confirmingAccount: ""
  property string confirming: ""
  property string confirmValue: ""

  function profileFor(account) {
    var name = String(account || "")
    if (demoMode) return demoProfiles[name] || ({})
    return (operations && operations.profileFor(name)) || ({})
  }
  function candidateFor(account) {
    var name = String(account || "")
    if (demoMode) return String(demoCandidates[name] || "")
    return operations ? operations.candidateFor(name) : ""
  }
  function errorFor(account) { return live ? operations.errorFor(account) : "" }
  function noticeFor(account) {
    return demoMode ? String(demoNotices[String(account || "")] || "")
      : (live ? operations.noticeFor(account) : "")
  }
  function busyFor(account) {
    return live && operations.busy && operations.busyAccount === String(account || "")
  }
  function online(entry) { return demoMode || !entry || entry.online !== false }
  function canAct(entry) { return (demoMode || (live && !operations.busy)) && online(entry) }

  // Local reads only, and only when the set of linked accounts changes, not
  // on every status poll that rebuilds the same list.
  property string loadedAccounts: ""
  function reload() {
    if (demoMode || !operations) return
    var names = linkedAccounts.map(function(entry) { return String(entry.account || "") })
    var key = JSON.stringify(names)
    if (key === loadedAccounts) return
    loadedAccounts = key
    names.forEach(function(name) { operations.load(name) })
  }
  Component.onCompleted: reload()
  onLinkedAccountsChanged: reload()
  onOperationsChanged: { loadedAccounts = ""; reload() }

  function startEdit(account, field) {
    cancel()
    editingAccount = String(account || "")
    editingField = field
    draft = String(profileFor(account)[field] || "")
  }
  function review(account, field, value) {
    var text = String(value || "").trim()
    var limit = field === "name" ? nameLimit : aboutLimit
    if (text === "" || text.length > limit) return false
    if (text === String(profileFor(account)[field] || "")) { cancel(); return false }
    confirmingAccount = String(account || "")
    confirming = field
    confirmValue = text
    return true
  }
  function askPhoto(account) {
    if (candidateFor(account) === "") return false
    confirmingAccount = String(account || "")
    confirming = "photo"
    confirmValue = ""
    return true
  }
  function askRemovePhoto(account) {
    cancel()
    confirmingAccount = String(account || "")
    confirming = "remove-photo"
    confirmValue = ""
    return true
  }
  function pickPhoto(account) {
    cancel()
    if (demoMode) {
      var next = Object.assign({}, demoCandidates)
      next[String(account || "")] = "__demo_avatar__"
      demoCandidates = next
      return askPhoto(account)
    }
    return live && operations.pickPhoto(account)
  }
  function discardPhoto(account) {
    if (demoMode) {
      var next = Object.assign({}, demoCandidates)
      delete next[String(account || "")]
      demoCandidates = next
    } else if (live) operations.discardPhoto(account)
    cancel()
  }
  function confirmText() {
    switch (confirming) {
    case "name": return "Change your WhatsApp name to \u201c" + confirmValue
      + "\u201d? Everyone who sees your profile sees the new name."
    case "about": return "Change your About text to \u201c" + confirmValue
      + "\u201d? People see it on your profile as your privacy settings allow."
    case "photo": return "Use this photo for your WhatsApp profile? People see it as your privacy settings allow."
    case "remove-photo": return "Remove your WhatsApp profile photo? People see a blank photo until you set another."
    default: return ""
    }
  }
  function confirmLabel() {
    return confirming === "name" ? "Change name" : confirming === "about" ? "Change About"
      : confirming === "photo" ? "Use photo" : confirming === "remove-photo" ? "Remove photo" : ""
  }
  function confirm() {
    var account = confirmingAccount
    var action = confirming
    var value = confirmValue
    if (action === "" || !linkedAccounts.some(function(entry) {
      return String(entry.account || "") === account
    })) return false
    var done = false
    if (demoMode) {
      var profile = Object.assign({}, profileFor(account))
      if (action === "name" || action === "about") profile[action] = value
      else if (action === "photo") profile.photo_path = candidateFor(account)
      else if (action === "remove-photo") profile.photo_path = ""
      var profiles = Object.assign({}, demoProfiles)
      profiles[account] = profile
      demoProfiles = profiles
      var notices = Object.assign({}, demoNotices)
      notices[account] = "Demo only: nothing was sent to WhatsApp"
      demoNotices = notices
      if (action === "photo") {
        var candidates = Object.assign({}, demoCandidates)
        delete candidates[account]
        demoCandidates = candidates
      }
      done = true
    } else if (live) {
      done = action === "name" || action === "about" ? operations.change(account, action, value)
        : action === "photo" ? operations.setPhoto(account)
        : action === "remove-photo" ? operations.removePhoto(account) : false
    }
    if (done) {
      cancel()
      editingAccount = ""
      editingField = ""
    }
    return done
  }
  function cancel() {
    confirmingAccount = ""
    confirming = ""
    confirmValue = ""
  }
  function closeEditor() {
    cancel()
    editingAccount = ""
    editingField = ""
    draft = ""
  }
  function refresh(account) {
    cancel()
    if (demoMode) {
      var notices = Object.assign({}, demoNotices)
      notices[String(account || "")] = "Demo only: nothing was asked of WhatsApp"
      demoNotices = notices
      return true
    }
    return live && operations.refresh(account)
  }
  function stateText(entry, profile) {
    var label = multi ? String(entry.label || entry.account || "primary") : ""
    var parts = []
    if (label !== "") parts.push(label)
    if (String(profile.phone || "") !== "") parts.push(String(profile.phone))
    if (!online(entry)) parts.push("Background sync is paused · go online to check or change your profile")
    return parts.join(" · ")
  }

  Text {
    textFormat: Text.PlainText
    objectName: "profileEmpty"
    visible: panel.linkedAccounts.length === 0
    width: panel.width
    leftPadding: Style.space(14)
    wrapMode: Text.Wrap
    text: "Link an account to see and change your profile."
    color: panel.dim
    font.family: panel.fontFamily
    font.pixelSize: Style.font.caption
  }

  Repeater {
    model: panel.linkedAccounts
    delegate: Rectangle {
      id: card
      required property var modelData
      readonly property string account: String(modelData.account || "")
      readonly property var profile: panel.profileFor(account)
      readonly property string candidate: panel.candidateFor(account)
      readonly property bool editing: panel.editingAccount === account && panel.editingField !== ""
      readonly property bool asking: panel.confirmingAccount === account && panel.confirming !== ""
      readonly property bool working: panel.busyFor(account)
      readonly property bool actionable: panel.canAct(modelData)
      objectName: "profileCard-" + account
      width: panel.width
      height: cardColumn.implicitHeight + Style.space(24)
      radius: Style.cornerRadius
      color: Style.normalFillFor(panel.foreground, panel.accent)

      Column {
        id: cardColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Style.space(14)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(10)

        Item {
          width: parent.width
          height: Math.max(photo.height, identity.implicitHeight)
          ChatAvatar {
            id: photo
            objectName: "profilePhoto-" + card.account
            width: Style.space(64)
            height: width
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            // A chosen photo previews through the same isolated decoder.
            chat: ({ kind: "dm", name: String(card.profile.name || "?"),
                     avatar_path: card.candidate !== "" ? card.candidate : String(card.profile.photo_path || "") })
            foreground: panel.foreground
            background: panel.background
            accent: panel.accent
            fontFamily: panel.fontFamily
          }
          Column {
            id: identity
            anchors.left: photo.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(3)
            Text {
              textFormat: Text.PlainText
              objectName: "profileName-" + card.account
              width: parent.width
              elide: Text.ElideRight
              text: String(card.profile.name || "") !== "" ? String(card.profile.name)
                : "Your name is not known on this computer yet"
              color: String(card.profile.name || "") !== "" ? panel.foreground : panel.dim
              font.family: panel.fontFamily
              font.pixelSize: Style.font.body
            }
            Text {
              textFormat: Text.PlainText
              objectName: "profileAbout-" + card.account
              width: parent.width
              wrapMode: Text.Wrap
              text: String(card.profile.about || "") !== "" ? String(card.profile.about)
                : (Number(card.profile.checked_at || 0) > 0 ? "No About text"
                  : "Check with WhatsApp to see your About text")
              color: panel.dim
              font.family: panel.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              textFormat: Text.PlainText
              objectName: "profileState-" + card.account
              visible: text !== ""
              width: parent.width
              wrapMode: Text.Wrap
              text: panel.stateText(card.modelData, card.profile)
              color: panel.dim
              font.family: panel.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        Flow {
          width: parent.width
          spacing: Style.space(8)
          visible: !card.editing && !card.asking
          Button {
            objectName: "profileEditName-" + card.account
            text: "Edit name"
            enabled: card.actionable
            foreground: panel.foreground; accent: panel.accent; fontFamily: panel.fontFamily
            bordered: true
            onClicked: panel.startEdit(card.account, "name")
          }
          Button {
            objectName: "profileEditAbout-" + card.account
            text: "Edit About"
            enabled: card.actionable
            foreground: panel.foreground; accent: panel.accent; fontFamily: panel.fontFamily
            bordered: true
            onClicked: panel.startEdit(card.account, "about")
          }
          Button {
            objectName: "profileChoosePhoto-" + card.account
            text: "Change photo…"
            enabled: card.actionable
            foreground: panel.foreground; accent: panel.accent; fontFamily: panel.fontFamily
            bordered: true
            onClicked: panel.pickPhoto(card.account)
          }
          Button {
            objectName: "profileRemovePhoto-" + card.account
            visible: String(card.profile.photo_path || "") !== ""
            text: "Remove photo…"
            enabled: card.actionable
            foreground: panel.foreground; accent: panel.accent; fontFamily: panel.fontFamily
            bordered: true
            onClicked: panel.askRemovePhoto(card.account)
          }
          Button {
            objectName: "profileRefresh-" + card.account
            text: card.working && panel.operations.busyAction === "refresh" ? "Checking…" : "Check with WhatsApp"
            enabled: card.actionable
            foreground: panel.foreground; accent: panel.accent; fontFamily: panel.fontFamily
            bordered: true
            onClicked: panel.refresh(card.account)
          }
        }

        Column {
          id: editorRow
          objectName: "profileEditorRow-" + card.account
          visible: card.editing && !card.asking
          width: parent.width
          spacing: Style.space(6)
          readonly property int limit: panel.editingField === "about" ? panel.aboutLimit : panel.nameLimit
          Row {
            spacing: Style.space(8)
            SafeTextField {
              id: editor
              objectName: "profileEditor-" + card.account
              width: Math.min(Style.space(360), cardColumn.width - Style.space(200))
              text: card.editing ? panel.draft : ""
              placeholderText: panel.editingField === "about" ? "Your About text" : "Your name"
              maximumLength: editorRow.limit
              foreground: panel.foreground
              accent: panel.accent
              font.family: panel.fontFamily
              font.pixelSize: Style.font.bodySmall
              onTextChanged: if (card.editing) panel.draft = text
              onAccepted: panel.review(card.account, panel.editingField, text)
            }
            Button {
              objectName: "profileReview-" + card.account
              text: "Save…"
              enabled: card.actionable && editor.text.trim() !== ""
              foreground: panel.foreground; accent: panel.accent; fontFamily: panel.fontFamily
              bordered: true
              onClicked: panel.review(card.account, panel.editingField, editor.text)
            }
            Button {
              objectName: "profileEditCancel-" + card.account
              text: "Cancel"
              foreground: panel.foreground; accent: panel.accent; fontFamily: panel.fontFamily
              bordered: true
              onClicked: panel.closeEditor()
            }
          }
          Text {
            textFormat: Text.PlainText
            objectName: "profileEditorCount-" + card.account
            text: editor.text.length + " / " + editorRow.limit
            color: panel.dim
            font.family: panel.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Column {
          objectName: "profileConfirm-" + card.account
          visible: card.asking
          width: parent.width
          spacing: Style.space(8)
          Text {
            textFormat: Text.PlainText
            objectName: "profileConfirmText-" + card.account
            width: parent.width
            wrapMode: Text.Wrap
            text: card.asking ? panel.confirmText() : ""
            color: panel.foreground
            font.family: panel.fontFamily
            font.pixelSize: Style.font.caption
          }
          Row {
            spacing: Style.space(8)
            Button {
              objectName: "profileConfirmButton-" + card.account
              text: card.asking ? panel.confirmLabel() : ""
              enabled: card.actionable
              foreground: panel.confirming === "remove-photo" ? panel.urgent : panel.foreground
              accent: panel.confirming === "remove-photo" ? panel.urgent : panel.accent
              fontFamily: panel.fontFamily
              bordered: true
              onClicked: panel.confirm()
            }
            Button {
              objectName: "profileConfirmCancel-" + card.account
              text: "Cancel"
              foreground: panel.foreground; accent: panel.accent; fontFamily: panel.fontFamily
              bordered: true
              onClicked: panel.confirming === "photo" ? panel.discardPhoto(card.account) : panel.cancel()
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          objectName: "profileNotice-" + card.account
          visible: text !== ""
          width: parent.width
          wrapMode: Text.Wrap
          text: card.working ? (panel.operations.busyAction === "refresh" ? "Asking WhatsApp…"
              : "Changing your profile on WhatsApp…")
            : panel.errorFor(card.account) !== "" ? panel.errorFor(card.account)
            : panel.noticeFor(card.account)
          color: !card.working && panel.errorFor(card.account) !== "" ? panel.urgent : panel.dim
          font.family: panel.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      // A photo picked in the dialog asks for confirmation at once.
      onCandidateChanged: if (candidate !== "" && !panel.demoMode) panel.askPhoto(account)
    }
  }

  Text {
    textFormat: Text.PlainText
    visible: panel.linkedAccounts.length > 0
    width: panel.width
    leftPadding: Style.space(14)
    rightPadding: Style.space(14)
    wrapMode: Text.Wrap
    text: "Checking or changing your profile connects to WhatsApp and pauses background sync for a few seconds. A photo is a JPEG or PNG up to 10 MB."
    color: panel.dim
    font.family: panel.fontFamily
    font.pixelSize: Style.font.caption
  }
}
