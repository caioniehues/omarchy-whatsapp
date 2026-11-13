import QtQuick
import QtTest
import "../plugins/omawhatsapp" as Oma

// What the profile panel asks the helper: values only on stdin, each change
// with its own authorization, refused locally when out of bounds, one request
// at a time, and a failure kept on screen instead of retried.
TestCase {
  id: testCase
  name: "ProfileOperations"

  Component {
    id: operationsComponent
    Oma.ProfileOperations { helper: "/synthetic/omawhatsapp" }
  }

  function create() {
    var operations = createTemporaryObject(operationsComponent, testCase)
    verify(operations !== null)
    return operations
  }
  function action(operations) { return findChild(operations, "profileActionProcess") }
  function finish(operations, exitCode, payload) {
    var process = action(operations)
    process.stdout.text = JSON.stringify(payload)
    process.running = false
    process.exited(exitCode)
  }

  function test_changes_travel_on_stdin_with_their_own_authorization() {
    var operations = create()
    var process = action(operations)
    verify(operations.change("work", "name", "  Synthetic Name "))
    compare(process.command, ["/synthetic/omawhatsapp", "profile"], "the value never enters argv")
    compare(JSON.parse(process.payload), { account: "work", action: "name",
      value: "Synthetic Name", authorization: "whatsapp-write" })
    finish(operations, 0, { ok: true, kind: "profile", name: "Synthetic Name", changed: "name" })
    compare(operations.profileFor("work").name, "Synthetic Name")
    compare(operations.noticeFor("work"), "Your name was changed")

    verify(operations.change("work", "about", "Synthetic about"))
    compare(JSON.parse(process.payload).authorization, "whatsapp-write")
    finish(operations, 0, { ok: true })
    verify(operations.refresh("work"))
    compare(JSON.parse(process.payload), { account: "work", action: "refresh", authorization: "remote-read" })
    finish(operations, 0, { ok: true })
    verify(operations.removePhoto("work"))
    compare(JSON.parse(process.payload), { account: "work", action: "remove-photo", authorization: "destructive" })
  }

  function test_out_of_bounds_values_are_refused_before_the_helper() {
    var operations = create()
    var process = action(operations)
    verify(!operations.change("work", "name", new Array(27).join("x")))
    verify(!operations.change("work", "name", "   "))
    verify(!operations.change("work", "about", "line one\nline two"))
    verify(!operations.change("work", "about", new Array(141).join("x")))
    verify(!operations.change("work", "status", "Synthetic"))
    verify(!process.running)
    compare(process.payload, "")
    verify(operations.errorFor("work") !== "")
    verify(operations.change("work", "name", new Array(26).join("x")), "exactly the limit is fine")
  }

  function test_one_request_at_a_time_and_failures_are_not_retried() {
    var operations = create()
    var process = action(operations)
    verify(operations.change("work", "name", "Synthetic"))
    verify(!operations.change("home", "name", "Other"), "a second change waits")
    verify(!operations.refresh("home"))
    finish(operations, 1, { ok: false, error: "WhatsApp did not confirm this in time.", outcome: "uncertain" })
    compare(operations.errorFor("work"), "WhatsApp did not confirm this in time.")
    verify(!operations.busy)
    verify(!process.running, "an unconfirmed change is not sent again")
    compare(operations.profileFor("work"), null, "a failure does not pretend to have changed anything")
  }

  function test_a_picked_photo_waits_for_confirmation_and_must_be_jpeg_or_png() {
    var operations = create()
    verify(!operations.choosePhoto("work", "/synthetic/animation.gif\n"))
    verify(!operations.choosePhoto("work", "relative.png"))
    compare(operations.candidateFor("work"), "")
    verify(operations.choosePhoto("work", "/synthetic/photo.JPG\n"))
    compare(operations.candidateFor("work"), "/synthetic/photo.JPG")
    verify(!action(operations).running, "choosing sends nothing")
    verify(operations.setPhoto("work"))
    compare(JSON.parse(action(operations).payload), { account: "work", action: "photo",
      path: "/synthetic/photo.JPG", authorization: "whatsapp-write" })
    compare(operations.candidateFor("work"), "")
  }

  function test_without_zenity_the_picker_explains_instead_of_starting() {
    var operations = create()
    operations.zenityAvailable = false
    verify(!operations.pickPhoto("work"))
    verify(!findChild(operations, "profilePhotoPicker").running)
    verify(operations.errorFor("work").indexOf("zenity") >= 0)
  }
}
