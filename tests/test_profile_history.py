"""Own profile and phone history requests, against a synthetic private wacli."""
from __future__ import annotations

from contextlib import closing
import importlib.util
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

SPEC = importlib.util.spec_from_file_location(
    "profile_history_core", Path(__file__).resolve().parents[1] / "bin/omawhatsapp_core.py")
core = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(core)

sys.path.insert(0, str(Path(__file__).resolve().parent))
os.environ.setdefault("OMAW_SCRIPT", str(Path(__file__).resolve().parents[1] / "bin/omawhatsapp_core.py"))
from test_backend import SCHEMA  # noqa: E402  the same synthetic mirror schema

OWN = "15550001111@s.whatsapp.net"
PNG = b"\x89PNG\r\n\x1a\n" + b"\0" * 64

# A private wacli: it answers the capability probe and, for each private
# call, records its real argv and /proc cmdline beside the stdin arguments.
FAKE_WACLI = r'''#!{python}
import hashlib, json, os, sys
LOG = {log!r}
if sys.argv[1:] == ["--private-args-version"]:
    print(json.dumps({{"protocol": 1, "max_bytes": 65536}}))
    raise SystemExit(0)
args = json.load(sys.stdin) if sys.argv[1:] == ["--private-args-stdin"] else sys.argv[1:]
entry = {{"argv": sys.argv[1:],
          "cmdline": open("/proc/self/cmdline", "rb").read().decode("utf-8", "replace").split("\0"),
          "args": args}}
def answer(data, code=0):
    with open(LOG, "a", encoding="utf-8") as log:
        log.write(json.dumps(entry) + "\n")
    print(json.dumps({{"success": code == 0, "data": data, "error": None if code == 0 else "synthetic"}}))
    raise SystemExit(code)
if "doctor" in args:
    answer({{"authenticated": True, "linked_jid": "15550001111:7@s.whatsapp.net"}})
if "set-picture" in args:
    path = args[-1]
    data = open(path, "rb").read() if os.path.isfile(path) else b""
    entry["staged"] = {{"path": path, "sha": hashlib.sha256(data).hexdigest(),
                        "mode": oct(os.stat(path).st_mode & 0o777) if data else ""}}
    answer({{"picture_id": "synthetic-picture"}})
if "set-name" in args:
    answer({{"name": args[-1]}})
if "set-about" in args:
    answer({{"about": args[-1]}})
if "remove-picture" in args:
    answer({{"removed": True}})
if "get-about" in args:
    answer({{"jid": "x", "about": "Synthetic about"}})
if "picture-info" in args:
    answer({{"jid": "x", "unchanged": True}})
if "backfill" in args:
    answer({{"chat": "x", "requests_sent": 1, "responses_seen": 1,
             "messages_added": 7, "messages_synced": 7}})
answer(None, 1)
'''


class ProfileAndHistoryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.log = self.root / "wacli.log"
        self.wacli = self.root / "wacli"
        self.wacli.write_text(FAKE_WACLI.format(python=sys.executable, log=str(self.log)),
                              encoding="utf-8")
        self.wacli.chmod(0o700)
        self.store = self.root / "store"
        self.store.mkdir()
        with closing(sqlite3.connect(self.store / "wacli.db")) as connection, connection:
            connection.executescript(SCHEMA)
            connection.executemany(
                "INSERT INTO chats (jid, kind, name, last_message_ts) VALUES (?, ?, ?, ?)", [
                    ("alex@s.whatsapp.net", "dm", "Alex", 40),
                    ("news@newsletter", "newsletter", "News", 50),
                ])
            connection.execute("INSERT INTO messages (chat_jid, msg_id, ts, from_me, text) "
                               "VALUES ('alex@s.whatsapp.net', 'a1', 40, 0, 'hello')")
            connection.execute("INSERT INTO contacts (jid, push_name) VALUES (?, 'Synthetic Me')", [OWN])
        self.backend = core.Backend(store_dir=self.store, state_dir=self.root / "state",
                                    wacli=self.wacli, account_config=self.root / "none")
        # No real systemd: this account's sync is not running unless a test says so.
        quiet = mock.patch.object(self.backend, "_sync_active", return_value=False)
        quiet.start()
        self.addCleanup(quiet.stop)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def calls(self, leaf: str = "") -> list[dict]:
        if not self.log.exists():
            return []
        entries = [json.loads(line) for line in self.log.read_text(encoding="utf-8").splitlines()]
        return [entry for entry in entries if not leaf or leaf in entry["args"]]

    # ------------------------------------------------------------ profile

    def test_name_and_about_reach_wacli_only_on_private_stdin(self) -> None:
        name = "-Synthetic Grüße"
        about = "Out of office · 世界"
        profile = self.backend.set_own_profile("name", f"  {name} ", "whatsapp-write")
        self.backend.set_own_profile("about", about, "whatsapp-write")
        for leaf, value in (("set-name", name), ("set-about", about)):
            [call] = self.calls(leaf)
            self.assertEqual(call["argv"], ["--private-args-stdin"])
            self.assertNotIn(value, " ".join(call["cmdline"]))
            self.assertEqual(call["args"][-4:], ["profile", leaf, "--", value],
                             "a value starting with a dash is never read as a flag")
        self.assertEqual(profile["name"], name, "the confirmed name is shown at once")
        shown = self.backend.own_profile()
        self.assertEqual((shown["name"], shown["about"]), (name, about))
        self.assertEqual(shown["phone"], "+15550001111")
        self.assertEqual(self.calls("get-about"), [], "showing the profile asks WhatsApp nothing")

    def test_profile_changes_need_the_matching_authorization(self) -> None:
        for authorization in ("", "remote-read", "destructive"):
            with self.assertRaisesRegex(core.OmaWhatsAppError, "whatsapp-write"):
                self.backend.set_own_profile("name", "Synthetic", authorization)
            with self.assertRaisesRegex(core.OmaWhatsAppError, "whatsapp-write"):
                self.backend.set_own_photo(str(self.root / "missing.png"), authorization)
        with self.assertRaisesRegex(core.OmaWhatsAppError, "destructive"):
            self.backend.remove_own_photo("whatsapp-write")
        with self.assertRaisesRegex(core.OmaWhatsAppError, "remote-read"):
            self.backend.refresh_own_profile("")
        self.assertEqual([call for call in self.calls() if "profile" in call["args"]], [])

    def test_name_and_about_are_bounded_one_line_text(self) -> None:
        rejected = [("name", "x" * 26), ("name", "   "), ("name", "two\nlines"),
                    ("name", None), ("about", "x" * 140), ("about", "tab\there"),
                    ("about", "bell\x7f"), ("status", "Synthetic")]
        for field, value in rejected:
            with self.assertRaises(core.OmaWhatsAppError, msg=f"{field}={value!r}"):
                self.backend.set_own_profile(field, value, "whatsapp-write")
        self.assertEqual(self.calls("profile"), [], "nothing out of bounds is dispatched")
        self.backend.set_own_profile("name", "x" * 25, "whatsapp-write")
        self.backend.set_own_profile("about", "😀" * 139, "whatsapp-write")
        self.assertEqual(len(self.calls("profile")), 2, "exactly WhatsApp's limits are accepted")

    def test_a_photo_is_checked_and_sent_from_a_private_copy(self) -> None:
        photo = self.root / "photo.png"
        photo.write_bytes(PNG)
        result = self.backend.set_own_photo(str(photo), "whatsapp-write")
        [call] = self.calls("set-picture")
        staged = Path(call["staged"]["path"])
        self.assertEqual(call["argv"], ["--private-args-stdin"])
        self.assertNotIn(str(staged), " ".join(call["cmdline"]))
        self.assertNotEqual(staged, photo, "wacli reads a copy the user cannot swap")
        self.assertEqual(staged.parent, self.root / "state" / "outgoing")
        self.assertEqual(call["staged"]["sha"], __import__("hashlib").sha256(PNG).hexdigest())
        self.assertEqual(call["staged"]["mode"], "0o600")
        self.assertFalse(staged.exists(), "the copy is removed afterwards")
        self.assertTrue(result["photo_path"], "the new photo shows from the private cache")
        self.assertEqual(Path(result["photo_path"]).read_bytes(), PNG)

    def test_photos_that_are_not_small_regular_jpeg_or_png_files_are_refused(self) -> None:
        gif = self.root / "photo.gif"
        gif.write_bytes(b"GIF89a" + b"\0" * 32)
        large = self.root / "large.png"
        with large.open("wb") as handle:
            handle.write(PNG)
            handle.truncate(core.MAX_PROFILE_PHOTO + 1)
        good = self.root / "good.png"
        good.write_bytes(PNG)
        link = self.root / "link.png"
        link.symlink_to(good)
        fifo = self.root / "pipe.png"
        os.mkfifo(fifo)
        for path, message in ((gif, "JPEG or PNG"), (large, "10 MB"), (link, "could not be opened"),
                              (self.root, "Choose a photo"), ("good.png", "Choose a photo"),
                              (fifo, "Choose a photo"), ("", "Choose a photo")):
            with self.assertRaisesRegex(core.OmaWhatsAppError, message, msg=str(path)):
                self.backend.set_own_photo(str(path), "whatsapp-write")
        self.assertEqual(self.calls("set-picture"), [])
        self.assertFalse(any((self.root / "state" / "outgoing").glob("*"))
                         if (self.root / "state" / "outgoing").exists() else False)

    def test_refresh_asks_about_and_photo_with_one_sync_pause(self) -> None:
        systemctl = mock.Mock(return_value=subprocess.CompletedProcess([], 0, "", ""))
        with mock.patch.object(self.backend, "_sync_active", return_value=True), \
                mock.patch.object(self.backend, "_systemctl_user", systemctl):
            profile = self.backend.refresh_own_profile("remote-read")
        self.assertEqual([call.args[0][0] for call in systemctl.call_args_list], ["stop", "start"],
                         "two reads, one pause, and sync always comes back")
        [about] = self.calls("get-about")
        [picture] = self.calls("picture-info")
        for call in (about, picture):
            self.assertEqual(call["argv"], ["--private-args-stdin"])
            self.assertIn(OWN, call["args"], "the device part of the linked JID is dropped")
        self.assertEqual(profile["about"], "Synthetic about")
        self.assertEqual(profile["name"], "Synthetic Me", "the name comes from the local contacts")
        self.assertGreater(profile["checked_at"], 0)

    def test_offline_refuses_profile_reads_writes_and_history_requests(self) -> None:
        photo = self.root / "photo.png"
        photo.write_bytes(PNG)
        with mock.patch.object(self.backend, "online", return_value=False):
            attempts = [
                lambda: self.backend.refresh_own_profile("remote-read"),
                lambda: self.backend.set_own_profile("name", "Synthetic", "whatsapp-write"),
                lambda: self.backend.set_own_profile("about", "Synthetic", "whatsapp-write"),
                lambda: self.backend.set_own_photo(str(photo), "whatsapp-write"),
                lambda: self.backend.remove_own_photo("destructive"),
                lambda: self.backend.history_backfill("alex@s.whatsapp.net", 50, "sync"),
            ]
            for attempt in attempts:
                with self.assertRaisesRegex(core.OmaWhatsAppError, "Offline mode"):
                    attempt()
            self.assertFalse(self.backend.own_profile()["online"])
        self.assertEqual([call for call in self.calls()
                          if "profile" in call["args"] or "history" in call["args"]], [])

    # ------------------------------------------------------------ history

    def test_backfill_is_one_bounded_batch_for_one_known_chat(self) -> None:
        result = self.backend.history_backfill("alex@s.whatsapp.net", 5000, "sync")
        [call] = self.calls("backfill")
        self.assertEqual(call["argv"], ["--private-args-stdin"])
        args = call["args"]
        position = args.index("history")
        self.assertEqual(args[position:], [
            "history", "backfill", "--chat", "alex@s.whatsapp.net", "--count", "100",
            "--requests", "1", "--wait", "30s", "--idle-exit", "5s"])
        self.assertEqual((result["requested"], result["added"], result["answered"]), (100, 7, True))
        self.backend.history_backfill("alex@s.whatsapp.net", "not a number", "sync")
        self.assertEqual(self.calls("backfill")[-1]["args"][position + 5], "50")

    def test_backfill_needs_authorization_and_an_exact_rail_chat(self) -> None:
        with self.assertRaisesRegex(core.OmaWhatsAppError, "authorization='sync'"):
            self.backend.history_backfill("alex@s.whatsapp.net", 50, "")
        for chat in ("stranger@s.whatsapp.net", "news@newsletter", ""):
            with self.assertRaises(core.OmaWhatsAppError, msg=chat):
                self.backend.history_backfill(chat, 50, "sync")
        self.assertEqual(self.calls("backfill"), [])

    def test_backfill_is_never_retried_after_a_timeout_or_a_failure(self) -> None:
        with mock.patch.object(self.backend, "_run", side_effect=core.OmaWhatsAppTimeout("slow")) as run:
            with self.assertRaisesRegex(core.OmaWhatsAppError, "did not answer in time"):
                self.backend.history_backfill("alex@s.whatsapp.net", 50, "sync")
        self.assertEqual(run.call_count, 1)
        refused = subprocess.CompletedProcess([], 1, '{"success":false,"error":"synthetic refusal"}', "")
        with mock.patch.object(self.backend, "_run", return_value=refused) as run:
            with self.assertRaisesRegex(core.OmaWhatsAppError, "synthetic refusal"):
                self.backend.history_backfill("alex@s.whatsapp.net", 50, "sync")
        self.assertEqual(run.call_count, 1)


if __name__ == "__main__":
    unittest.main()
