import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "ShortcutModel.js" as Shortcuts
import "MediaModel.js" as MediaModel
import "TimeFormat.js" as TimeFormat

// Status updates of the last 24 hours, read from the local mirror: one row
// per person, then their updates one by one, oldest first, as on the phone.
// Viewing is private: nothing here reaches WhatsApp, so no author is told
// their status was seen. Photos and videos open only from a local file, in the
// isolated media viewer.
FocusScope {
  id: root
  objectName: "statusView"

  property var items: []
  property bool loading: false
  property bool multiAccount: false
  property bool showAvatars: true
  // account + "\n" + jid -> a cached chat photo.
  property var avatarPaths: ({})
  property var shortcuts: ({})
  property string timeFormat: "auto"
  property var now: new Date()
  property color foreground: Commons.Color.foreground
  property color surface: Commons.Color.background
  property color accent: Commons.Color.accent
  property color muted: foreground
  property string fontFamily: Style.font.family
  property int cursor: 0
  property bool cursorShown: false
  // The person whose updates are open (-1: the list) and which one.
  property int openGroup: -1
  property int storyIndex: 0

  signal closeRequested()
  signal openMediaRequested(var item, var gallery)

  readonly property var groups: {
    var byKey = ({})
    var order = []
    for (var i = 0; i < items.length; i++) {
      var item = items[i]
      if (!item || String(item.id || "") === "") continue
      var key = String(item.account || "") + "\n" + (item.from_me === true ? "" : String(item.sender_jid || item.sender || ""))
      if (!byKey[key]) {
        byKey[key] = { key: key, account: String(item.account || ""), from_me: item.from_me === true,
          jid: item.from_me === true ? "" : String(item.sender_jid || ""),
          name: item.from_me === true ? "My status" : (String(item.sender || "") || "WhatsApp contact"),
          latest: 0, updates: [] }
        order.push(byKey[key])
      }
      byKey[key].updates.push(item)
      byKey[key].latest = Math.max(byKey[key].latest, Number(item.timestamp || 0))
    }
    order.forEach(function(group) {
      group.updates.sort(function(a, b) { return Number(a.timestamp || 0) - Number(b.timestamp || 0) })
    })
    // Yours first, then the most recent first.
    return order.sort(function(a, b) {
      if (a.from_me !== b.from_me) return a.from_me ? -1 : 1
      return b.latest - a.latest
    })
  }
  readonly property var currentGroup: openGroup >= 0 && openGroup < groups.length ? groups[openGroup] : null
  readonly property var currentStatus: currentGroup && storyIndex >= 0 && storyIndex < currentGroup.updates.length
    ? currentGroup.updates[storyIndex] : null
  readonly property bool currentLocal: !!currentStatus && String(currentStatus.local_path || "") !== ""
  readonly property bool currentVisual: !!currentStatus
    && ["image", "video", "gif"].indexOf(String(currentStatus.media_type || "")) >= 0

  function localUrl(path) {
    var value = String(path || "")
    if (value === "__demo__" || value === "__demo_photo__") return Qt.resolvedUrl("assets/demo-photo.png")
    return MediaModel.encodedFileUrl(value)
  }
  function ago(ts) {
    var seconds = Math.max(0, Math.floor(root.now.getTime() / 1000) - Number(ts || 0))
    if (seconds < 60) return "just now"
    if (seconds < 3600) return Math.floor(seconds / 60) + " min ago"
    if (seconds < 86400) return Math.floor(seconds / 3600) + " h ago"
    return TimeFormat.dayLabel(Number(ts || 0), root.now)
  }
  function avatarChat(group) {
    return { jid: group.jid || group.key, name: group.name, kind: "dm",
      avatar_path: root.avatarPaths[group.account + "\n" + group.jid] || "" }
  }
  function groupLine(group) {
    var count = group.updates.length
    var parts = [count === 1 ? "1 update" : count + " updates", ago(group.latest)]
    if (multiAccount && group.account !== "") parts.push(group.account)
    return parts.join(" · ")
  }
  function kindLabel(item) {
    var kind = String(item && item.media_type || "")
    return kind === "image" ? "Photo" : kind === "video" ? "Video" : kind === "gif" ? "GIF"
      : kind === "audio" ? "Voice note" : kind !== "" ? kind.charAt(0).toUpperCase() + kind.slice(1) : ""
  }

  function move(delta) {
    if (groups.length === 0) return
    cursor = Math.max(0, Math.min(groups.length - 1, cursor + (cursorShown ? delta : 0)))
    cursorShown = true
    list.positionViewAtIndex(cursor, ListView.Contain)
  }
  function openAt(index) {
    if (index < 0 || index >= groups.length) return false
    cursor = index
    openGroup = index
    storyIndex = 0
    root.forceActiveFocus()
    return true
  }
  function closeStory() {
    if (openGroup < 0) return false
    cursor = openGroup
    openGroup = -1
    storyIndex = 0
    return true
  }
  // Past the last update of a person comes the next person, then the list.
  function step(delta) {
    if (!currentGroup) return false
    var next = storyIndex + delta
    if (next >= 0 && next < currentGroup.updates.length) { storyIndex = next; return true }
    var group = openGroup + (delta > 0 ? 1 : -1)
    if (group < 0) { storyIndex = 0; return true }
    if (group >= groups.length) return closeStory()
    openGroup = group
    storyIndex = delta > 0 ? 0 : groups[group].updates.length - 1
    return true
  }
  function openCurrentMedia() {
    if (!currentLocal || !currentVisual) return false
    var gallery = currentGroup.updates.filter(function(item) {
      return String(item.local_path || "") !== ""
        && ["image", "video", "gif"].indexOf(String(item.media_type || "")) >= 0
    })
    openMediaRequested(currentStatus, gallery)
    return true
  }
  onGroupsChanged: {
    cursor = Math.max(0, Math.min(cursor, groups.length - 1))
    if (openGroup >= groups.length) closeStory()
  }
  onVisibleChanged: if (visible) { cursorShown = false; cursor = 0; openGroup = -1; storyIndex = 0 }

  Keys.onPressed: function(event) {
    if (Shortcuts.matches("back", event, shortcuts, true)) {
      if (!closeStory()) closeRequested()
      event.accepted = true
    } else if (openGroup >= 0) {
      if (Shortcuts.matches("viewerNext", event, shortcuts, true) || Shortcuts.matches("next", event, shortcuts, true)) {
        event.accepted = step(1)
      } else if (Shortcuts.matches("viewerPrevious", event, shortcuts, true) || Shortcuts.matches("previous", event, shortcuts, true)) {
        event.accepted = step(-1)
      } else if (Shortcuts.matches("openMedia", event, shortcuts, true) || Shortcuts.matches("openChat", event, shortcuts, true)) {
        event.accepted = openCurrentMedia()
      }
    } else if (Shortcuts.matches("next", event, shortcuts, true)) {
      move(1)
      event.accepted = true
    } else if (Shortcuts.matches("previous", event, shortcuts, true)) {
      move(-1)
      event.accepted = true
    } else if (Shortcuts.matches("openChat", event, shortcuts, true)) {
      event.accepted = openAt(cursor)
    }
  }

  Rectangle {
    anchors.fill: parent
    color: root.surface
  }
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
      PanelActionButton {
        id: backButton
        objectName: "statusBack"
        visible: root.openGroup >= 0
        anchors.left: parent.left
        anchors.leftMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        iconText: "󰅁"
        tooltipText: "All status updates"
        foreground: root.muted
        hoverColor: root.foreground
        fontFamily: root.fontFamily
        fontSize: Style.font.body
        size: Style.space(30)
        onClicked: root.closeStory()
      }
      Text {
        textFormat: Text.PlainText
        objectName: "statusTitle"
        anchors.left: backButton.visible ? backButton.right : parent.left
        anchors.leftMargin: backButton.visible ? Style.space(6) : Style.space(18)
        anchors.right: closeButton.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        text: root.currentGroup ? root.currentGroup.name : "Status updates"
        elide: Text.ElideRight
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
        font.weight: Font.Bold
      }
      PanelActionButton {
        id: closeButton
        objectName: "statusClose"
        anchors.right: parent.right
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        iconText: "󰅖"
        tooltipText: "Close status updates"
        foreground: root.muted
        hoverColor: root.foreground
        fontFamily: root.fontFamily
        fontSize: Style.font.body
        size: Style.space(30)
        onClicked: root.closeRequested()
      }
    }

    Text {
      textFormat: Text.PlainText
      id: privacyNote
      objectName: "statusPrivacyNote"
      anchors.top: header.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: Style.space(18)
      anchors.rightMargin: Style.space(18)
      text: "Seen privately: viewing here sends no read receipt. Last 24 hours, from this computer's copy."
      wrapMode: Text.WordWrap
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    ListView {
      id: list
      objectName: "statusList"
      visible: root.openGroup < 0
      anchors.top: privacyNote.bottom
      anchors.topMargin: Style.space(10)
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      clip: true
      spacing: Style.space(2)
      model: root.groups
      currentIndex: root.cursor
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
      delegate: Rectangle {
        id: row
        required property var modelData
        required property int index
        objectName: "statusRow-" + index
        width: list.width
        height: Style.space(60)
        radius: Style.cornerRadius
        color: root.cursorShown && index === root.cursor ? Style.selectedFillFor(root.foreground, root.accent)
          : (rowHover.hovered ? Style.hoverFillFor(root.foreground, root.accent) : "transparent")
        Rectangle {
          id: ring
          anchors.left: parent.left
          anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(46)
          height: width
          radius: width / 2
          color: "transparent"
          border.width: Style.space(2)
          border.color: root.accent
          ChatAvatar {
            anchors.centerIn: parent
            width: parent.width - Style.space(8)
            height: width
            chat: root.avatarChat(row.modelData)
            showPhoto: root.showAvatars
            foreground: root.foreground
            background: root.surface
            accent: root.accent
            fontFamily: root.fontFamily
          }
        }
        Column {
          anchors.left: ring.right
          anchors.leftMargin: Style.space(12)
          anchors.right: parent.right
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          Text {
            textFormat: Text.PlainText
            objectName: "statusName"
            width: parent.width
            text: row.modelData.name
            color: root.foreground
            elide: Text.ElideRight
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: root.groupLine(row.modelData)
            color: root.muted
            elide: Text.ElideRight
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.openAt(row.index) }
      }
    }

    Text {
      textFormat: Text.PlainText
      objectName: "statusEmpty"
      anchors.centerIn: list
      width: list.width - Style.space(24)
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      visible: root.openGroup < 0 && root.groups.length === 0
      text: root.loading ? "Reading status updates…"
        : "No status updates from the last 24 hours on this computer."
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    // One person's updates, one at a time.
    Item {
      id: story
      objectName: "statusStory"
      visible: !!root.currentStatus
      anchors.top: privacyNote.bottom
      anchors.topMargin: Style.space(10)
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: Style.space(12)

      Row {
        id: segments
        objectName: "statusSegments"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(4)
        Repeater {
          model: root.currentGroup ? root.currentGroup.updates.length : 0
          delegate: Rectangle {
            required property int index
            width: (segments.width - segments.spacing * Math.max(0, (root.currentGroup ? root.currentGroup.updates.length : 1) - 1))
              / Math.max(1, root.currentGroup ? root.currentGroup.updates.length : 1)
            height: Style.space(3)
            radius: height / 2
            color: index <= root.storyIndex ? root.accent
              : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.2)
          }
        }
      }
      Text {
        textFormat: Text.PlainText
        id: storyMeta
        objectName: "statusMeta"
        anchors.top: segments.bottom
        anchors.topMargin: Style.space(8)
        anchors.left: parent.left
        anchors.right: parent.right
        text: root.currentStatus
          ? [String(root.storyIndex + 1) + " of " + root.currentGroup.updates.length,
             root.ago(root.currentStatus.timestamp), root.kindLabel(root.currentStatus)]
              .filter(function(part) { return part !== "" }).join(" · ")
          : ""
        elide: Text.ElideRight
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Rectangle {
        id: card
        objectName: "statusCard"
        anchors.top: storyMeta.bottom
        anchors.topMargin: Style.space(10)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: navigation.top
        anchors.bottomMargin: Style.space(10)
        radius: Style.cornerRadius
        clip: true
        color: root.currentVisual ? Qt.rgba(0, 0, 0, 0.35)
          : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)

        SafeImage {
          id: storyImage
          objectName: "statusImage"
          anchors.fill: parent
          anchors.bottomMargin: caption.visible ? caption.height + Style.space(16) : 0
          visible: root.currentLocal && root.currentVisual && !MediaModel.isVideo(root.currentStatus)
          source: visible ? root.localUrl(root.currentStatus.local_path) : ""
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          sourceSize.width: 1280
          sourceSize.height: 1280
        }
        Column {
          objectName: "statusMediaPlaceholder"
          anchors.centerIn: parent
          width: parent.width - Style.space(32)
          spacing: Style.space(8)
          visible: root.currentVisual && (!root.currentLocal || MediaModel.isVideo(root.currentStatus))
          Text {
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.currentLocal ? "󰐊" : "󰠫"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.iconLarge
          }
          Text {
            textFormat: Text.PlainText
            objectName: "statusMediaNote"
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.currentLocal ? "Play · " + Shortcuts.bindings("openMedia", root.shortcuts, true).map(Shortcuts.label).join(" / ")
              : "This " + root.kindLabel(root.currentStatus).toLowerCase()
                + " is not on this computer; open it on your phone."
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
        TapHandler {
          enabled: root.currentLocal && root.currentVisual
          onTapped: root.openCurrentMedia()
        }
        HoverHandler {
          enabled: root.currentLocal && root.currentVisual
          cursorShape: Qt.PointingHandCursor
        }
        Text {
          textFormat: Text.PlainText
          objectName: "statusText"
          anchors.centerIn: parent
          width: parent.width - Style.space(40)
          visible: !root.currentVisual
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          elide: Text.ElideRight
          maximumLineCount: 14
          text: root.currentStatus
            ? (String(root.currentStatus.text || "") || String(root.currentStatus.caption || "")
              || (root.kindLabel(root.currentStatus) !== "" ? root.kindLabel(root.currentStatus) + " status" : ""))
            : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: String(text).length > 140 ? Style.font.body : Style.font.title
        }
        Text {
          textFormat: Text.PlainText
          id: caption
          objectName: "statusCaption"
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(8)
          anchors.horizontalCenter: parent.horizontalCenter
          width: parent.width - Style.space(24)
          visible: root.currentVisual && text !== ""
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          maximumLineCount: 4
          elide: Text.ElideRight
          text: root.currentStatus ? String(root.currentStatus.caption || root.currentStatus.text || "") : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }

      Row {
        id: navigation
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(16)
        PanelActionButton {
          objectName: "statusPrevious"
          iconText: "󰅁"
          tooltipText: "Previous · " + Shortcuts.bindings("viewerPrevious", root.shortcuts, true).map(Shortcuts.label).join(" / ")
          foreground: root.muted
          hoverColor: root.foreground
          fontFamily: root.fontFamily
          fontSize: Style.font.icon
          size: Style.space(36)
          onClicked: root.step(-1)
        }
        PanelActionButton {
          objectName: "statusNext"
          iconText: "󰅂"
          tooltipText: "Next · " + Shortcuts.bindings("viewerNext", root.shortcuts, true).map(Shortcuts.label).join(" / ")
          foreground: root.muted
          hoverColor: root.foreground
          fontFamily: root.fontFamily
          fontSize: Style.font.icon
          size: Style.space(36)
          onClicked: root.step(1)
        }
      }
    }
  }
}
