import QtQuick
import QtTest
import "../plugins/omawhatsapp" as Oma
import "../plugins/omawhatsapp/AccountModel.js" as AccountModel

// Status updates and starred messages: what each view lists, how it opens
// and closes, the jump to a starred message in its chat, the guarded unstar,
// and that looking at a status never reaches WhatsApp.
TestCase {
  id: testCase
  name: "StatusAndStarred"
  width: 1000
  height: 700
  visible: true
  when: windowShown

  readonly property var workChat: ({ account: "work", jid: "shared@example", name: "Synthetic work",
    kind: "dm", preview: "", unread: 0 })
  readonly property var teamChat: ({ account: "work", jid: "team@example", name: "Synthetic team",
    kind: "group", preview: "", unread: 0 })
  readonly property var homeChat: ({ account: "home", jid: "shared@example", name: "Synthetic home",
    kind: "dm", preview: "", unread: 0 })
  readonly property var nowSeconds: 1787540400

  readonly property var statuses: [
    { account: "work", id: "s-alex", timestamp: nowSeconds - 600, from_me: false, sender: "Alex",
      sender_jid: "alex@example", text: "", media_type: "video", mime_type: "video/mp4", caption: "Walkthrough" },
    { account: "work", id: "s-sam-2", timestamp: nowSeconds - 60, from_me: false, sender: "Sam",
      sender_jid: "sam@example", text: "Second", media_type: "" },
    { account: "work", id: "s-mine", timestamp: nowSeconds - 3000, from_me: true, sender: "You",
      sender_jid: "", text: "Mine", media_type: "" },
    { account: "work", id: "s-sam-1", timestamp: nowSeconds - 1200, from_me: false, sender: "Sam",
      sender_jid: "sam@example", text: "", media_type: "image", mime_type: "image/png",
      caption: "Desk", local_path: "__demo_photo__" }
  ]

  Component { id: statusComponent; Oma.StatusView { width: 400; height: 600; now: new Date(testCase.nowSeconds * 1000) } }
  Component { id: starredComponent; Oma.StarredView { width: 400; height: 600 } }
  Component { id: spyComponent; SignalSpy {} }
  Component { id: demoAppComponent; Oma.App { width: 1000; height: 700; demoMode: true; opened: true } }
  Component { id: realServiceComponent; Oma.Service {} }

  // The app's view of the service, recording every call that could reach WhatsApp.
  Component {
    id: serviceComponent
    Item {
      readonly property alias playback: playbackCoordinator
      property bool appOpen: false
      property bool writing: false
      property bool controlWriting: false
      property bool settingsWriting: false
      property bool statusReady: true
      property bool railReady: true
      property bool offlineMode: false
      property bool syncActive: true
      property bool notificationsEnabled: true
      property bool notificationsPreview: false
      property bool notifyAvailable: true
      property bool sendReadReceipts: false
      property bool showUnreadCount: true
      property bool multiAccount: true
      property int dropdownRows: 7
      property int composerMaxLines: 6
      property string timeFormat: "auto"
      property string statusAccount: "work"
      property string selectedChatAccount: "work"
      property string selectedChatJid: "shared@example"
      property string selectedChatName: "Synthetic work"
      property string selectedChatKind: "dm"
      property string activeWriteAccount: ""
      property string activeWriteChatJid: ""
      property string activeWriteKind: ""
      property string voiceDraftAccount: ""
      property string voiceDraftJid: ""
      property string voiceState: "idle"
      property int voiceDurationMs: 0
      property int voicePlaybackPosition: 0
      property bool voicePlaying: false
      property bool loadingMembers: false
      property bool loadingMessages: false
      property bool loadingOlder: false
      property bool hasOlderMessages: true
      property string mediaDownloadId: ""
      property string errorText: ""
      property var chats: []
      property int presenceNow: 0
      function presenceSnapshotFor() { return null }
      function setPresenceFocus() {}
      property var accounts: []
      property var messages: []
      property var members: []
      property var accountOperations: ({ linkBusy: false, avatarBusy: false, statusMessage: "" })
      property bool starSupported: true
      property var starOverrides: ({})
      property var statusUpdates: []
      property bool statusUpdatesLoading: false
      property bool statusUpdatesWanted: false
      property var starredItems: []
      property bool starredLoading: false
      property bool starredWanted: false
      property var starredScope: null
      // Every call that could change or tell WhatsApp something.
      property var calls: []
      property int olderLoads: 0
      function record(name, args) { calls = calls.concat([name + ":" + JSON.stringify(args)]) }

      Oma.PlaybackCoordinator { id: playbackCoordinator }

      signal textPasted(string text, var chatRef, string owner)
      signal attachmentPasted(string path, var chatRef, string owner)
      signal writeCompleted(string kind, var chatRef, var request, string owner)
      signal writeFailed(string message, var chatRef, var details, string owner)
      signal controlCompleted(string kind)
      signal controlFailed(string message)
      signal settingsCompleted()
      signal settingsFailed(string message)

      function selectChat(chat) {
        selectedChatAccount = String(chat.account || "")
        selectedChatJid = String(chat.jid || "")
        selectedChatName = String(chat.name || "")
        selectedChatKind = String(chat.kind || "")
        statusAccount = selectedChatAccount
      }
      function setStarredScope(ref) { starredScope = ref ? { account: ref.account, jid: ref.jid } : null }
      // The app also loads older pages by itself when the oldest is on screen.
      function loadOlderMessages() {
        if (!hasOlderMessages) return false
        olderLoads++
        return true
      }
      function starMessage(ref, item, starred, owner) {
        record("star", { account: ref.account, jid: ref.jid, id: item.id, starred: starred, owner: owner })
        return true
      }
      function deleteMessage() { record("delete", []); return false }
      function forwardMessage() { record("forward", []); return false }
      function forwardMany() { record("forward", []); return false }
      function sendPoll() { record("poll", []); return false }
      function discardStages(paths) {}
      function discardStage(path) {}
      function refresh() {}
      function refreshChats() {}
      function refreshMessages() {}
      function dismissNotifications(jid, account) {}
      function stopVoiceRecording() {}
      function stopVoiceForSurfaceClose() {}
      function toggleVoice() { return false }
      function toggleVoicePlayback() {}
      function discardVoice() {}
      function sendVoiceDraft() { record("voice", []); return false }
      function pasteClipboard() { return false }
      function sendFilesReply() { record("files", []); return false }
      function sendSticker() { record("sticker", []); return false }
      function sendText() { record("send", []); return false }
      function editMessage() { record("edit", []); return false }
      function search() {}
      function closeApp() {}
      function selectItem() {}
      function chatAction(ref, action, owner) { record("chat-action", { action: action }); return true }
      function downloadMedia() { record("media", []); return false }
      function reactTo() { record("react", []); return false }
      function selectOption() { record("select", []); return false }
      function setNotifications() { return false }
      function setOnline() { return false }
      function setPreference(key, value) { return true }
    }
  }
  Component { id: appComponent; Oma.App { width: 1000; height: 700 } }

  function createHarness() {
    var service = createTemporaryObject(serviceComponent, testCase)
    service.chats = [workChat, teamChat, homeChat]
    var app = createTemporaryObject(appComponent, testCase, { service: service })
    app.opened = true
    return { app: app, service: service }
  }

  // ------------------------------------------------------------ status view

  function test_status_empty_state() {
    var view = createTemporaryObject(statusComponent, testCase, { items: [] })
    verify(findChild(view, "statusEmpty").visible)
    compare(findChild(view, "statusEmpty").text, "No status updates from the last 24 hours on this computer.")
    view.loading = true
    compare(findChild(view, "statusEmpty").text, "Reading status updates…")
    verify(!findChild(view, "statusStory").visible)
  }

  function test_status_lists_yours_first_then_the_newest_person() {
    var view = createTemporaryObject(statusComponent, testCase, { items: statuses })
    compare(view.groups.map(function(group) { return group.name }), ["My status", "Sam", "Alex"])
    compare(view.groups[1].updates.map(function(item) { return item.id }), ["s-sam-1", "s-sam-2"],
      "one person's updates play oldest first")
    verify(!findChild(view, "statusEmpty").visible)
    tryVerify(function() { return findChild(view, "statusRow-2") !== null })
    compare(view.groupLine(view.groups[1]), "2 updates · 1 min ago")
  }

  function test_status_opens_steps_and_closes_with_keys() {
    var view = createTemporaryObject(statusComponent, testCase, { items: statuses })
    var closed = createTemporaryObject(spyComponent, testCase, { target: view, signalName: "closeRequested" })
    view.forceActiveFocus()
    keyClick(Qt.Key_J)
    compare(view.cursor, 0, "the first J only shows the cursor")
    keyClick(Qt.Key_J)
    keyClick(Qt.Key_Return)
    compare(view.openGroup, 1)
    verify(findChild(view, "statusStory").visible)
    verify(!findChild(view, "statusList").visible)
    compare(findChild(view, "statusTitle").text, "Sam")
    compare(findChild(view, "statusMeta").text, "1 of 2 · 20 min ago · Photo")
    keyClick(Qt.Key_Right)
    compare(view.currentStatus.id, "s-sam-2")
    compare(findChild(view, "statusText").text, "Second")
    keyClick(Qt.Key_Right)
    compare(view.currentGroup.name, "Alex", "past one person's last update comes the next person")
    keyClick(Qt.Key_Left)
    compare(view.currentStatus.id, "s-sam-2")
    keyClick(Qt.Key_Escape)
    compare(view.openGroup, -1, "Esc goes back to the list first")
    compare(closed.count, 0)
    keyClick(Qt.Key_Escape)
    compare(closed.count, 1)
  }

  function test_status_media_opens_only_from_a_local_file() {
    var view = createTemporaryObject(statusComponent, testCase, { items: statuses })
    var opened = createTemporaryObject(spyComponent, testCase, { target: view, signalName: "openMediaRequested" })
    verify(view.openAt(1))
    verify(findChild(view, "statusImage").visible, "a local photo shows through the isolated image")
    verify(view.openCurrentMedia())
    compare(opened.count, 1)
    compare(opened.signalArguments[0][0].id, "s-sam-1")
    compare(opened.signalArguments[0][1].length, 1, "the gallery holds only local photos and videos")
    verify(view.openAt(2))
    verify(!view.openCurrentMedia(), "a video that is not on this computer cannot open")
    compare(opened.count, 1)
    verify(findChild(view, "statusMediaNote").text.indexOf("not on this computer") >= 0)
    compare(findChild(view, "statusCaption").text, "Walkthrough")
  }

  function test_viewing_statuses_in_the_app_sends_nothing_to_whatsapp() {
    var harness = createHarness()
    var app = harness.app
    var service = harness.service
    service.statusUpdates = statuses
    verify(app.openStatusUpdates())
    verify(service.statusUpdatesWanted, "the open view asks for the local list")
    var view = findChild(app, "statusView")
    tryVerify(function() { return view.visible && view.activeFocus })
    verify(view.openAt(1))
    keyClick(Qt.Key_Right)
    keyClick(Qt.Key_Right)
    verify(view.openAt(1))
    verify(view.openCurrentMedia())
    verify(findChild(app, "mediaViewer").opened)
    findChild(app, "mediaViewer").closeViewer()
    keyClick(Qt.Key_Escape)
    keyClick(Qt.Key_Escape)
    verify(!app.statusOpen)
    verify(!service.statusUpdatesWanted)
    compare(service.calls, [], "no receipt, read mark or other write")
  }

  function test_the_service_reads_statuses_locally_and_never_writes() {
    var service = createTemporaryObject(realServiceComponent, testCase)
    var reader = findChild(service, "statusesProcess")
    service.statusUpdatesWanted = true
    verify(reader.running)
    compare(reader.command[reader.command.length - 1], "statuses")
    compare(JSON.parse(reader.payload), { all_accounts: true })
    verify(!findChild(service, "writeProcess").running)
    verify(!findChild(service, "readMarkProcess").running)
    reader.stdout.text = JSON.stringify({ ok: true, kind: "statuses", statuses: statuses })
    reader.running = false
    reader.exited(0)
    compare(service.statusUpdates.length, 4)
    verify(!service.statusUpdatesLoading)
  }

  // ---------------------------------------------------------- starred view

  readonly property var starredRows: [
    { account: "work", chat_jid: "team@example", chat_name: "Synthetic team", chat_kind: "group",
      id: "m-new", timestamp: nowSeconds - 60, starred_at: nowSeconds, from_me: false, sender: "Sam", text: "Newest" },
    { account: "home", chat_jid: "shared@example", chat_name: "Synthetic home", chat_kind: "dm",
      id: "m-home", timestamp: nowSeconds - 7200, starred_at: nowSeconds - 10, from_me: true, sender: "You",
      text: "", media_type: "image" }
  ]

  function test_starred_empty_state_for_every_chat_and_one_chat() {
    var view = createTemporaryObject(starredComponent, testCase, { items: [] })
    verify(findChild(view, "starredEmpty").visible)
    compare(findChild(view, "starredEmpty").text, "No starred messages. Star one from its menu to find it here.")
    verify(findChild(view, "starredScope-chat") === null, "no chat tab without an open chat")
    view.chatName = "Synthetic team"
    view.scope = "chat"
    compare(findChild(view, "starredEmpty").text,
      "No starred messages in this chat. Star one from its menu to find it here.")
    tryVerify(function() { return findChild(view, "starredScope-chat") !== null })
  }

  function test_starred_rows_name_chat_sender_and_account() {
    var view = createTemporaryObject(starredComponent, testCase, { items: starredRows, multiAccount: true })
    verify(!findChild(view, "starredEmpty").visible)
    tryVerify(function() { return findChild(view, "starredRow-1") !== null })
    compare(view.placeText(starredRows[0]), "Sam · Synthetic team · work")
    compare(view.placeText(starredRows[1]), "You · Synthetic home · home")
    compare(view.bodyText(starredRows[1]), "[image]")
  }

  function test_starred_keys_open_and_unstar_only_where_allowed() {
    var view = createTemporaryObject(starredComponent, testCase, { items: starredRows, writableAccount: "work" })
    var opened = createTemporaryObject(spyComponent, testCase, { target: view, signalName: "openRequested" })
    var unstarred = createTemporaryObject(spyComponent, testCase, { target: view, signalName: "unstarRequested" })
    var closed = createTemporaryObject(spyComponent, testCase, { target: view, signalName: "closeRequested" })
    view.forceActiveFocus()
    keyClick(Qt.Key_U)
    compare(unstarred.count, 0, "U does nothing before a row is selected")
    keyClick(Qt.Key_J)
    keyClick(Qt.Key_U)
    compare(unstarred.count, 1)
    compare(unstarred.signalArguments[0][0].id, "m-new")
    keyClick(Qt.Key_J)
    keyClick(Qt.Key_U)
    compare(unstarred.count, 1, "another account's star needs its chat open first")
    keyClick(Qt.Key_Return)
    compare(opened.signalArguments[0][0].id, "m-home")
    keyClick(Qt.Key_Escape)
    compare(closed.count, 1)
    view.starAvailable = false
    verify(!view.unstar(0), "a wacli that cannot star offers no unstar")
  }

  function test_opening_a_starred_message_jumps_to_it_in_its_chat() {
    var harness = createHarness()
    var app = harness.app
    var service = harness.service
    service.messages = [
      { id: "m-3", text: "three", sender: "Sam", timestamp: 300, from_me: false },
      { id: "m-2", text: "two", sender: "Sam", timestamp: 200, from_me: false }]
    service.starredItems = [{ account: "work", chat_jid: "team@example", chat_name: "Synthetic team",
      chat_kind: "group", id: "m-old", timestamp: 50, starred_at: 400, from_me: false, sender: "Sam", text: "old" }]
    verify(app.openStarred("all"))
    verify(service.starredWanted)
    compare(service.starredScope, null, "every chat of every account")
    var view = findChild(app, "starredView")
    tryVerify(function() { return view.visible && view.activeFocus })
    keyClick(Qt.Key_J)
    keyClick(Qt.Key_Return)
    verify(!app.starredOpen, "the list closes")
    compare(service.selectedChatJid, "team@example")
    compare(service.selectedChatAccount, "work")
    tryVerify(function() { return app.pendingJump && app.pendingJump.pages === 1 }, 2000,
      "not on the first page: an older one loads")
    verify(service.olderLoads >= 1)
    service.messages = service.messages.concat([{ id: "m-old", text: "old", sender: "Sam", timestamp: 50, from_me: false }])
    tryVerify(function() { return app.pendingJump === null })
    compare(app.cursorIndex, 2, "the starred message is the selected one")
    compare(app.keyboardContext, "messages")
    compare(service.calls, [], "opening a starred message writes nothing")
  }

  function test_a_starred_message_older_than_the_whole_chat_gives_up() {
    var harness = createHarness()
    var app = harness.app
    var service = harness.service
    service.messages = [{ id: "m-3", text: "three", sender: "Sam", timestamp: 300, from_me: false }]
    service.hasOlderMessages = false
    verify(app.openStarredMessage({ account: "work", chat_jid: "team@example", id: "gone", timestamp: 10 }))
    tryVerify(function() { return app.pendingJump === null })
    compare(service.olderLoads, 0)
  }

  function test_unstarring_from_the_list_uses_the_guarded_star_write() {
    var harness = createHarness()
    var app = harness.app
    var service = harness.service
    service.starredItems = starredRows
    verify(app.openStarred("all"))
    compare(app.starredRows.length, 2)
    verify(app.unstarFromList(starredRows[0]))
    compare(service.calls, ['star:{"account":"work","jid":"team@example","id":"m-new","starred":false,"owner":"app"}'])
    // The pending unstar hides the row at once.
    var overrides = {}
    overrides[AccountModel.chatKey("work", "team@example") + "\nm-new"] = false
    service.starOverrides = overrides
    compare(app.starredRows.map(function(item) { return item.id }), ["m-home"])
  }

  function test_the_chat_tab_lists_only_the_open_chat() {
    var harness = createHarness()
    var app = harness.app
    var service = harness.service
    service.selectChat(teamChat)
    verify(app.openStarred("chat"))
    compare(app.starredScope, "chat")
    compare(service.starredScope, { account: "work", jid: "team@example" })
    var view = findChild(app, "starredView")
    compare(view.chatName, "Synthetic team")
    view.scopeRequested("all")
    compare(service.starredScope, null)
  }

  // ------------------------------------------------------------- demo mode

  function test_demo_shows_both_views_and_jumps_to_a_starred_bubble() {
    var app = createTemporaryObject(demoAppComponent, testCase)
    app.open('{"demo":true,"status":true}')
    var status = findChild(app, "statusView")
    tryVerify(function() { return status.visible })
    compare(status.groups.length, 3)
    compare(status.groups[0].name, "My status")
    verify(app.openStarred("all"))
    verify(!status.visible)
    compare(app.starredRows.map(function(item) { return item.id }), ["demo-1", "demo-4"])
    verify(app.openStarredMessage(app.starredRows[1]))
    compare(app.demoSelectedJid, "demo-lab")
    tryVerify(function() { return app.pendingJump === null })
    compare(app.visibleMessages[app.cursorIndex].id, "demo-4")
    verify(app.openStarred("all"))
    verify(app.unstarFromList(app.starredRows[0]))
    compare(app.starredRows.map(function(item) { return item.id }), ["demo-4"])
  }

  // The status view and the media browser hand the viewer their gallery
  // through a signal; it must still open on the chosen item.
  function test_a_gallery_from_a_signal_opens_the_viewer_on_its_item() {
    var app = createTemporaryObject(demoAppComponent, testCase)
    verify(app.openMediaBrowser("media"))
    var browser = findChild(app, "mediaBrowser")
    browser.items = [
      { id: "g1", media_type: "image", mime_type: "image/png", local_path: "__demo_photo__" },
      { id: "g2", media_type: "image", mime_type: "image/png", local_path: "__demo__" }]
    browser.openMedia(browser.items[1])
    var viewer = findChild(app, "mediaViewer")
    verify(viewer.opened)
    compare(viewer.items.length, 2)
    compare(viewer.currentItem.id, "g2")
    viewer.closeViewer()
  }

  function test_both_views_fit_a_360_pixel_window() {
    var app = createTemporaryObject(demoAppComponent, testCase, { width: 360, height: 640 })
    findChild(app, "omawhatsappWindow").width = 360
    findChild(app, "omawhatsappWindow").height = 640
    verify(app.narrow)
    verify(app.openStatusUpdates())
    var status = findChild(app, "statusView")
    tryVerify(function() { return status.visible && status.width > 0 })
    verify(status.width <= 360)
    verify(findChild(status, "statusList").width <= 360)
    verify(status.openAt(1))
    verify(findChild(status, "statusCard").width > 200)
    verify(app.openStarred("all"))
    var starred = findChild(app, "starredView")
    tryVerify(function() { return starred.visible })
    tryVerify(function() { return findChild(starred, "starredRow-0") !== null })
    var row = findChild(starred, "starredRow-0")
    verify(row.width <= 360 && row.width > 300)
    verify(findChild(starred, "starredUnstar-0").x + findChild(starred, "starredUnstar-0").width <= row.width)
  }
}
