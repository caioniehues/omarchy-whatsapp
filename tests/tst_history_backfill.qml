import QtQuick
import QtTest
import "../plugins/omawhatsapp" as Oma

// Asking the phone for older history: only after the local copy of the open
// chat ends, one bounded request per click, for that chat only, never while
// its account is offline, and never repeated by itself.
TestCase {
  id: testCase
  name: "HistoryBackfill"

  Component { id: serviceComponent; Oma.Service {} }

  function createService() {
    var service = createTemporaryObject(serviceComponent, testCase)
    service.accounts = [{ account: "work", label: "work", authenticated: true, online: true },
                        { account: "home", label: "home", authenticated: true, online: true }]
    service.selectedChatAccount = "work"
    service.selectedChatJid = "synthetic@s.whatsapp.net"
    service.messages = [{ id: "n2", timestamp: 30 }, { id: "n1", timestamp: 20 }]
    service.hasOlderMessages = false
    return service
  }

  function finish(service, exitCode, payload) {
    var process = findChild(service, "backfillProcess")
    process.stdout.text = JSON.stringify(payload)
    process.running = false
    process.exited(exitCode)
  }

  function test_one_bounded_request_for_the_open_chat() {
    var service = createService()
    var process = findChild(service, "backfillProcess")
    compare(process.command.slice(1), ["history-backfill"], "nothing private in the arguments")
    verify(service.requestHistoryBackfill())
    var request = JSON.parse(process.payload)
    compare(request, { account: "work", jid: "synthetic@s.whatsapp.net", count: 50, authorization: "sync" })
    compare(service.selectedBackfillState, "running")
    compare(service.syncPauseReason, "loading older messages from your phone")
    verify(!service.requestHistoryBackfill(), "one request at a time")
  }

  function test_local_pages_come_first() {
    var service = createService()
    service.hasOlderMessages = true
    verify(!service.requestHistoryBackfill())
    service.hasOlderMessages = false
    service.query = "needle"
    verify(!service.requestHistoryBackfill(), "a search is not the start of the chat")
  }

  function test_a_paused_account_is_not_asked() {
    var service = createService()
    service.accounts = [{ account: "work", label: "work", authenticated: true, online: false }]
    verify(!service.selectedChatOnline)
    verify(!service.requestHistoryBackfill())
    verify(!findChild(service, "backfillProcess").running)
    compare(service.selectedBackfillState, "idle")
  }

  function test_arrivals_are_read_as_one_older_local_page() {
    var service = createService()
    service.requestHistoryBackfill()
    finish(service, 0, { ok: true, kind: "history-backfill", added: 3, answered: true, requested: 50 })
    compare(service.selectedBackfillState, "done")
    compare(service.selectedBackfillMessage, "3 older messages arrived from your phone")
    var older = findChild(service, "olderProcess")
    verify(older.running, "the stored messages are read like any older page")
    compare(JSON.parse(older.payload).before, { ts: 20, id: "n1" })
    verify(!findChild(service, "backfillProcess").running, "and the phone is not asked again")
  }

  function test_no_answer_and_failures_wait_for_another_click() {
    var service = createService()
    var process = findChild(service, "backfillProcess")
    service.requestHistoryBackfill()
    finish(service, 0, { ok: true, added: 0, answered: false })
    compare(service.selectedBackfillState, "done")
    compare(service.selectedBackfillMessage, "Your phone did not send older messages. Keep it online and try again.")
    verify(!findChild(service, "olderProcess").running)
    service.requestHistoryBackfill()
    finish(service, 0, { ok: true, added: 0, answered: true })
    compare(service.selectedBackfillMessage, "Your phone has no older messages for this chat")
    service.requestHistoryBackfill()
    finish(service, 1, { ok: false, error: "Synthetic refusal" })
    compare(service.selectedBackfillState, "failed")
    compare(service.selectedBackfillMessage, "Synthetic refusal")
    verify(!process.running, "a failure is not retried by itself")
    verify(service.requestHistoryBackfill(), "the user may ask again")
  }

  function test_the_answer_belongs_to_the_chat_that_asked() {
    var service = createService()
    service.requestHistoryBackfill()
    service.selectChat({ account: "home", jid: "other@s.whatsapp.net", name: "Other", kind: "dm" })
    service.hasOlderMessages = false
    service.messages = [{ id: "x1", timestamp: 5 }]
    compare(service.selectedBackfillState, "busy", "another chat's request is still out")
    verify(!service.requestHistoryBackfill())
    finish(service, 0, { ok: true, added: 4, answered: true })
    compare(service.selectedBackfillState, "idle")
    verify(!findChild(service, "olderProcess").running, "the open chat is not reloaded for another's answer")
    compare(service.hasOlderMessages, false)
    service.selectChat({ account: "work", jid: "synthetic@s.whatsapp.net", name: "Synthetic", kind: "dm" })
    compare(service.selectedBackfillState, "done")
    compare(service.selectedBackfillMessage, "4 older messages arrived from your phone")
  }
}
