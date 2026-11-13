# Private wacli input extension

The application uses wacli 0.26.0 built from pinned upstream source
(tag `v0.26.0`, commit `535a8b969cc83c3aad57f66be77e8fd4a7fcaaa3`; its
`git archive` tarball has SHA256
`c809f25ef916a42d0d69ddadf14e2b367feb5a3e6825ee64c143580ec45de420`) with two
patches from this directory, applied in this order:

1. `wacli-private-input.patch`: private stdin argument transport and the
   group-name fallback, maintained by OmaWhatsApp.
2. `wacli-omawhatsapp-outcomes.patch`: small OmaWhatsApp-specific changes,
   described [below](#omawhatsapp-outcomes).

The combined build is extension `omawhatsapp.4`. It is an OmaWhatsApp-maintained
extension, not an official upstream release. Upstream source and its MIT license
remain at https://github.com/openclaw/wacli.

`wacli --private-args-version` returns
`{"protocol":1,"max_bytes":65536,"build":"omawhatsapp.4"}`. Earlier private
builds return the same object with an older label (`omawhatsapp.3`) or without
`build`; the app accepts all of them and shows the label, when present, under
Settings → About.
`wacli --private-args-stdin` accepts one UTF-8 JSON array of arguments over stdin,
with a 64 KiB limit, 256 arguments and a three-second input deadline. The process
command line contains no message, caption, recipient or other payload. The array
replaces the whole argument list before wacli parses it, so every command and
flag works this way, including those added after wacli 0.19 (for example
`contacts save`, `chats mark-read --through-message-id` and paginated message
reads). Normal CLI parsing, account selection, authorization and locking still
apply after input decoding. Private-mode errors are sanitized, also under
`--events`: the typed store-lock error is
preserved so the app's existing pre-dispatch lock handoff remains available, and
two fixed outcome messages say whether a failed request was sent (see below).
The extension adds no send retries. Normal upstream command syntax stays available.

## Build and install

Run these commands on the target Linux machine from the OmaWhatsApp checkout
you reviewed. The bundled patches and builder are part of that checkout; review
changes to them before updating. Prerequisites are Git, Python 3.12 or newer,
Go 1.27.3 or newer (upstream's `go.mod` names toolchain `go1.27.3`; with an older
Go 1.27, the `go` command fetches that toolchain itself and verifies it against
the Go checksum database), a C compiler and the upstream build prerequisites.
Dependency modules are verified by Go against upstream's committed `go.sum`; do
not disable that verification.

```bash
# Keep all build files separate from any linked-device state or existing binary.
set -euo pipefail
build_dir=$(mktemp -d)
trap 'rm -rf -- "$build_dir"' EXIT
git clone https://github.com/openclaw/wacli.git "$build_dir/source"
git -C "$build_dir/source" checkout --detach 535a8b969cc83c3aad57f66be77e8fd4a7fcaaa3
python3 ./scripts/build-private-wacli "$build_dir/source" "$build_dir/wacli" --test
"$build_dir/wacli" --private-args-version
# Expected JSON: {"protocol":1,"max_bytes":65536,"build":"omawhatsapp.4"}
mkdir -p "$HOME/.local/bin"
install -m 755 "$build_dir/wacli" "$HOME/.local/bin/wacli"
# A running sync keeps the old binary's send queue until it restarts.
systemctl --user restart wacli-sync.service
```

With named accounts, also restart each `wacli-sync@<account>.service` that is
running (`systemctl --user list-units 'wacli-sync@*'` lists them). Until sync
restarts, it keeps the previous build's queue and outcome handling.

The builder refuses a different upstream HEAD and exports only committed source
(ignoring working-tree edits). It reads each patch once, records the SHA256 of
exactly those bytes, and applies them in order through `git apply` on stdin with
no enclosing repository, failing if any file is skipped or a patch's sentinel is
missing. It reads git's report untranslated (`LC_ALL=C`), so the build works the
same in every locale. It then runs plain/FTS tests, a `-race` run of the queue,
read-mark and outcome tests and Go vet, builds locally, and checks the protocol
and build label before producing the output. It does not install anything or
start WhatsApp. Installation happens only in the final explicit commands after a
successful build. No account relinking is needed; wacli updates its own local
store on first start, as with any upstream upgrade.

## Build evidence and historical binaries

The supported route is the local source build above. Earlier release archives
are historical artifacts, not supported installation candidates: a release's
own provenance JSON and pinned binary hash do not independently prove which
source produced it. There is no prebuilt installer in this release.

Pass `--provenance build-evidence.json` to the builder to record the exact
upstream commit, source archive SHA256 (compare it with the digest above), each
patch's SHA256 (`patch_sha256` for the private input patch,
`outcomes_patch_sha256` for the OmaWhatsApp outcomes), the
extension label, Go/compiler versions, build flags and resulting executable
SHA256. CI runs the same builder and publishes this evidence in its log and
build summary. Output hashes from different toolchains are not assumed equal,
and this evidence does not attest to the older distributed binary. CI does not
publish an installable binary.

The app refuses sensitive commands when this protocol is unavailable, before
passing any private content to a child. Direct local SQLite reads still work with older versions; sensitive external
reads and terminal authentication require private input too. Never substitute an unsafe argv fallback.

The private input patch's group-name fallback preserves an existing cached
subject when metadata is temporarily unavailable, rather than substituting the
current participant's push name. Since wacli 0.20, sync names groups from a
shared group-info cache (`groupChatName`, #447) instead of `ResolveChatName`, so
the patch covers both paths. Broadcast lists keep upstream's naming from local
contacts, then push name (#550): wacli no longer asks group metadata for them.
The app independently prefers the groups table's subject. Protocol version
remains 1. Earlier private builds (extensions `omawhatsapp.1` to `omawhatsapp.3`)
keep working; build and install `omawhatsapp.4` for wacli 0.26.0.

## Rebase onto wacli 0.26.0

Earlier builds (`omawhatsapp.3`) applied three patches to wacli 0.19.0. The
rebase keeps only what upstream still lacks:

- **Send-queue backport dropped.** `wacli-send-queue.patch` was an exact
  backport of upstream #456 (commit `7c1b3bf`). That commit is an ancestor of
  `v0.26.0` (released in 0.20.0), so the patch and CI's byte-for-byte
  attestation of it are gone.
- **Outcomes patch kept, smaller.** Upstream #483 (released in 0.22.0) stops
  fresh message retries after an ambiguous disconnect (`not connected`), which
  could duplicate a message. It does not touch any part of the outcomes patch:
  the read-mark send-slot bypass, the fixed private-mode outcome messages, and
  the send attempt's own deadline (upstream still reports it as a definite
  "send timed out after …") are all still needed. Upstream's
  `writeDelegateResult` and app-state bypass (#454) are now part of the base,
  so the patch only adds read marks to that bypass. Since 0.22, a mark-read
  bounded by `--through-message-id` uses its own delegate kind; it is an
  app-state write too and bypasses the slot the same way, unless it asks for
  `--receipts`.
- **Private input ported.** The transport itself needed no change: wacli 0.26.0
  still reads arguments only in `main`, and every new command parses the
  decoded list. The group-name fallback moved to cover sync's new group naming
  path and leaves broadcast lists to upstream (#550); upstream's
  `TestFailedGroupInfoLookupIsReusedBriefly` is updated to expect no
  sender-named group.
- **Build label** `omawhatsapp.4`.

## Interactive send queue

Upstream (#456, in wacli since 0.20.0) puts every delegated operation behind one send
slot whose wait is bounded by the caller's deadline, paced or not. A request
still queued when that deadline arrives is refused with "it was not sent" and
is never dispatched later; a reply margin lets the refusal arrive before the
caller gives up.

The app passes each operation's budget to wacli as `--timeout`, in whole
milliseconds and slightly below the helper's own limit (a tenth of the budget,
from 0.5 to 5 seconds, at most half), so wacli answers before the helper stops
it. The helper's hard limit stays exactly the caller's budget, including the
2-second total for inline mention lookups. Protocol version, account selection
and private stdin transport are unchanged.

## OmaWhatsApp outcomes

`wacli-omawhatsapp-outcomes.patch` holds only changes specific to OmaWhatsApp.
Its header justifies each one:

- **App-state read marks bypass the send slot.** `chats mark-read` (including
  `--through-message-id`) and `chats mark-unread` without `--receipts` can wait
  minutes on app-state recovery. wacli already serializes them on its own
  chat-state slot, so in the send slot they only held up interactive sends.
  Receipt-mode read marks never enter recovery and stay serialized and paced in
  the send slot, as upstream keeps them. The bypass follows upstream's own
  app-state bypass (bb80227, #454).
  A read mark can now overlap a reconnect started by a failed send; it then
  fails like any other read-mark failure: the app shows the error, the chat
  keeps its stored read state, and marking it again works. Contributed by
  Brunno Vert (#28).
- **Fixed private-mode outcomes.** Private input replaces every error with
  "Private WhatsApp command failed.", which hid upstream's "it was not sent" and
  "may still have gone through" reports. The daemon's exact pre-dispatch
  refusals now print "Private WhatsApp command was not sent."; a request that
  failed after dispatch at its deadline, an unanswered delegate and any other
  deadline print "Private WhatsApp command outcome is unknown." Both strings are
  fixed: no socket path, wrapped error, identifier or content is printed.
- **A send attempt's own deadline is uncertain.** wacli cuts each send attempt at
  45 seconds (plus a second per 64 KiB of an attachment). The command's budget
  can be longer, so an attempt could expire after its message frame was written
  while the request was still live; upstream reports that as a definite failure.
  Its text is unchanged, but it now counts as a deadline and is reported as
  uncertain.
- **Build label.** `--private-args-version` adds `"build":"omawhatsapp.4"`.

What the app shows:

| wacli reports | App result | Retry |
| --- | --- | --- |
| "…was not sent." | "WhatsApp was busy with an earlier request, so this was not sent. You can try again." (`outcome: "not-sent"`) | Safe; only on the user's request |
| "…outcome is unknown.", or a generic failure near or after wacli's own deadline (older builds) | "WhatsApp did not confirm this in time. It may still have gone through, so check before trying again." (`outcome: "uncertain"`); reads keep "WhatsApp took too long to respond." | Never automatic |
| Any other failure | The generic failure, as before | Only on the user's request |

The uncertain outcome is reported when the caller's deadline, or a single send
attempt's own deadline, expires after dispatch, and when the sync process
never answers. A failed send bubble then says it may have been sent, and Try
again stays an explicit choice. An older private build reports only the generic
failure; the app treats it as uncertain when it arrives at wacli's deadline, or
within the half second (a tenth of shorter budgets) by which a rebuilt sync
answers before it, so its result is never less cautious than before.
