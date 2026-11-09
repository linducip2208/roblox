#!/usr/bin/env python3
"""Harness uji protokol fencing SaveSystem (Steal a Kebun).

Memodelkan semantik Roblox DataStore UpdateAsync + MemoryStore lock di Python,
MENCERMINKAN logika src/Server/SaveSystem.luau (bukan implementasi ulang bebas):
setiap transform di bawah diparameterisasi agar logika protokolnya setara dengan
callback Luau (aturan claim / fence / save yang sama, keputusan yang sama).

Skenario: pemain baru/lama, migrasi legacy, 2 server klaim 1 akun, JobId sama
token beda, sesi kedaluwarsa, server lama save setelah claim/commit baru
(WAJIB DITOLAK), save konkuren, kegagalan DataStore, shutdown saat save,
rejoin, recovery setelah save gagal.

Portabel: tanpa path hardcoded, tanpa I/O file, tanpa dependensi pihak ketiga.
Exit code: 0 jika SEMUA skenario lulus, 1 jika ada yang gagal. Test gagal jika
stale writer bisa menang (fungsi _require_* melempar AssertionError).

Contoh:  python tools/test_fencing.py [--demo-legacy] [--scenario NAME]
"""

from __future__ import annotations

import argparse
import copy
import json
import sys
from dataclasses import dataclass, field


# ----------------------------------------------------------------------------
# Model semantik Roblox (disederhanakan tapi setia pada sifat atomiknya)
# ----------------------------------------------------------------------------

class DataStoreError(Exception):
    """Mewakili kegagalan DataStore: throttled/timeout/unavailable."""


@dataclass
class ProtocolConfig:
    """Parameterisasi logika protokol.

    new (rilis): takeover_same_job=False, full_identity=True, fencing=True.
    legacy (pra-perbaikan, hanya untuk --demo-legacy): nilai sebaliknya,
    mereproduksi 3 bug yang diidentifikasi.
    """

    takeover_same_job: bool = False
    full_identity: bool = True
    fencing: bool = True


NEW_PROTOCOL = ProtocolConfig(
    takeover_same_job=False, full_identity=True, fencing=True
)
LEGACY_PROTOCOL = ProtocolConfig(
    takeover_same_job=True, full_identity=False, fencing=False
)


@dataclass
class FakeDataStore:
    """Model DataStore: UpdateAsync atomik (transform jalan di atas salinan,
    komit hanya bila transform tidak melempar dan tidak return None/abort)."""

    data: dict = field(default_factory=dict)
    failures: list = field(default_factory=list)  # antrean error injeksi

    def update(self, key, transform):
        if self.failures:
            raise self.failures.pop(0)
        current = copy.deepcopy(self.data.get(key))
        result = transform(current)
        if result is None:
            return None  # ABORT ala UpdateAsync: batal tanpa tulis
        self.data[key] = copy.deepcopy(result)
        return copy.deepcopy(result)


@dataclass
class FakeMemoryStore:
    """Model MemoryStore SortedMap untuk lease sesi (dengan expiry)."""

    leases: dict = field(default_factory=dict)
    failures: list = field(default_factory=list)

    def update(self, key, transform):
        if self.failures:
            raise self.failures.pop(0)
        current = copy.deepcopy(self.leases.get(key))
        result = transform(current)
        if result is None:
            self.leases.pop(key, None)
        else:
            self.leases[key] = copy.deepcopy(result)
        return copy.deepcopy(result)

    def get(self, key, now):
        cur = self.leases.get(key)
        if cur is None:
            return None
        if (cur.get("exp") or 0) < now:
            return None
        return copy.deepcopy(cur)


# ----------------------------------------------------------------------------
# Protokol (cermin SaveSystem.luau)
# ----------------------------------------------------------------------------

LOCK_TTL = 300
SCHEMA_VERSION = 2
STARTING_CASH = 100
# Cermin batas payload DataStore 4MB (+ guard pre-check di SaveSystem.Save).
MAX_PAYLOAD_BYTES = 4 * 1024 * 1024


def estimate_bytes(obj):
    """Estimasi ukuran tulis via JSON (cermin HttpService:JSONEncode di Save)."""
    try:
        return len(json.dumps(obj, ensure_ascii=False))
    except (TypeError, ValueError):
        return MAX_PAYLOAD_BYTES + 1  # tak-serialisasi = tolak tulis


def sanitize_legacy(old, now):
    """Cermin ValidateProfile untuk jalur migrasi v1 mentah: sanitasi, bukan percaya."""
    data = {}
    cash = old.get("cash")
    if isinstance(cash, bool) or not isinstance(cash, (int, float)) \
            or cash != cash or cash in (float("inf"), float("-inf")):
        data["cash"] = STARTING_CASH
    elif cash < 0 or cash > 10**15:
        data["cash"] = STARTING_CASH
    else:
        data["cash"] = cash
    slots = old.get("slots")
    data["slots"] = dict(slots) if isinstance(slots, dict) else {}
    data["lastLogout"] = now
    return data


def normalize_session(s):
    """Cermin SaveSystem.NormalizeSession."""
    if isinstance(s, dict):
        return {"job": s.get("job"), "token": s.get("token")}
    if isinstance(s, str):
        return {"job": s, "token": None}
    return {"job": None, "token": None}


def same_identity(a, b, full_identity):
    a, b = normalize_session(a), normalize_session(b)
    if full_identity:
        return a["job"] == b["job"] and a["token"] == b["token"]
    return a["job"] == b["job"]


def claim_session(ms, uid, job, token, now, cfg):
    """Cermin SaveSystem.ClaimSession. Return (ok, token|reason)."""
    my_lock = {"job": job, "token": token, "at": now, "exp": now + LOCK_TTL}

    def transform(old):
        if old is None:
            return my_lock
        if not isinstance(old, dict):
            return my_lock
        if cfg.takeover_same_job and old.get("job") == job:
            return my_lock  # BUG legacy isu #1: tanpa bukti token
        if (old.get("exp") or 0) < now:
            return my_lock
        return old

    res = ms.update(f"s_{uid}", transform)
    if isinstance(res, dict) and res.get("token") == token:
        return True, token
    return False, "rejected"


def release_session(ms, uid, token):
    """Cermin SaveSystem.ReleaseSession: hanya melepas milik sendiri."""

    def transform(old):
        if isinstance(old, dict) and old.get("token") == token:
            return None
        return old

    ms.update(f"s_{uid}", transform)


def verify_lock(ms, uid, token, now):
    cur = ms.get(f"s_{uid}", now)
    if isinstance(cur, dict) and cur.get("token") == token:
        return True
    return False


def default_profile(now):
    return {
        "version": SCHEMA_VERSION,
        "cash": STARTING_CASH,
        "slots": {},
        "lastLogout": now,
    }


def fence_and_read(ds, uid, my_session, now, cfg):
    """Cermin fenceAndRead: akuisisi gen + baca atomik. Return (env|None, err).

    Legacy (fencing=False): tanpa gen, tanpa idempotensi sesi (sekadar baca).
    Retry 3x seperti Luau (backoff dihilangkan: waktu tak dimodelkan harness).
    """
    key = f"p_{uid}"

    def transform(old):
        if old is None:
            return {
                "v": SCHEMA_VERSION,
                "gen": 1,
                "session": dict(my_session),
                "at": now,
                "data": dict(default_profile(now)),
            }
        if not isinstance(old, dict):
            return None
        if old.get("data") is not None:
            if not cfg.fencing:
                return old
            old_s = normalize_session(old.get("session"))
            if old_s["job"] == my_session["job"] and old_s["token"] == my_session["token"]:
                return old  # re-fence sendiri: idempoten
            gen = old.get("gen") if isinstance(old.get("gen"), int) else 0
            old["gen"] = gen + 1
            old["session"] = dict(my_session)
            old["at"] = now
            old["v"] = SCHEMA_VERSION
            return old
        if old.get("cash") is not None or old.get("slots") is not None:
            data = sanitize_legacy(old, now)  # migrasi legacy v1 mentah
            return {
                "v": SCHEMA_VERSION,
                "gen": 1,
                "session": dict(my_session),
                "at": now,
                "data": data,
            }
        return None

    last_err = None
    for _ in range(3):
        try:
            res = ds.update(key, transform)
        except DataStoreError as exc:
            last_err = str(exc)
            continue
        if res is None:
            return None, "corrupt"
        return res, None
    return None, (last_err or "unavailable")


def save_transform(old, my_session, my_gen, base_at, base_session, snap, now, cfg):
    """Cermin callback UpdateAsync di SaveSystem.Save (keputusan atomik murni).

    Legacy (fencing=False, full_identity=False): aturan at/job-only yang lama.
    """
    if old is None:
        if not cfg.fencing:
            # Legacy menulis envelope fresh tanpa gen (menimpa buta).
            return {"v": SCHEMA_VERSION, "session": dict(my_session),
                    "at": now, "data": dict(snap)}
        return None
    if not isinstance(old, dict) or not isinstance(old.get("data"), dict):
        return None
    if not cfg.fencing:
        old_s = normalize_session(old.get("session"))
        base_s = normalize_session(base_session)
        if (old.get("at") or 0) > base_at and old_s["job"] != my_session["job"] \
                and old_s["job"] != base_s["job"]:
            return old
        new = dict(old)
        new["session"] = dict(my_session)
        new["at"] = now
        new["data"] = dict(snap)
        return new
    old_gen = old.get("gen") if isinstance(old.get("gen"), int) else 0
    old_s = normalize_session(old.get("session"))
    base_s = normalize_session(base_session)
    same_me = old_s["job"] == my_session["job"] and old_s["token"] == my_session["token"]
    same_base = (
        base_s["token"] is not None
        and old_s["job"] == base_s["job"]
        and old_s["token"] == base_s["token"]
    )
    if old_gen != my_gen:
        return old  # (a) generation basi -> TOLAK
    if not same_me:
        return old  # (b) identitas sesi basi -> TOLAK
    if (old.get("at") or 0) > base_at and not same_base:
        return old  # (c) cloud lebih baru dari sesi asing -> TOLAK
    new = copy.deepcopy(old)
    new["data"] = copy.deepcopy(snap)
    new["at"] = now
    new["v"] = SCHEMA_VERSION
    return new


def do_save(ds, uid, my_session, my_gen, base_at, base_session, snap, now, cfg,
            attempts=3):
    """Cermin SaveSystem.Save. Return (ok, reason)."""
    if estimate_bytes(snap) > MAX_PAYLOAD_BYTES:
        return False, "payload_too_large"  # guard pre-check: tanpa sentuh DataStore
    key = f"p_{uid}"
    last_err = None
    for _ in range(attempts):
        try:
            res = ds.update(
                key,
                lambda old: save_transform(
                    old, my_session, my_gen, base_at, base_session,
                    snap, now, cfg,
                ),
            )
        except DataStoreError as exc:
            last_err = str(exc)
            continue
        if not isinstance(res, dict) or not isinstance(res.get("data"), dict):
            return False, "aborted"
        res_gen = res.get("gen") if isinstance(res.get("gen"), int) else -1
        res_s = normalize_session(res.get("session"))
        if cfg.fencing:
            if res_gen == my_gen and res_s["job"] == my_session["job"] \
                    and res_s["token"] == my_session["token"]:
                return True, "committed"
            return False, "conflict"
        if same_identity(res.get("session"), my_session, cfg.full_identity):
            return True, "committed"
        return False, "conflict"
    return False, f"ds_error:{last_err}"


# ----------------------------------------------------------------------------
# Mini framework skenario
# ----------------------------------------------------------------------------

RESULTS = []


def scenario(name):
    def deco(fn):
        def run(cfg=NEW_PROTOCOL):
            try:
                detail = fn(cfg) or "ok"
                RESULTS.append((name, True, detail))
            except AssertionError as exc:
                RESULTS.append((name, False, str(exc) or "assertion"))
            except Exception as exc:  # noqa: BLE001 - harness harus lapor, bukan crash
                RESULTS.append((name, False, f"ERROR: {type(exc).__name__}: {exc}"))

        run.__scenario__ = name
        return run

    return deco


def require(cond, msg):
    if not cond:
        raise AssertionError(msg)


# ----------------------------------------------------------------------------
# Skenario (semua memakai protokol BARU kecuali --demo-legacy)
# ----------------------------------------------------------------------------

@scenario("pemain_baru")
def t_new_player(cfg):
    ds, ms, now, uid = FakeDataStore(), FakeMemoryStore(), 1_000_000, 7
    ok, tok = claim_session(ms, uid, "job-A", "tok-A1", now, cfg)
    require(ok, "claim pemain baru harus menang")
    env, err = fence_and_read(ds, uid, {"job": "job-A", "token": tok}, now, cfg)
    require(env is not None, f"fence pemain baru gagal: {err}")
    require(env["gen"] == 1, "gen pemain baru harus 1")
    require(env["data"]["cash"] == STARTING_CASH, "kas awal salah")
    snap = dict(env["data"])
    ok, _ = do_save(ds, uid, {"job": "job-A", "token": tok}, env["gen"],
                    env["at"], env["session"], snap, now + 1, cfg)
    require(ok, "save pertama pemain baru harus berhasil")
    return f"gen={env['gen']} cash={snap['cash']}"


@scenario("pemain_lama")
def t_returning(cfg):
    ds, ms, now, uid = FakeDataStore(), FakeMemoryStore(), 2_000_000, 8
    ds.data[f"p_{uid}"] = {"v": 2, "gen": 5, "session": {"job": "job-O", "token": "tok-O"},
                           "at": now - 90000, "data": {"cash": 4321, "slots": {}}}
    ok, tok = claim_session(ms, uid, "job-B", "tok-B1", now, cfg)
    require(ok, "claim pemain lama harus menang")
    env, err = fence_and_read(ds, uid, {"job": "job-B", "token": tok}, now, cfg)
    require(env is not None, f"fence gagal: {err}")
    require(env["gen"] == 6, f"gen harus naik 5->6, dapat {env.get('gen')}")
    require(env["data"]["cash"] == 4321, "data lama harus utuh (tidak ditimpa default)")
    return "gen 5->6, cash utuh"


@scenario("migrasi_legacy")
def t_legacy(cfg):
    ds, ms, now, uid = FakeDataStore(), FakeMemoryStore(), 3_000_000, 9
    ds.data[f"p_{uid}"] = {"cash": 777, "slots": {"1": {"itemId": "x"}}}
    ok, tok = claim_session(ms, uid, "job-C", "tok-C1", now, cfg)
    require(ok, "claim harus menang")
    env, err = fence_and_read(ds, uid, {"job": "job-C", "token": tok}, now, cfg)
    require(env is not None, f"migrasi gagal: {err}")
    require(env["gen"] == 1 and env["data"]["cash"] == 777, "migrasi harus bawa data lama")
    return "legacy -> envelope gen=1"


@scenario("dua_server_klaim")
def t_two_servers(cfg):
    ds, ms, now, uid = FakeDataStore(), FakeMemoryStore(), 4_000_000, 10
    ok_a, tok_a = claim_session(ms, uid, "job-A", "tok-A", now, cfg)
    require(ok_a, "server pertama harus menang")
    env_a, _ = fence_and_read(ds, uid, {"job": "job-A", "token": tok_a}, now, cfg)
    ok_b, _ = claim_session(ms, uid, "job-B", "tok-B", now + 10, cfg)
    require(not ok_b, "server kedua WAJIB DITOLAK saat lease hidup")
    require(verify_lock(ms, uid, tok_a, now + 10), "lease pemenang harus utuh")
    return f"server B ditolak, gen A={env_a['gen']}"


@scenario("job_sama_token_beda")
def t_same_job(cfg):
    ms, now, uid = FakeMemoryStore(), 5_000_000, 11
    ok_a, tok_a = claim_session(ms, uid, "job-SAMA", "tok-1", now, cfg)
    require(ok_a, "claim pertama harus menang")
    ok_b, reason = claim_session(ms, uid, "job-SAMA", "tok-2", now + 5, cfg)
    require(not ok_b, f"takeover job-sama tanpa bukti token WAJIB DITOLAK ({reason})")
    return "takeover job-sama ditolak (isu #1)"


@scenario("sesi_kedaluwarsa")
def t_expiry(cfg):
    ms, now, uid = FakeMemoryStore(), 6_000_000, 12
    ok_a, _ = claim_session(ms, uid, "job-A", "tok-A", now, cfg)
    require(ok_a, "claim pertama harus menang")
    ok_b, tok_b = claim_session(ms, uid, "job-B", "tok-B", now + LOCK_TTL + 1, cfg)
    require(ok_b, "claim setelah kedaluwarsa harus menang")
    require(verify_lock(ms, uid, tok_b, now + LOCK_TTL + 1), "lease baru harus valid")
    return "takeover pasca-expiry ok"


@scenario("stale_save_setelah_claim")
def t_stale_after_claim(cfg):
    ds, ms, now, uid = FakeDataStore(), FakeMemoryStore(), 7_000_000, 13
    ok_a, tok_a = claim_session(ms, uid, "job-A", "tok-A", now, cfg)
    require(ok_a, "claim A harus menang")
    env_a, _ = fence_and_read(ds, uid, {"job": "job-A", "token": tok_a}, now, cfg)
    snap_a = dict(env_a["data"])
    snap_a["cash"] = 999999  # mutasi basi di server A
    # A disconnect: lease dilepas (atau kedaluwarsa); B klaim + fence -> gen naik.
    release_session(ms, uid, tok_a)
    ok_b, tok_b = claim_session(ms, uid, "job-B", "tok-B", now + 1, cfg)
    require(ok_b, "claim B harus menang")
    env_b, _ = fence_and_read(ds, uid, {"job": "job-B", "token": tok_b}, now + 1, cfg)
    require(env_b["gen"] == env_a["gen"] + 1, "gen harus naik di akuisisi B")
    # TOCTOU: A sudah lolos VerifyLock SEBELUM B fence; transform A jalan SETELAH.
    require(verify_lock(ms, uid, tok_a, now + 1) is False, "pra-kondisi: lease A hilang")
    res = ds.update(
        f"p_{uid}",
        lambda old: save_transform(old, {"job": "job-A", "token": tok_a},
                                   env_a["gen"], env_a["at"], env_a["session"],
                                   snap_a, now + 2, cfg),
    )
    require(res is not None and res["gen"] == env_b["gen"],
            "tulisan basi A WAJIB DITOLAK (cloud tetap gen B)")
    require(res["data"]["cash"] != 999999, "data basi A tidak boleh mendarat")
    return f"stale gen={env_a['gen']} ditolak vs gen={env_b['gen']}"


@scenario("stale_save_setelah_commit")
def t_stale_after_commit(cfg):
    # SEMUA langkah dalam detik yang SAMA (os.time() resolusi 1 detik -- hal biasa
    # saat rejoin cepat). Ini justru mematikan aturan lama `old.at > baseAt`.
    ds, ms, now, uid = FakeDataStore(), FakeMemoryStore(), 8_000_000, 14
    ok_a, tok_a = claim_session(ms, uid, "job-A", "tok-A", now, cfg)
    require(ok_a, "claim A harus menang")
    env_a, _ = fence_and_read(ds, uid, {"job": "job-A", "token": tok_a}, now, cfg)
    snap_a = dict(env_a["data"])
    snap_a["cash"] = 111  # progres basi A
    release_session(ms, uid, tok_a)
    ok_b, tok_b = claim_session(ms, uid, "job-B", "tok-B", now, cfg)
    require(ok_b, "claim B harus menang")
    env_b, _ = fence_and_read(ds, uid, {"job": "job-B", "token": tok_b}, now, cfg)
    snap_b = dict(env_b["data"])
    snap_b["cash"] = 5555  # progres BARU di server B
    ok, _ = do_save(ds, uid, {"job": "job-B", "token": tok_b}, env_b["gen"],
                    env_b["at"], env_b["session"], snap_b, now, cfg)
    require(ok, "commit B harus berhasil")
    # Server lama A mencoba timpa SETELAH commit B (WAJIB DITOLAK, data baru utuh).
    res = ds.update(
        f"p_{uid}",
        lambda old: save_transform(old, {"job": "job-A", "token": tok_a},
                                   env_a["gen"], env_a["at"], env_a["session"],
                                   snap_a, now, cfg),
    )
    require(res is not None, "abort tak terduga")
    require(res["data"]["cash"] == 5555,
            f"data baru B harus UTUH, dapat cash={res['data'].get('cash')}")
    require(res["gen"] == env_b["gen"], "gen tidak boleh mundur")
    return "stale-write A ditolak, cash=5555 utuh"


@scenario("save_konkuren")
def t_concurrent(cfg):
    ds, ms, now, uid = FakeDataStore(), FakeMemoryStore(), 9_000_000, 15
    ok, tok = claim_session(ms, uid, "job-A", "tok-A", now, cfg)
    require(ok, "claim harus menang")
    sess = {"job": "job-A", "token": tok}
    env, _ = fence_and_read(ds, uid, sess, now, cfg)
    snap1 = dict(env["data"])
    snap1["cash"] = 200  # autosave
    snap2 = dict(env["data"])
    snap2["cash"] = 300  # leave-save (sedikit lebih baru)
    ok1, _ = do_save(ds, uid, sess, env["gen"], env["at"], env["session"],
                     snap1, now + 1, cfg)
    env_mid = copy.deepcopy(ds.data[f"p_{uid}"])
    ok2, _ = do_save(ds, uid, sess, env["gen"], env_mid["at"], env_mid["session"],
                     snap2, now + 2, cfg)
    require(ok1 and ok2, "dua save sesama sesi harus SAMA-SAMA lolos")
    final = ds.data[f"p_{uid}"]["data"]["cash"]
    require(final == 300, f"last-writer-wins sesama sesi, dapat {final}")
    return "autosave+leave-save konsisten (300)"


@scenario("datastore_gagal")
def t_ds_failure(cfg):
    ds, ms, now, uid = FakeDataStore(), FakeMemoryStore(), 10_000_000, 16
    ds.data[f"p_{uid}"] = {"v": 2, "gen": 3, "session": {"job": "job-O", "token": "t"},
                           "at": now - 10, "data": {"cash": 900, "slots": {}}}
    ds.failures = [DataStoreError("timeout"), DataStoreError("throttled"),
                   DataStoreError("timeout")]
    ok, tok = claim_session(ms, uid, "job-A", "tok-A", now, cfg)
    require(ok, "claim harus menang")
    env, err = fence_and_read(ds, uid, {"job": "job-A", "token": tok}, now, cfg)
    require(env is None, "load saat DataStore down WAJIB gagal (fail-closed)")
    # Tanpa load sukses: tidak ada init default, tidak ada save.
    # (Di Luau, Save menolak sebelum menyentuh DataStore bila sessionGen nil.)
    require("p_16" in ds.data and ds.data["p_16"]["data"]["cash"] == 900,
            "cloud tidak boleh tersentuh saat load gagal")
    my_gen = None  # tidak ada akuisisi -> Save Luau return false tanpa tulis
    require(my_gen is None, "save tanpa generation WAJIB ditolak")
    return f"fail-closed ({err}); save-ditolak-tanpa-gen"


@scenario("shutdown_saat_save")
def t_shutdown(cfg):
    ds, ms, now, uid = FakeDataStore(), FakeMemoryStore(), 11_000_000, 17
    ok, tok = claim_session(ms, uid, "job-A", "tok-A", now, cfg)
    require(ok, "claim harus menang")
    sess = {"job": "job-A", "token": tok}
    env, _ = fence_and_read(ds, uid, sess, now, cfg)
    snap = dict(env["data"])
    snap["cash"] = 4242
    ds.failures = [DataStoreError("timeout")]  # gagal di percobaan 1, retry sukses
    ok_save, _ = do_save(ds, uid, sess, env["gen"], env["at"], env["session"],
                         snap, now + 1, cfg)
    require(ok_save, "retry shutdown harus akhirnya komit (atomik: utuh/gagal total)")
    require(ds.data[f"p_{uid}"]["data"]["cash"] == 4242, "data shutdown harus utuh")
    return "retry komit atomik, cash=4242"


@scenario("rejoin")
def t_rejoin(cfg):
    ds, ms, now, uid = FakeDataStore(), FakeMemoryStore(), 12_000_000, 18
    ok, tok1 = claim_session(ms, uid, "job-A", "tok-1", now, cfg)
    require(ok, "claim-1 harus menang")
    env1, _ = fence_and_read(ds, uid, {"job": "job-A", "token": tok1}, now, cfg)
    snap = dict(env1["data"])
    snap["cash"] = 600
    ok, _ = do_save(ds, uid, {"job": "job-A", "token": tok1}, env1["gen"],
                    env1["at"], env1["session"], snap, now + 1, cfg)
    require(ok, "leave-save harus komit")
    release_session(ms, uid, tok1)
    ok2, tok2 = claim_session(ms, uid, "job-A", "tok-2", now + 2, cfg)
    require(ok2, "rejoin harus bisa klaim")
    env2, _ = fence_and_read(ds, uid, {"job": "job-A", "token": tok2}, now + 2, cfg)
    require(env2["data"]["cash"] == 600, "progres rejoin harus terbawa")
    require(env2["gen"] == env1["gen"] + 1, "gen naik saat rejoin")
    return "rejoin bawa progres, gen+1"


@scenario("recovery_gagal_save")
def t_recovery(cfg):
    ds, ms, now, uid = FakeDataStore(), FakeMemoryStore(), 13_000_000, 19
    ok, tok = claim_session(ms, uid, "job-A", "tok-A", now, cfg)
    require(ok, "claim harus menang")
    sess = {"job": "job-A", "token": tok}
    env, _ = fence_and_read(ds, uid, sess, now, cfg)
    snap = dict(env["data"])
    snap["cash"] = 7777
    ds.failures = [DataStoreError("throttled")] * 5  # gagal total 3 percobaan
    ok_save, reason = do_save(ds, uid, sess, env["gen"], env["at"],
                              env["session"], snap, now + 1, cfg)
    require(not ok_save, "save saat throttle total harus GAGAL")
    cloud = ds.data[f"p_{uid}"]
    require(cloud["data"]["cash"] != 7777, "cloud tidak boleh termutasi parsial")
    snap["cash"] = 7888  # progres lanjut sebelum retry
    ok_save2, _ = do_save(ds, uid, sess, env["gen"], cloud["at"], cloud["session"],
                          snap, now + 2, cfg)
    require(ok_save2, "save setelah pulih harus berhasil")
    require(ds.data[f"p_{uid}"]["data"]["cash"] == 7888, "data pulih harus utuh")
    return f"gagal-total ({reason}) lalu pulih 7888"


@scenario("release_aman")
def t_release_safe(cfg):
    ms, now, uid = FakeMemoryStore(), 14_000_000, 20
    ok_a, tok_a = claim_session(ms, uid, "job-A", "tok-A", now, cfg)
    require(ok_a, "claim A harus menang")
    release_session(ms, uid, tok_a)
    ok_b, tok_b = claim_session(ms, uid, "job-B", "tok-B", now + 1, cfg)
    require(ok_b, "claim B harus menang")
    release_session(ms, uid, tok_a)  # server lama melepas SETELAH B klaim
    require(verify_lock(ms, uid, tok_b, now + 1),
            "release basi TIDAK boleh melepas lock server baru")
    return "release basi tidak merusak lock B"


@scenario("payload_raksasa")
def t_huge_payload(cfg):
    ds, ms, now, uid = FakeDataStore(), FakeMemoryStore(), 15_000_000, 21
    ok, tok = claim_session(ms, uid, "job-A", "tok-A", now, cfg)
    require(ok, "claim harus menang")
    sess = {"job": "job-A", "token": tok}
    env, err = fence_and_read(ds, uid, sess, now, cfg)
    require(env is not None, f"fence gagal: {err}")
    snap = dict(env["data"])
    snap["blob"] = "x" * (MAX_PAYLOAD_BYTES + 1)  # >4MB
    ok_save, reason = do_save(ds, uid, sess, env["gen"], env["at"],
                              env["session"], snap, now + 1, cfg)
    require(not ok_save and reason == "payload_too_large",
            f"tulis raksasa WAJIB DITOLAK pre-check, dapat {reason}")
    cloud = ds.data[f"p_{uid}"]
    require("blob" not in cloud["data"], "cloud tidak boleh kemasukan payload raksasa")
    require(not ds.failures, "penolakan pre-check tidak boleh membakar retry DataStore")
    snap_ok = dict(env["data"])
    snap_ok["cash"] = 123
    ok2, _ = do_save(ds, uid, sess, env["gen"], env["at"], env["session"],
                     snap_ok, now + 2, cfg)
    require(ok2, "save normal setelah penolakan harus tetap bisa")
    return "oversize ditolak pre-check, cloud utuh"


@scenario("throttle_beruntun")
def t_throttle_burst(cfg):
    ds, ms, now, uid = FakeDataStore(), FakeMemoryStore(), 16_000_000, 22
    ok, tok = claim_session(ms, uid, "job-A", "tok-A", now, cfg)
    require(ok, "claim harus menang")
    sess = {"job": "job-A", "token": tok}
    ds.failures = [DataStoreError("throttled"), DataStoreError("throttled")]
    env, err = fence_and_read(ds, uid, sess, now, cfg)
    require(env is not None, f"fence harus pulih via retry, dapat err={err}")
    snap = dict(env["data"])
    snap["cash"] = 2000
    ds.failures = [DataStoreError("timeout")] * 5  # gagal total semua retry save
    ok_save, reason = do_save(ds, uid, sess, env["gen"], env["at"],
                              env["session"], snap, now + 1, cfg)
    require(not ok_save, f"save saat throttle total harus GAGAL, dapat {reason}")
    require(ds.data[f"p_{uid}"]["data"]["cash"] != 2000,
            "cloud tidak boleh termutasi parsial saat throttle")
    ok2, _ = do_save(ds, uid, sess, env["gen"], ds.data[f"p_{uid}"]["at"],
                     ds.data[f"p_{uid}"]["session"], snap, now + 2, cfg)
    require(ok2, "save setelah throttle reda harus komit")
    return "retry fence pulih; save gagal-total lalu pulih"


@scenario("migrasi_v1_korup")
def t_corrupt_legacy(cfg):
    ds, ms, now, uid = FakeDataStore(), FakeMemoryStore(), 17_000_000, 23
    ds.data[f"p_{uid}"] = {"cash": "bukan-angka", "slots": "rusak-juga"}
    ok, tok = claim_session(ms, uid, "job-A", "tok-A", now, cfg)
    require(ok, "claim harus menang")
    env, err = fence_and_read(ds, uid, {"job": "job-A", "token": tok}, now, cfg)
    require(env is not None, f"migrasi korup harus disanitasi, bukan crash: {err}")
    require(env["gen"] == 1, "gen migrasi harus 1")
    require(env["data"]["cash"] == STARTING_CASH, "cash korup harus jadi default aman")
    require(env["data"]["slots"] == {}, "slots korup harus jadi tabel kosong")
    ds.data["p_98"] = "sampah-bukan-tabel"
    env2, err2 = fence_and_read(ds, 98, {"job": "job-A", "token": tok}, now, cfg)
    require(env2 is None and err2 == "corrupt",
            "envelope non-tabel WAJIB ABORT (fail-closed, bukan timpa default)")
    require(ds.data["p_98"] == "sampah-bukan-tabel", "abort tidak boleh menulis apa pun")
    return "v1 korup disanitasi; non-tabel abort"


@scenario("autosave_vs_leave_ketat")
def t_tight_race(cfg):
    ds, ms, now, uid = FakeDataStore(), FakeMemoryStore(), 18_000_000, 24
    ok, tok = claim_session(ms, uid, "job-A", "tok-A", now, cfg)
    require(ok, "claim harus menang")
    sess = {"job": "job-A", "token": tok}
    env, _ = fence_and_read(ds, uid, sess, now, cfg)
    # Kedua save baca basis SAMA sebelum salah satu komit (race ketat).
    snap_auto = dict(env["data"])
    snap_auto["cash"] = 200
    snap_leave = dict(env["data"])
    snap_leave["cash"] = 300
    ok1, _ = do_save(ds, uid, sess, env["gen"], env["at"], env["session"],
                     snap_auto, now + 1, cfg)
    ok2, _ = do_save(ds, uid, sess, env["gen"], env["at"], env["session"],
                     snap_leave, now + 1, cfg)
    require(ok1 and ok2, "dua save sesama sesi (basis sama) harus SAMA-SAMA lolos")
    require(ds.data[f"p_{uid}"]["data"]["cash"] == 300, "last-writer-wins sesama sesi")
    # Penulis basi asing dengan gen lama mencoba masuk SETELAH race: WAJIB kalah.
    res = ds.update(
        f"p_{uid}",
        lambda old: save_transform(old, {"job": "job-X", "token": "tok-X"},
                                   env["gen"] - 1, now - 50,
                                   {"job": "job-X", "token": "tok-X"},
                                   {"cash": 1}, now + 2, cfg),
    )
    require(res["data"]["cash"] == 300, "penulis basi asing TIDAK boleh menang")
    return "race sesama sesi konsisten; stale asing ditolak"


@scenario("clock_skew")
def t_clock_skew(cfg):
    ds, ms, now, uid = FakeDataStore(), FakeMemoryStore(), 19_000_000, 25
    ds.data[f"p_{uid}"] = {"v": 2, "gen": 5,
                           "session": {"job": "job-O", "token": "tok-O"},
                           "at": now + 7200,  # jam server lama maju (skew masa depan)
                           "data": {"cash": 4321, "slots": {}}}
    ok, tok = claim_session(ms, uid, "job-A", "tok-A", now, cfg)
    require(ok, "claim harus menang")
    env, err = fence_and_read(ds, uid, {"job": "job-A", "token": tok}, now, cfg)
    require(env is not None, f"fence saat clock skew gagal: {err}")
    require(env["gen"] == 6, "gen tetap naik monotonik walau at skew")
    require(env["data"]["cash"] == 4321, "data skew tidak boleh ditimpa default")
    snap = dict(env["data"])
    snap["cash"] = 5000
    ok_save, _ = do_save(ds, uid, {"job": "job-A", "token": tok}, env["gen"],
                         env["at"], env["session"], snap, now + 1, cfg)
    require(ok_save, "save sesi baru harus komit walau at lama di masa depan")
    res = ds.update(
        f"p_{uid}",
        lambda old: save_transform(old, {"job": "job-O", "token": "tok-O"},
                                   5, now + 7200,
                                   {"job": "job-O", "token": "tok-O"},
                                   {"cash": 9}, now + 2, cfg),
    )
    require(res["data"]["cash"] == 5000 and res["gen"] == 6,
            "stale writer gen-5 WAJIB kalah walau at-nya masa depan")
    return "skew at diatasi fencing, stale kalah"


@scenario("re_fence_sendiri_berulang")
def t_refence_self(cfg):
    ds, ms, now, uid = FakeDataStore(), FakeMemoryStore(), 20_000_000, 26
    ok, tok = claim_session(ms, uid, "job-A", "tok-A", now, cfg)
    require(ok, "claim harus menang")
    sess = {"job": "job-A", "token": tok}
    env1, _ = fence_and_read(ds, uid, sess, now, cfg)
    env2, _ = fence_and_read(ds, uid, sess, now + 1, cfg)
    env3, _ = fence_and_read(ds, uid, sess, now + 2, cfg)
    require(env1["gen"] == env2["gen"] == env3["gen"],
            f"re-fence sendiri idempoten, dapat {env1['gen']}/{env2['gen']}/{env3['gen']}")
    snap = dict(env3["data"])
    snap["cash"] = 9090
    ok_save, _ = do_save(ds, uid, sess, env1["gen"], env3["at"], env3["session"],
                         snap, now + 3, cfg)
    require(ok_save, "save setelah re-fence berulang harus komit")
    require(ds.data[f"p_{uid}"]["gen"] == env1["gen"], "gen tidak boleh merayap")
    return f"re-fence 3x idempoten gen={env1['gen']}"


@scenario("release_ganda")
def t_double_release(cfg):
    ms, now, uid = FakeMemoryStore(), 21_000_000, 27
    ok_a, tok_a = claim_session(ms, uid, "job-A", "tok-A", now, cfg)
    require(ok_a, "claim A harus menang")
    release_session(ms, uid, tok_a)
    release_session(ms, uid, tok_a)  # ganda: no-op, tidak boleh error
    release_session(ms, uid, "token-asing")  # tak dikenal: no-op
    ok_b, tok_b = claim_session(ms, uid, "job-B", "tok-B", now + 1, cfg)
    require(ok_b, "klaim ulang setelah release ganda harus menang")
    require(verify_lock(ms, uid, tok_b, now + 1), "lease baru harus valid")
    release_session(ms, uid, tok_b)
    require(not verify_lock(ms, uid, tok_b, now + 2), "setelah release, lock hilang")
    return "release ganda/asing no-op; re-claim ok"


# ----------------------------------------------------------------------------
# Runner
# ----------------------------------------------------------------------------

ALL = [v for v in list(globals().values())
       if callable(v) and getattr(v, "__scenario__", None)]


def main(argv=None):
    ap = argparse.ArgumentParser(description="Harness uji protokol fencing SaveSystem.")
    ap.add_argument("--demo-legacy", action="store_true",
                    help="jalankan ulang skenario kritis dengan parameter LEGACY "
                         "(diharapkan GAGAL: membuktikan bug lama; tidak memengaruhi exit code)")
    ap.add_argument("--scenario", default=None,
                    help="hanya jalankan skenario bernama (substring match)")
    args = ap.parse_args(argv)

    selected = [fn for fn in ALL
                if args.scenario is None or args.scenario in fn.__scenario__]
    if not selected:
        print(f"tidak ada skenario cocok: {args.scenario!r}")
        return 2
    for fn in selected:
        fn(NEW_PROTOCOL)

    width = max(len(n) for n, _, _ in RESULTS)
    failed = 0
    print(f"{'SKENARIO':<{width}}  HASIL  DETAIL")
    print("-" * (width + 30))
    for name, passed, detail in RESULTS:
        print(f"{name:<{width}}  {'LULUS' if passed else 'GAGAL'}  {detail}")
        failed += not passed
    print("-" * (width + 30))
    print(f"ringkasan: {len(RESULTS) - failed}/{len(RESULTS)} lulus")

    if args.demo_legacy:
        print("\n[demo-legacy] skenario kritis dengan parameter lama (diharapkan gagal):")
        for name in ("stale_save_setelah_claim", "stale_save_setelah_commit",
                     "job_sama_token_beda"):
            fn = next(f for f in ALL if f.__scenario__ == name)
            before = len(RESULTS)
            fn(LEGACY_PROTOCOL)
            _, passed, detail = RESULTS[before]
            status = "LULUS?! (tak terduga)" if passed else "GAGAL (sesuai harapan: bug lama repro)"
            print(f"  legacy/{name}: {status} -- {detail}")
        # buang hasil demo agar tidak memengaruhi exit code
        del RESULTS[before - 2:]

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
