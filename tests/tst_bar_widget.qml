import QtQuick
import QtTest
import Quickshell
import "../plugins/omawhatsapp" as Oma

// The bar item: left click opens the dropdown, middle click clears the badge,
// right click mutes or unmutes every desktop notification.
TestCase {
  id: testCase
  name: "BarWidget"
  width: 200
  height: 60
  visible: true
  when: windowShown

  Component {
    id: serviceComponent
    Item {
      property int notificationUnreadCount: 3
      property bool railReady: true
      property bool inputsReady: true
      property bool showUnreadCount: true
      property bool notificationsMuted: false
      property int dropdownRows: 7
      property string statusMessage: ""
      property string barTooltipWithMute: notificationsMuted ? "muted tooltip" : "tooltip"
      property int toggles: 0
      property int dismissals: 0
      property int refreshes: 0
      property bool closed: false
      property int launches: 0
      function launchApp() { launches++; closed = false; return true }
      signal openDropdownRequested(var payload)
      signal toggleDropdownRequested()
      function toggleNotificationsMuted() { toggles++; notificationsMuted = !notificationsMuted; return true }
      function dismissNotifications(jid) { dismissals++ }
      function refresh() { refreshes++ }
    }
  }

  Component {
    id: barComponent
    QtObject {
      id: barRoot
      property bool vertical: false
      property var service: null
      property QtObject shell: QtObject {
        function serviceFor(id) { return barRoot.service }
      }
    }
  }

  Component {
    id: widgetComponent
    Oma.BarWidget {}
  }

  function createWidget(vertical) {
    var service = createTemporaryObject(serviceComponent, testCase)
    var bar = createTemporaryObject(barComponent, testCase, { vertical: vertical === true })
    bar.service = service
    var widget = createTemporaryObject(widgetComponent, testCase, { bar: bar })
    verify(widget !== null)
    tryVerify(function() { return widget.oma === service })
    return { widget: widget, service: service, button: findChild(widget, "barButton") }
  }

  function test_right_click_mutes_and_the_icon_shows_it() {
    var h = createWidget(false)
    compare(h.button.text, "󰖣 3")
    verify(!h.button.dimmed)
    h.button.pressed(Qt.RightButton)
    compare(h.service.toggles, 1)
    compare(h.service.refreshes, 0, "right click no longer refreshes")
    compare(h.button.text, "󰖣 3 󰂛", "the crossed bell sits beside the count")
    verify(h.button.dimmed)
    compare(h.button.tooltipText, "muted tooltip")
    h.button.pressed(Qt.RightButton)
    compare(h.service.toggles, 2)
    compare(h.button.text, "󰖣 3")
    verify(!h.button.dimmed)
  }

  function test_middle_click_still_clears_the_badge() {
    var h = createWidget(false)
    h.button.pressed(Qt.MiddleButton)
    compare(h.service.dismissals, 1)
    compare(h.service.toggles, 0)
  }

  function test_a_vertical_bar_swaps_the_logo_for_the_bell() {
    var h = createWidget(true)
    compare(h.button.text, "󰖣")
    h.service.notificationsMuted = true
    compare(h.button.text, "󰂛")
  }

  function test_a_closed_whatsapp_is_grey_and_opens_from_its_icon() {
    // L233: after Quit the icon is dimmed, and a click starts it again.
    var h = createWidget(false)
    verify(!h.button.dimmed)
    h.service.closed = true
    verify(h.button.dimmed, "closed shows grey")
    h.button.pressed(Qt.LeftButton)
    compare(h.service.launches, 1)
    verify(!h.service.closed)
    h.button.pressed(Qt.LeftButton)
    compare(h.service.launches, 1, "an open one just toggles its dropdown")
  }

  function test_a_bar_without_the_service_keeps_a_working_icon() {
    // Upstream #30: a cloned omarchy.bar answers serviceFor() with null.
    var bar = createTemporaryObject(barComponent, testCase, { vertical: false })
    var widget = createTemporaryObject(widgetComponent, testCase, { bar: bar })
    var button = findChild(widget, "barButton")
    compare(widget.oma, null)
    compare(button.text, "󰖣", "the icon stays on the bar")
    verify(!button.dimmed)
    verify(button.tooltipText.indexOf("click to open the app") !== -1, button.tooltipText)
    Quickshell.detached = []
    button.pressed(Qt.LeftButton)
    compare(Quickshell.detached.length, 1)
    compare(Quickshell.detached[0], ["omarchy-shell", "io.github.caioniehues.omawhatsapp", "openApp", "{}"])
    button.pressed(Qt.MiddleButton)
    button.pressed(Qt.RightButton)
    compare(Quickshell.detached.length, 1, "only a left click opens the app")

    // Once the service appears, the click goes back to the dropdown.
    var service = createTemporaryObject(serviceComponent, testCase)
    bar.service = service
    tryVerify(function() { return widget.oma === service })
    button.pressed(Qt.LeftButton)
    compare(Quickshell.detached.length, 1)
    compare(button.tooltipText, "tooltip")
  }
}
