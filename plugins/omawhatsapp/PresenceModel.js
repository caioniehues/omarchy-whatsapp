.pragma library
.import "TimeFormat.js" as TimeFormat

// Presence snapshot that the OmaWhatsApp wacli build keeps in each store
// (presence.json): who is online, when they were last seen, who is typing.
// Official wacli writes none, so every function answers "nothing known".
// Official 0.21+ can subscribe to presence, but WhatsApp answers only a
// device shown online, and the app's sync stays quiet unless the build can
// show it online just while the app has focus.

// A typing indicator never followed by "paused" stops after this, as on the phone.
var TYPING_TTL = 25
// Said where online/last seen would be when the user asked to see presence
// but this wacli cannot follow it.
var UNSUPPORTED_TEXT = "online status needs the OmaWhatsApp wacli build"

function parse(text) {
  var value
  try {
    value = JSON.parse(String(text || ""))
  } catch (error) {
    return null
  }
  if (!value || typeof value !== "object" || Number(value.version) !== 1) return null
  return {
    available: value.available === true,
    updatedAt: Number(value.updated_at || 0),
    contacts: value.contacts && typeof value.contacts === "object" ? value.contacts : ({}),
    typing: value.typing && typeof value.typing === "object" ? value.typing : ({})
  }
}

// People typing in a chat now, oldest first: [{ jid, media }].
function typingIn(snapshot, chatJid, nowSeconds) {
  if (!snapshot || !snapshot.typing) return []
  var senders = snapshot.typing[String(chatJid || "")]
  if (!senders || typeof senders !== "object") return []
  var out = []
  for (var jid in senders) {
    var entry = senders[jid]
    var at = Number(entry && entry.at || 0)
    if (at <= 0 || Number(nowSeconds) - at >= TYPING_TTL) continue
    out.push({ jid: jid, media: String(entry.media || ""), at: at })
  }
  out.sort(function(a, b) { return a.at - b.at })
  return out
}

function isTyping(snapshot, chatJid, nowSeconds) {
  return typingIn(snapshot, chatJid, nowSeconds).length > 0
}

function lastSeenLabel(timestamp, now, clockPattern) {
  var date = new Date(Number(timestamp) * 1000)
  var day = TimeFormat.dayLabel(timestamp, now)
  var when = day === "Today" ? "today" : day === "Yesterday" ? "yesterday" : day
  return "last seen " + when + " at " + Qt.formatDateTime(date, String(clockPattern || "HH:mm"))
}

// The line under the chat name. `live` asks for the accent color (typing).
// options: { now: seconds, date: Date for "today", clock: pattern,
//            group: bool, names: { jid: name },
//            unsupported: the user wants presence this wacli cannot follow }
function line(snapshot, chatJid, options) {
  var settings = options || ({})
  var empty = { text: "", live: false }
  if (String(chatJid || "") === "") return empty
  if (settings.unsupported === true)
    return settings.group === true ? empty : { text: UNSUPPORTED_TEXT, live: false }
  if (!snapshot) return empty
  var typers = typingIn(snapshot, chatJid, settings.now)
  if (typers.length > 0) {
    var recording = typers.every(function(item) { return item.media === "audio" })
    if (settings.group !== true)
      return { text: recording ? "recording audio…" : "typing…", live: true }
    var names = typers.map(function(item) {
      var name = String(settings.names && settings.names[item.jid] || "").trim()
      return name !== "" ? name.split(/\s+/)[0] : "Someone"
    })
    var verb = recording ? "recording audio…" : "typing…"
    if (names.length === 1) return { text: names[0] + " is " + verb, live: true }
    if (names.length === 2) return { text: names[0] + " and " + names[1] + " are " + verb, live: true }
    return { text: names.length + " people are " + verb, live: true }
  }
  if (settings.group === true || !snapshot.available) return empty
  var contact = snapshot.contacts[String(chatJid)]
  if (!contact || typeof contact !== "object") return empty
  if (contact.online === true) return { text: "online", live: false }
  var seen = Number(contact.last_seen || 0)
  if (seen > 0) return { text: lastSeenLabel(seen, settings.date, settings.clock), live: false }
  return empty
}
