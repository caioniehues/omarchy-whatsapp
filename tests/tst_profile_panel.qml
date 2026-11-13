import QtQuick
import QtTest
import "../plugins/omawhatsapp" as Oma

// Settings → Profile: each linked account shows its own name, About text and
// photo; every change names the exact new value and waits for a second click;
// a paused account changes nothing; demo mode edits synthetic data in memory.
TestCase {
  id: testCase
  name: "ProfilePanel"
  width: 900
  height: 700
  visible: true
  when: windowShown

  Component {
    id: operationsStub
    QtObject {
      property var profiles: ({
        work: { name: "Synthetic Work", about: "Synthetic about", phone: "+1 555 010 0001",
                photo_path: "", checked_at: 1, linked: true },
        home: { name: "", about: "", phone: "", photo_path: "", checked_at: 0, linked: true }
      })
      property var candidates: ({})
      property bool busy: false
      property string busyAccount: ""
      property string busyAction: ""
      property var calls: []
      function record(name, args) { calls = calls.concat([{ name: name, args: args }]) }
      function profileFor(account) { return profiles[account] || null }
      function candidateFor(account) { return String(candidates[account] || "") }
      function errorFor(account) { return "" }
      function noticeFor(account) { return "" }
      function load(account) { record("load", [account]); return true }
      function refresh(account) { record("refresh", [account]); return true }
      function change(account, field, value) { record("change", [account, field, value]); return true }
      function setPhoto(account) { record("setPhoto", [account]); return true }
      function removePhoto(account) { record("removePhoto", [account]); return true }
      function pickPhoto(account) { record("pickPhoto", [account]); return true }
      function discardPhoto(account) {
        record("discardPhoto", [account])
        var next = Object.assign({}, candidates); delete next[account]; candidates = next
      }
    }
  }

  Component {
    id: panelComponent
    Oma.ProfilePanel { width: 800 }
  }

  readonly property var twoAccounts: [
    { account: "work", label: "work", authenticated: true, online: true },
    { account: "home", label: "home", authenticated: true, online: true },
    { account: "spare", label: "spare", authenticated: false, online: true }
  ]

  function create(accounts) {
    var operations = createTemporaryObject(operationsStub, testCase)
    var panel = createTemporaryObject(panelComponent, testCase,
      { operations: operations, accounts: accounts || twoAccounts })
    verify(panel !== null)
    return { panel: panel, operations: operations }
  }
  function writes(operations) {
    return operations.calls.filter(function(call) { return call.name !== "load" })
  }
  function click(panel, name) {
    var item = findChild(panel, name)
    verify(item !== null, name)
    verify(item.visible && item.enabled, name + " is usable")
    item.clicked()
  }

  function test_each_linked_account_shows_its_own_profile() {
    var h = create()
    compare(h.operations.calls.map(function(call) { return call.args[0] }), ["work", "home"],
      "only linked accounts are read, from this computer")
    compare(findChild(h.panel, "profileName-work").text, "Synthetic Work")
    compare(findChild(h.panel, "profileAbout-work").text, "Synthetic about")
    compare(findChild(h.panel, "profileState-work").text, "work · +1 555 010 0001")
    compare(findChild(h.panel, "profileName-home").text, "Your name is not known on this computer yet")
    compare(findChild(h.panel, "profileAbout-home").text, "Check with WhatsApp to see your About text")
    verify(findChild(h.panel, "profileCard-spare") === null, "an unlinked account has no profile")
    verify(!findChild(h.panel, "profileRemovePhoto-work").visible, "no photo, nothing to remove")
    h.panel.accounts = twoAccounts.slice()
    compare(h.operations.calls.length, 2, "a status poll with the same accounts reads nothing again")
  }

  function test_a_name_change_names_the_value_and_waits_for_confirmation() {
    var h = create()
    click(h.panel, "profileEditName-work")
    var editor = findChild(h.panel, "profileEditor-work")
    verify(editor.visible)
    compare(editor.text, "Synthetic Work")
    compare(editor.maximumLength, 25)
    editor.text = "  New Synthetic  "
    click(h.panel, "profileReview-work")
    compare(writes(h.operations).length, 0, "reviewing changes nothing")
    verify(findChild(h.panel, "profileConfirm-work").visible)
    verify(!findChild(h.panel, "profileConfirm-home").visible, "only that account asks")
    verify(findChild(h.panel, "profileConfirmText-work").text.indexOf("\u201cNew Synthetic\u201d") >= 0)
    compare(findChild(h.panel, "profileConfirmButton-work").text, "Change name")
    click(h.panel, "profileConfirmCancel-work")
    compare(writes(h.operations).length, 0, "cancel writes nothing")
    verify(!findChild(h.panel, "profileConfirm-work").visible)
    click(h.panel, "profileReview-work")
    click(h.panel, "profileConfirmButton-work")
    compare(writes(h.operations), [{ name: "change", args: ["work", "name", "New Synthetic"] }])
    verify(!findChild(h.panel, "profileEditorRow-work").visible)
  }

  function test_about_editor_is_bounded_and_unchanged_text_asks_nothing() {
    var h = create()
    click(h.panel, "profileEditAbout-work")
    var editor = findChild(h.panel, "profileEditor-work")
    compare(editor.maximumLength, 139)
    compare(findChild(h.panel, "profileEditorCount-work").text, "15 / 139")
    verify(!h.panel.review("work", "about", "Synthetic about"), "the same text is not a change")
    verify(!h.panel.review("work", "about", ""))
    verify(!h.panel.review("work", "about", new Array(141).join("x")), "longer than WhatsApp allows")
    compare(writes(h.operations).length, 0)
  }

  function test_photo_changes_and_removal_are_confirmed() {
    var h = create()
    click(h.panel, "profileChoosePhoto-work")
    compare(writes(h.operations), [{ name: "pickPhoto", args: ["work"] }])
    h.operations.candidates = { work: "/synthetic/photo.png" }
    tryVerify(function() { return findChild(h.panel, "profileConfirm-work").visible },
      1000, "a picked photo asks at once")
    compare(findChild(h.panel, "profilePhoto-work").chat.avatar_path, "/synthetic/photo.png",
      "the preview is the picked file, through the photo component")
    click(h.panel, "profileConfirmCancel-work")
    compare(writes(h.operations)[1], { name: "discardPhoto", args: ["work"] })
    h.operations.candidates = { work: "/synthetic/photo.png" }
    tryVerify(function() { return findChild(h.panel, "profileConfirm-work").visible })
    click(h.panel, "profileConfirmButton-work")
    compare(writes(h.operations)[2], { name: "setPhoto", args: ["work"] })

    var profiles = Object.assign({}, h.operations.profiles)
    profiles.work = Object.assign({}, profiles.work, { photo_path: "/synthetic/cached.jpg" })
    h.operations.profiles = profiles
    click(h.panel, "profileRemovePhoto-work")
    compare(writes(h.operations).length, 3, "removing asks first")
    compare(findChild(h.panel, "profileConfirmButton-work").text, "Remove photo")
    click(h.panel, "profileConfirmButton-work")
    compare(writes(h.operations)[3], { name: "removePhoto", args: ["work"] })
  }

  function test_a_paused_account_cannot_check_or_change_its_profile() {
    var h = create([
      { account: "work", label: "work", authenticated: true, online: false },
      { account: "home", label: "home", authenticated: true, online: true }
    ])
    var names = ["profileEditName-work", "profileEditAbout-work", "profileChoosePhoto-work", "profileRefresh-work"]
    for (var i = 0; i < names.length; i++)
      verify(!findChild(h.panel, names[i]).enabled, names[i])
    verify(findChild(h.panel, "profileState-work").text.indexOf("Background sync is paused") >= 0)
    verify(findChild(h.panel, "profileEditName-home").enabled, "the other account is unaffected")
    h.panel.editingAccount = "work"
    h.panel.editingField = "name"
    verify(h.panel.review("work", "name", "Synthetic"))
    verify(!findChild(h.panel, "profileConfirmButton-work").enabled)
  }

  function test_one_change_at_a_time_and_refresh_is_explicit() {
    var h = create()
    click(h.panel, "profileRefresh-work")
    compare(writes(h.operations), [{ name: "refresh", args: ["work"] }])
    h.operations.busy = true
    h.operations.busyAccount = "work"
    h.operations.busyAction = "refresh"
    compare(findChild(h.panel, "profileNotice-work").text, "Asking WhatsApp…")
    verify(!findChild(h.panel, "profileEditName-home").enabled, "every account waits for the request")
  }

  function test_demo_mode_edits_synthetic_profiles_in_memory() {
    var panel = createTemporaryObject(panelComponent, testCase, { demoMode: true })
    compare(findChild(panel, "profileName-work").text, "Jordan Lee")
    compare(findChild(panel, "profileName-personal").text, "Jordan")
    click(panel, "profileEditName-work")
    findChild(panel, "profileEditor-work").text = "Jordan L."
    click(panel, "profileReview-work")
    click(panel, "profileConfirmButton-work")
    compare(findChild(panel, "profileName-work").text, "Jordan L.")
    compare(findChild(panel, "profileNotice-work").text, "Demo only: nothing was sent to WhatsApp")
    click(panel, "profileChoosePhoto-personal")
    click(panel, "profileConfirmButton-personal")
    compare(panel.demoProfiles.personal.photo_path, "__demo_avatar__")
  }
}
