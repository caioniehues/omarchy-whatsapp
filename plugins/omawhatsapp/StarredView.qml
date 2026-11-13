import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "ShortcutModel.js" as Shortcuts
import "TimeFormat.js" as TimeFormat

// Starred messages of every chat, or of the open one. Choosing one opens its
// chat on that message; unstarring goes through the same guarded star write
// as the message menu. Nothing is sent by just looking.
FocusScope {
  id: root
  objectName: "starredView"

  property var items: []
  property bool loading: false
  // "all" or "chat"; the chat scope needs a chat to name.
  property string scope: "all"
  property string chatName: ""
  property bool multiAccount: false
  // Unstarring needs a wacli build that stars, and the account the helper
  // serves (the open chat's); other rows say to open their chat first.
  property bool starAvailable: true
  property string writableAccount: ""
  property bool demoMode: false
  property var shortcuts: ({})
  property var now: new Date()
  property color foreground: Commons.Color.foreground
  property color surface: Commons.Color.background
  property color accent: Commons.Color.accent
  property color muted: foreground
  property string fontFamily: Style.font.family
  property int cursor: 0
  property bool cursorShown: false

  signal closeRequested()
  signal scopeRequested(string scope)
  signal openRequested(var item)
  signal unstarRequested(var item)

  function canUnstar(item) {
    return !!item && starAvailable && (demoMode || String(item.account || "") === writableAccount)
  }
  function dateText(ts) {
    var value = Number(ts || 0)
    return value > 0 ? TimeFormat.dayLabel(value, root.now) : ""
  }
  function placeText(item) {
    var chat = String(item.chat_name || "")
    var sender = String(item.sender || "")
    var place = item.chat_kind === "group" && sender !== "" ? sender + " · " + chat
      : item.from_me === true ? "You · " + chat : chat
    return multiAccount && String(item.account || "") !== ""
      ? place + " · " + String(item.account) : place
  }
  function bodyText(item) {
    var text = String(item.text || "")
    if (text !== "") return text
    var kind = String(item.media_type || "")
    return kind !== "" ? "[" + kind + "]" : "Message"
  }
  // The first J/K only shows the cursor, as in the chat list.
  function move(delta) {
    if (items.length === 0) return
    cursor = Math.max(0, Math.min(items.length - 1, cursor + (cursorShown ? delta : 0)))
    cursorShown = true
    list.positionViewAtIndex(cursor, ListView.Contain)
  }
  function open(index) {
    var item = items[index === undefined ? cursor : index]
    if (!item) return false
    openRequested(item)
    return true
  }
  function unstar(index) {
    var item = items[index === undefined ? cursor : index]
    if (!canUnstar(item)) return false
    unstarRequested(item)
    return true
  }
  onItemsChanged: cursor = Math.max(0, Math.min(cursor, items.length - 1))
  onVisibleChanged: if (visible) { cursorShown = false; cursor = 0 }

  Keys.onPressed: function(event) {
    if (Shortcuts.matches("back", event, shortcuts, true)) {
      closeRequested()
      event.accepted = true
    } else if (Shortcuts.matches("next", event, shortcuts, true)) {
      move(1)
      event.accepted = true
    } else if (Shortcuts.matches("previous", event, shortcuts, true)) {
      move(-1)
      event.accepted = true
    } else if (Shortcuts.matches("openChat", event, shortcuts, true)) {
      event.accepted = open()
    } else if (Shortcuts.matches("unstar", event, shortcuts, true)) {
      event.accepted = cursorShown && unstar()
    }
  }

  Rectangle {
    anchors.fill: parent
    color: root.surface
  }
  // Owns every click and wheel here, so nothing underneath reacts.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
    hoverEnabled: true
    onPressed: root.forceActiveFocus()
    onWheel: function(wheel) { wheel.accepted = true }
  }

  Item {
    id: column
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(parent.width, Style.space(760))

    Item {
      id: header
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: Style.space(54)
      Text {
        textFormat: Text.PlainText
        objectName: "starredTitle"
        anchors.left: parent.left
        anchors.leftMargin: Style.space(18)
        anchors.right: closeButton.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        text: "Starred messages"
        elide: Text.ElideRight
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
        font.weight: Font.Bold
      }
      PanelActionButton {
        id: closeButton
        objectName: "starredClose"
        anchors.right: parent.right
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        iconText: "󰅖"
        tooltipText: "Close · " + Shortcuts.bindings("back", root.shortcuts, true).map(Shortcuts.label).join(" / ")
        foreground: root.muted
        hoverColor: root.foreground
        fontFamily: root.fontFamily
        fontSize: Style.font.body
        size: Style.space(30)
        onClicked: root.closeRequested()
      }
    }

    Row {
      id: tabs
      anchors.top: header.bottom
      anchors.left: parent.left
      anchors.leftMargin: Style.space(14)
      spacing: Style.space(6)
      Repeater {
        model: root.chatName !== ""
          ? [{ id: "all", label: "All chats" }, { id: "chat", label: root.chatName }]
          : [{ id: "all", label: "All chats" }]
        delegate: Rectangle {
          required property var modelData
          objectName: "starredScope-" + modelData.id
          readonly property bool active: root.scope === modelData.id
          width: Math.min(scopeText.implicitWidth + Style.space(22), column.width / 2 - Style.space(20))
          height: Style.space(28)
          radius: height / 2
          color: active ? Style.selectedFillFor(root.foreground, root.accent)
            : (scopeHover.hovered ? Style.hoverFillFor(root.foreground, root.accent)
              : Style.normalFillFor(root.foreground, root.accent))
          Text {
            textFormat: Text.PlainText
            id: scopeText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - Style.space(16))
            text: modelData.label
            elide: Text.ElideRight
            color: parent.active ? root.foreground : root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          HoverHandler { id: scopeHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: root.scopeRequested(modelData.id) }
        }
      }
    }

    ListView {
      id: list
      objectName: "starredList"
      anchors.top: tabs.bottom
      anchors.topMargin: Style.space(10)
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      clip: true
      spacing: Style.space(2)
      model: root.items
      currentIndex: root.cursor
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
      delegate: Rectangle {
        id: row
        required property var modelData
        required property int index
        readonly property bool current: root.cursorShown && index === root.cursor
        objectName: "starredRow-" + index
        width: list.width
        height: rowColumn.implicitHeight + Style.space(18)
        radius: Style.cornerRadius
        color: current ? Style.selectedFillFor(root.foreground, root.accent)
          : (rowHover.hovered ? Style.hoverFillFor(root.foreground, root.accent) : "transparent")
        Text {
          textFormat: Text.PlainText
          id: starGlyph
          anchors.left: parent.left
          anchors.leftMargin: Style.space(8)
          anchors.top: parent.top
          anchors.topMargin: Style.space(10)
          text: "󰓎"
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
        Column {
          id: rowColumn
          anchors.left: starGlyph.right
          anchors.leftMargin: Style.space(10)
          anchors.right: unstarButton.left
          anchors.rightMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)
          Item {
            width: parent.width
            height: placeLabel.implicitHeight
            Text {
              textFormat: Text.PlainText
              id: placeLabel
              objectName: "starredPlace"
              anchors.left: parent.left
              anchors.right: dateLabel.left
              anchors.rightMargin: Style.space(8)
              text: root.placeText(row.modelData)
              color: root.muted
              elide: Text.ElideRight
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              textFormat: Text.PlainText
              id: dateLabel
              anchors.right: parent.right
              text: root.dateText(row.modelData.timestamp)
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
          Text {
            textFormat: Text.PlainText
            objectName: "starredText"
            width: parent.width
            text: root.bodyText(row.modelData)
            color: root.foreground
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }
        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: { root.cursor = row.index; root.open(row.index) } }
        PanelActionButton {
          id: unstarButton
          objectName: "starredUnstar-" + row.index
          anchors.right: parent.right
          anchors.rightMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          visible: root.starAvailable
          opacity: root.canUnstar(row.modelData) ? 1 : 0.45
          iconText: "󰓑"
          tooltipText: root.canUnstar(row.modelData)
            ? "Unstar · " + Shortcuts.bindings("unstar", root.shortcuts, true).map(Shortcuts.label).join(" / ")
            : "Open this message's chat to unstar it"
          foreground: root.muted
          hoverColor: root.foreground
          fontFamily: root.fontFamily
          fontSize: Style.font.body
          size: Style.space(30)
          onClicked: root.unstar(row.index)
        }
      }
    }

    Text {
      textFormat: Text.PlainText
      objectName: "starredEmpty"
      anchors.centerIn: list
      width: list.width - Style.space(24)
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      visible: root.items.length === 0
      text: root.loading ? "Reading starred messages…"
        : root.scope === "chat" ? "No starred messages in this chat. Star one from its menu to find it here."
        : "No starred messages. Star one from its menu to find it here."
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
