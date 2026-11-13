# Using OmaWhatsApp

[← Documentation](README.md)

Everything the app does, where to find it, and every shortcut. The
[README](../README.md) has the short tour; this page is the reference.

- [Two ways in: the bar and the full app](#two-ways-in-the-bar-and-the-full-app)
- [Chats and the chat list](#chats-and-the-chat-list)
- [Writing and sending](#writing-and-sending)
- [Messages you receive](#messages-you-receive)
- [Status updates and starred messages](#status-updates-and-starred-messages)
- [Reading, ticks and presence](#reading-ticks-and-presence)
- [Notifications and the bar badge](#notifications-and-the-bar-badge)
- [Several accounts](#several-accounts)
- [Groups and chat details](#groups-and-chat-details)
- [Settings](#settings)
- [Keyboard](#keyboard)
- [Commands and IPC](#commands-and-ipc)

## Two ways in: the bar and the full app

**The bar dropdown.** Click the bar icon for a compact client anchored to the
bar: recent chats with unread counts, search, the messages of a chat, and a
real composer with attachments, emoji, voice notes and clipboard paste. `O`
opens the same chat in the full app. Most replies never need more.

**The full app.** `Super+Shift+W` (see [Install](../README.md#install)) opens
the window: the chat list, the conversation, chat details, the media gallery,
search and settings. It is a real responsive layout at every size, from a wide
two-pane window down to a 360 px single pane.

Both open from the local mirror without waiting for the network, and closing
them keeps the chat list warm in the resident service.

**Under a replacement bar.** A cloned `omarchy.bar` gives its widgets no access
to the app's service ([omacom/omarchy#11051](https://github.com/omacom/omarchy/issues/11051)),
so the icon there has no badge and no dropdown. It stays on the bar, its
tooltip says why, and a click opens the full app through the app's own IPC.
The stock bar keeps everything.

## Chats and the chat list

- Every locally synced direct message and group, groups inside a Community
  included, as on the phone. Channels, calls and the Community itself are not
  in the list.
- Views: All, Unread, To reply (chats whose last message is theirs) and
  Groups; pinned chats stay on top under their own label.
- Search chats with `/`; `Ctrl+K` jumps to a chat by typing part of its name.
- Each row shows the time, the sender in groups, the kind of media, your ticks,
  "typing…" and your unsent draft.
- An `@` beside the unread count means an unread message mentions you.
- Hover a row, or right-click it, to mark it read or unread, pin, mute,
  archive or clear it locally.
- Drag the list's edge to resize it; `Ctrl+B` hides or shows it.
- Comfortable or compact density in Settings → Chats.

## Writing and sending

- Multiline text with WhatsApp formatting: `Ctrl+B`/`Ctrl+I` on a selection,
  `Ctrl+Shift+X` strikethrough, `Ctrl+Shift+M` monospace, and a formatting
  menu with lists, quotes and code.
- Reply, edit, react, delete for you or for everyone, and forward.
- Up to 10 files with one caption: documents (`Ctrl+O`), photos and videos
  (`Ctrl+Shift+O`), drag and drop, or paste text, screenshots, GIFs and files
  with `Ctrl+V`. Review and remove attachments before sending.
- Several photos go out as one album.
- **Voice notes are draft-first.** `Ctrl+Shift+V` starts and stops recording;
  stopping opens a review card with playback, discard and one explicit send.
  Nothing is sent when you stop.
- `@` in a group opens a member picker and sends a real WhatsApp mention.
- Polls, stickers (Emoji → Stickers) and interactive options.
- **Forward to many at once.** Pick messages in the conversation, then send
  them to several chats, or to a number with no chat yet, with an optional
  note.
- **Pick several messages** to forward, star or delete them together. Opening
  another chat ends the selection.
- **New chat** with `Ctrl+N`: search people by name or number, or type a
  number with its country code; WhatsApp confirms the number first.
- A contact card's Message button opens a draft chat with that person.
- **Signature** (off by default, per account): your name in bold at the top or
  the end of texts and captions, with Skip once in the message box.
- Every chat keeps its own draft, reply or edit, and pending attachments while
  you move between chats.
- Sending never waits: a message appears at once and, if it fails, stays as a
  bubble with Retry and Discard.
- While you type or record, the other person sees "typing…" or "recording
  audio…", as from the phone. It follows Settings → Reading → Show me online.

## Messages you receive

- Images, stickers, GIFs, videos, voice and audio, documents, locations,
  contact cards, quotes, reactions, polls, button rows, and edited, forwarded
  and starred marks.
- Voice notes play inline; the player keeps playing when new messages arrive
  and moves on to the next voice note when one ends.
- Media is downloaded when it arrives, or only when you open it (Settings →
  Media). A missing video downloads into its inline player with one click.
- **Native gallery**: photos, GIFs and videos full window, with zoom, previous
  and next, playback and metadata. `Space` opens the selected media.
- Save as… for any received file.
- With [Omasnap](https://github.com/tobi/omasnap) installed, Open externally
  sends images to its annotation editor.
- Select text to copy it, or use Copy in the message menu.
- At the top of a chat whose copy on this computer has ended, **Load older
  messages from your phone** asks the phone once for up to 50 earlier
  messages of that chat. It needs the phone online, is off while the account's
  background sync is paused, and is never repeated by itself.

## Status updates and starred messages

- **Status updates** (`Ctrl+Shift+U`, or the ring button above the chat list)
  lists the people who posted in the last 24 hours, yours first, from every
  account. Open one to go through their updates, oldest first, with Left/Right.
  Viewing is private: it reads this computer's copy and sends no read receipt.
  wacli does not download status photos and videos, so those say to open them
  on your phone unless the file is already here.
- **Starred messages** (`Ctrl+Shift+S`, the star button, or the starred count
  in chat details for one chat) lists every starred message, newest star first.
  Enter or a click opens its chat on that message, loading older history when
  it needs to; `U` or the button unstars it, with a wacli build that stars and
  for the account whose chat is open.

## Reading, ticks and presence

- Automatic marking as read on open or reply is opt-in in Settings → Reading.
  Existing private-reading choices are preserved during upgrades.
- Marking read syncs only your own devices by default. **Send read receipts
  to contacts** is a separate per-account opt-in for automatic reading, replies
  and manual mark-read. It follows WhatsApp privacy
  settings; a successful dispatch does not guarantee blue ticks.
- Ticks for what you send (sent, delivered, read) come from the receipts wacli
  0.21+ keeps; a group message turns blue only once every other member read
  it. A message with no stored receipt shows no tick rather than a guessed one.
- A contact's online, last seen and typing need the OmaWhatsApp wacli build
  and Settings → Reading → Show me online; with an official wacli the header
  says so. See
  [wacli: official and richer builds](../README.md#wacli-official-and-richer-builds).
- Linking from the first-run screen can ask the phone for older history
  (Bring older history, off by default) within a day and size limit.
- Settings → Media → Re-download missing voice notes asks the phone to send
  again voice notes that expired from WhatsApp's servers; sync pauses meanwhile.
- Files up to 2048 MB go out with wacli 0.25 or newer (100 MB with 0.24).

## Notifications and the bar badge

- A private desktop notification per chat with new messages: a generic notice
  and app icon, one short sound unless Omarchy's do not disturb is on, and a
  click that opens the chat or a small reply view by the bar. Chat names,
  message text and photos stay inside the app.
- Muted and archived chats stay silent, and so does the chat you are reading.
  Unmuting starts from now: nothing that arrived meanwhile pops up later.
- The bar badge counts unread chats, not messages; its tooltip gives both.
  Middle-click clears the current batch; right-click mutes every notification
  and shows a crossed bell until you right-click again.
- Notifications need `notify-send` from libnotify.

## Several accounts

- Link another account from Settings → Accounts or the `+` beside the account
  filters; a terminal shows the QR code.
- One merged chat list with a filter per account. Each account has a color, on
  the edge of its chats, on its filter and on its name in the conversation
  header.
- Each account has its own card in Settings → Accounts: background sync,
  notifications (one account can stay silent) and Unlink, which asks first,
  names the account and keeps the chats already on disk.
- Replies, receipts, offline mode and the signature follow the account of the
  chat on screen.

## Groups and chat details

- Click the conversation photo or name for its details: photo, about, phone,
  shared media, links and documents, starred messages, and actions.
- In a group: participants and their roles; admins can add, remove, make or
  dismiss admins, rename, edit the description, choose who may send or edit,
  manage the invite link and join requests. Anyone can leave.
- The media button in the header lists the chat's media, links and documents.

## Settings

| Section | What it holds |
|---|---|
| Reading | Mark read on open, mark read on reply, show me online (needed to see presence and to show typing) |
| Notifications | Desktop notifications, reply from the notification, message text, sound, unread badge, dropdown size |
| Chats | Signature, Enter sends, chat photos, list density, time format, message box height |
| Media | Automatic downloads, chat photo refresh |
| Sync & storage | Background sync, start with the system, Quit, letting AI agents use WhatsApp, removing it from this computer, storage used |
| Accounts | One card per account, link another |
| Profile | Your name, About text and photo per account; check them with WhatsApp or change them, each change confirmed first |
| Updates | Check for a newer version, update in a terminal, restart the shell after an update |

## Keyboard

### Everywhere

| Keys | Action |
|---|---|
| `Super+Shift+W` | Open or close the app (once bound) |
| `Ctrl+Q` | Quit: nothing arrives until you open it again from the bar |
| `Esc` | Step back: composer → messages → chat list → close |
| `J`/Down · `K`/Up | Move through messages or chats |
| `Enter` · `Shift+Enter` | Send · new line (swap in Settings → Chats) |
| `Ctrl+V` | Paste text, an image, a GIF or a file |
| `Ctrl+Shift+V` | Start or stop a voice note (never sends by itself) |

### Full app

| Keys | Action |
|---|---|
| `Ctrl+N` | New chat |
| `Ctrl+K` | Go to a chat by name |
| `Alt+1` … `Alt+9` | Open that position in the current chat list (search, view and account filter respected) |
| `Ctrl+F` | Find in this conversation |
| `Ctrl+B` | Hide or show the chat list (bold on a selection) |
| `Tab` · `Shift+Tab` | From the sidebar, cycle All → Unread → To reply → Groups → chats (reverse with Shift); Archived joins when present. Focus activates each filter. |
| `/` | Search chats from the list or filters |
| `C` | Write a message |
| `R` | Reply to the selected message |
| `Space` | Open the selected media; play or pause in the viewer |
| `Left` · `Right` | Previous or next item in the gallery |
| `+` · `-` · `0` | Zoom in, out, fit |
| `Page Up` · `Page Down` | Scroll a screen, even while typing |
| `Home` · `End` | Oldest loaded message · newest |
| `Ctrl+O` · `Ctrl+Shift+O` | Attach documents · photos and videos |
| `Ctrl+I` · `Ctrl+Shift+X` · `Ctrl+Shift+M` | Italic · strikethrough · monospace |
| `@`, then arrows and `Enter` | Mention a group member |

### Bar dropdown

| Keys | Action |
|---|---|
| `/` | Search recent chats |
| `Enter` | Open the chat and focus its message box |
| `O` | Open this chat in the full app |
| `Ctrl+O` | Attach files |

## Commands and IPC

Keybindings and hot corners can drive the app through the Omarchy shell:

```bash
omarchy-shell io.github.caioniehues.omawhatsapp toggleApp '{}'
omarchy-shell io.github.caioniehues.omawhatsapp toggleDropdown '{}'
omarchy-shell io.github.caioniehues.omawhatsapp openDropdown '{}'
```

`toggleDropdown` and `openDropdown` need the bar widget, as clicking its icon
does.

The helper is also a command line tool for scripts and agents; `omawhatsapp
--help` lists its commands. Its guarded wacli gateway, the agent skill and the
MCP server are described in the [README](../README.md#let-your-agent-use-whatsapp)
and in the [agent gateway reference](../skills/omawhatsapp/references/wacli-parity.md).

### Open a chat from a picker

`omawhatsapp launcher-chats` prints the chat list, newest first, one chat per
line: the name, the account and the chat's ID, separated by tabs (at most 500
chats, or `--limit`). It only reads the local mirror. Pipe the line you pick
into `omawhatsapp launcher-open` and the full app opens on that chat:

```bash
omawhatsapp launcher-chats | fzf --delimiter='\t' --with-nth=1 | omawhatsapp launcher-open
```

Any picker that returns the chosen line unchanged works the same way. The
chosen chat travels on standard input and reaches the shell as a one-use
token, so no chat ID shows up in a process list; a line for a chat that is not
in the chat list is refused.

Omarchy's own launcher cannot list chats yet: Omarchy 4.5 replaced Walker and
Elephant with the shell's Quickshell menu, whose runtime row sources are a
fixed set inside the shell (`providers` in `shell/plugins/menu/Menu.qml`), and
its user extension file takes static rows only. Writing chat names into that
file would keep private names in a config file, so OmaWhatsApp does not.

### Customize your keyboard

Open **Settings → Shortcuts**. Search by action or key, choose a group, or show
only customized actions. Click a key badge, press a new combination, then click
**Save shortcut**. A conflict names the other action and prevents saving;
change or remove that action's binding first. Use **+** for up to three
alternatives, **Remove binding** to disable a key, **Reset** for one action,
or **Reset all…** to restore the defaults after confirmation. Escape cancels
capture. Tab moves between controls and into the save/cancel buttons.

Bindings apply immediately to every account and every open app/mini-client
window on this device, persist privately, and survive upgrades: when an update
adds an action whose default key you already use, your binding keeps it and
the new action starts with no key. Media viewer and forwarding bindings have
their own contexts. Ordinary letters navigate
only when you are not typing. Writing, forwarding and window actions require a modifier
or function key, so assigning a shortcut cannot turn ordinary typing into a
send or another action. Copy, cut, undo, select-all, Tab navigation, and dialog
confirmation/cancellation retain their standard behavior. Ctrl+B retains its
context rule: selected text becomes bold; otherwise it toggles the sidebar.
The **Send message** binding overrides the default **Enter sends** preference;
new lines remain Enter or Shift+Enter as appropriate. Visible hints follow the
active bindings. Disabled actions can still be used by clicking their controls.

The desktop-wide launcher (Super+Shift+W by default) belongs to Omarchy's
Hyprland configuration. It is separate from in-app bindings; desktop shortcuts
may intercept keys before OmaWhatsApp sees them. This page does not rewrite
desktop configuration. Demo mode lets you try edits without saving preferences
or performing WhatsApp operations.
