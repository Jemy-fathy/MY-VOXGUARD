"""
VoxGuard — Voice Biometric API (Fast & Lean)
=============================================
POST /enroll          3 WAV → embedding (حفظ في SQLite)
POST /verify          WAV + embedding JSON → match (stateless)
POST /verify_user_id  WAV + user_id → match
GET  /users           قائمة المستخدمين
GET  /embedding/{id}  جلب البصمة للحفظ في MySQL
DELETE /users/{id}    حذف مستخدم
GET  /health          حالة النظام

تشغيل:
  python voxguard_biometric_api.py
  ngrok http 9000
"""

import io, os, json, time, wave, sqlite3, logging, threading
from pathlib import Path
from typing import Optional
from concurrent.futures import ThreadPoolExecutor

import numpy as np
import torch
import torch.nn.functional as F
import uvicorn
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s", datefmt="%H:%M:%S")
log = logging.getLogger("VG")

# ── Config ─────────────────────────────────────────────────────────────────────
SR        = 16_000
THRESHOLD = float(os.environ.get("VG_THRESHOLD", "0.55"))
PORT      = int(os.environ.get("PORT", "9000"))
WAVLM_DIR = os.environ.get("WAVLM_PATH", "wavlm_model")
DB_PATH   = os.environ.get("VG_DB_PATH", "voxguard_users.db")
_pool     = ThreadPoolExecutor(max_workers=4)

# ── SQLite ──────────────────────────────────────────────────────────────────────
_DB: dict = {}
_lock = threading.Lock()

def _db_init():
    c = sqlite3.connect(DB_PATH)
    c.execute("""CREATE TABLE IF NOT EXISTS users(
        user_id TEXT PRIMARY KEY, name TEXT,
        embedding TEXT NOT NULL, enrolled_at TEXT NOT NULL, dim INTEGER)""")
    c.commit()
    for uid, name, emb, ts, dim in c.execute(
            "SELECT user_id,name,embedding,enrolled_at,dim FROM users").fetchall():
        if not emb or not emb.strip():
            continue
        try:
            _DB[uid] = {"embedding": json.loads(emb), "name": name,
                        "enrolled_at": ts, "dim": dim}
        except Exception:
            continue
    c.close()
    log.info(f"DB ready — {len(_DB)} user(s)")

def _db_save(uid: str, info: dict):
    with _lock:
        c = sqlite3.connect(DB_PATH)
        c.execute("INSERT OR REPLACE INTO users VALUES(?,?,?,?,?)",
                  (uid, info["name"], json.dumps(info["embedding"]),
                   info["enrolled_at"], info["dim"]))
        c.commit(); c.close()

def _db_del(uid: str):
    with _lock:
        c = sqlite3.connect(DB_PATH)
        c.execute("DELETE FROM users WHERE user_id=?", (uid,))
        c.commit(); c.close()

_db_init()

# ── Audio Loading ───────────────────────────────────────────────────────────────
def _wav_parse(raw: bytes) -> Optional[np.ndarray]:
    try:
        with wave.open(io.BytesIO(raw), "rb") as wf:
            ch, sw, sr = wf.getnchannels(), wf.getsampwidth(), wf.getframerate()
            frames = wf.readframes(wf.getnframes())
        if sw == 2:
            w = np.frombuffer(frames, np.int16).astype(np.float32) / 32768.0
        elif sw == 4:
            w = np.frombuffer(frames, np.int32).astype(np.float32) / 2147483648.0
        elif sw == 1:
            w = (np.frombuffer(frames, np.uint8).astype(np.float32) - 128) / 128.0
        elif sw == 3:
            b = np.frombuffer(frames, np.uint8).reshape(-1, 3)
            i = b[:,0].astype(np.int32) | (b[:,1].astype(np.int32)<<8) | (b[:,2].astype(np.int32)<<16)
            i[i >= (1<<23)] -= (1<<24)
            w = i.astype(np.float32) / 8388608.0
        else:
            return None
        if ch > 1: w = w.reshape(-1, ch).mean(1)
        if sr != SR: w = _resample(w, sr, SR)
        return w.astype(np.float32)
    except Exception:
        return None

def _librosa_parse(raw: bytes) -> Optional[np.ndarray]:
    try:
        import librosa
        w, _ = librosa.load(io.BytesIO(raw), sr=SR, mono=True)
        return w.astype(np.float32)
    except Exception:
        return None

def _resample(w: np.ndarray, sr_in: int, sr_out: int) -> np.ndarray:
    try:
        from scipy.signal import resample_poly
        from math import gcd
        g = gcd(sr_in, sr_out)
        return resample_poly(w, sr_out//g, sr_in//g).astype(np.float32)
    except Exception:
        n = int(round(len(w) * sr_out / sr_in))
        return np.interp(np.linspace(0,1,n), np.linspace(0,1,len(w)), w).astype(np.float32)

def load_wav(raw: bytes) -> np.ndarray:
    log.info(f"قراءة ملف صوتي بحجم: {len(raw)} bytes")
    if len(raw) < 100:
        raise ValueError(f"ملف الصوت صغير جداً أو فارغ ({len(raw)} bytes)")
    
    w = _wav_parse(raw)
    if w is None:
        log.warning("فشل _wav_parse، محاولة استخدام librosa...")
        w = _librosa_parse(raw)
    
    if w is None or len(w) == 0:
        # محاولة أخيرة باستخدام pydub أو أي طريقة أخرى لو فشل librosa
        raise ValueError("لا يمكن قراءة الصوت — تأكد إنه WAV حقيقي وغير تالف")
    
    log.info(f"تمت قراءة الصوت بنجاح: {len(w)} عينة")
    return w

# ── Cosine Similarity ───────────────────────────────────────────────────────────
def cosine(a: np.ndarray, b: np.ndarray) -> float:
    na, nb = np.linalg.norm(a), np.linalg.norm(b)
    return float(np.dot(a, b) / (na * nb + 1e-8))

# ── WavLM Loading ───────────────────────────────────────────────────────────────
_model = _fe = None
_ok = False
_err = ""

def _load() -> bool:
    global _model, _fe, _err
    try:
        from transformers import WavLMForXVector, Wav2Vec2FeatureExtractor
    except ImportError as e:
        _err = str(e); return False

    for p in [WAVLM_DIR, "./wavlm_model", os.path.expanduser("~/wavlm_model")]:
        if p and Path(p).exists():
            try:
                _fe    = Wav2Vec2FeatureExtractor.from_pretrained(p, local_files_only=True)
                _model = WavLMForXVector.from_pretrained(p, local_files_only=True).eval()
                log.info(f"WavLM محمّل من: {p}")
                return True
            except Exception:
                pass

    try:
        log.info("تحميل WavLM من HuggingFace (~400MB)...")
        _fe    = Wav2Vec2FeatureExtractor.from_pretrained(
            "microsoft/wavlm-base-plus-sv", cache_dir="./wavlm_model")
        _model = WavLMForXVector.from_pretrained(
            "microsoft/wavlm-base-plus-sv", cache_dir="./wavlm_model").eval()
        return True
    except Exception as e:
        _err = str(e); return False

def embed(wav: np.ndarray) -> np.ndarray:
    if not _ok:
        raise RuntimeError("WavLM غير محمّل")
    wav = wav[:SR * 6]
    with torch.no_grad():
        inp = _fe(wav, sampling_rate=SR, return_tensors="pt", padding=True)
        e   = _model(**inp).embeddings.squeeze().cpu().numpy().astype(np.float32)
    n = np.linalg.norm(e)
    return e / n if n > 1e-8 else e

log.info("تحميل WavLM...")
_ok = _load()
log.info(f"WavLM: {'✓' if _ok else '✗ ' + _err}")

# ── FastAPI ─────────────────────────────────────────────────────────────────────
app = FastAPI(
    title       = "VoxGuard Voice Biometric API",
    description = """
## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| POST | /enroll | 3 WAV → embedding (حفظ في SQLite) |
| POST | /verify | WAV + embedding JSON → match (stateless) |
| POST | /verify_user_id | WAV + user_id → match |
| GET  | /users | قائمة المستخدمين |
| GET  | /embedding/{id} | جلب البصمة للحفظ في MySQL |
| DELETE | /users/{id} | حذف مستخدم |

## التكامل مع Laravel
```php
// Enroll
Http::attach('audio_1', file_get_contents($wav1), 'a1.wav')
    ->attach('audio_2', file_get_contents($wav2), 'a2.wav')
    ->attach('audio_3', file_get_contents($wav3), 'a3.wav')
    ->post(env('AI_URL').'/enroll', ['user_id' => (string)auth()->id()]);

// Verify by user_id
Http::attach('audio', file_get_contents($wav), 'v.wav')
    ->post(env('AI_URL').'/verify_user_id', [
        'user_id'   => (string)auth()->id(),
        'threshold' => '0.72',
    ]);

// Verify stateless (embedding من MySQL)
Http::attach('audio', file_get_contents($wav), 'v.wav')
    ->post(env('AI_URL').'/verify', [
        'embedding' => $user->voice_embedding,
        'threshold' => '0.72',
    ]);
```
""",
    version = "2.0",
    docs_url="/docs", redoc_url="/redoc",
)

app.add_middleware(CORSMiddleware, allow_origins=["*"],
                   allow_methods=["*"], allow_headers=["*"])

# ── API Key Guard ───────────────────────────────────────────────────────────────
_KEYS = {k.strip() for k in os.environ.get("VG_API_KEYS","").split(",") if k.strip()}
_PUBLIC = {"/","/health","/docs","/redoc","/openapi.json"}

@app.middleware("http")
async def _key_guard(req, call_next):
    if not _KEYS or req.url.path in _PUBLIC or req.method == "OPTIONS":
        return await call_next(req)
    if req.headers.get("x-api-key") not in _KEYS:
        return JSONResponse({"error": "invalid api key"}, status_code=401)
    return await call_next(req)

if _KEYS: log.info(f"API key auth: {len(_KEYS)} key(s)")
else:     log.warning("API key auth DISABLED — set VG_API_KEYS to enable")

# ── /enroll ─────────────────────────────────────────────────────────────────────
@app.post("/enroll", tags=["Biometric"],
          summary="تسجيل بصمة صوتية — 3 عينات WAV → embedding")
async def enroll(
    user_id:   str        = Form(..., description="معرف المستخدم (any string)"),
    user_name: str        = Form("",  description="اسم للعرض (اختياري)"),
    audio_1:   UploadFile = File(..., description="WAV عينة 1"),
    audio_2:   UploadFile = File(..., description="WAV عينة 2"),
    audio_3:   UploadFile = File(..., description="WAV عينة 3"),
):
    if not _ok:
        raise HTTPException(503, f"WavLM غير محمّل: {_err}")
    t0 = time.time()

    raws = await asyncio.gather(audio_1.read(), audio_2.read(), audio_3.read())

    loop = asyncio.get_event_loop()
    def _process(raw: bytes, idx: int) -> np.ndarray:
        wav = load_wav(raw)
        dur = len(wav) / SR
        rms = float(np.sqrt(np.mean(wav**2)))
        if dur < 0.8:
            raise ValueError(f"عينة {idx}: قصيرة جداً ({dur:.1f}s)")
        if rms < 0.005:
            raise ValueError(f"عينة {idx}: صامتة (RMS={rms:.4f})")
        return embed(wav)

    try:
        futs = [loop.run_in_executor(_pool, _process, raw, i+1) for i,raw in enumerate(raws)]
        embs = await asyncio.gather(*futs)
    except ValueError as e:
        raise HTTPException(400, str(e))

    mean = np.mean(embs, axis=0)
    mean = mean / (np.linalg.norm(mean) + 1e-8)

    _DB[user_id] = {
        "embedding":   mean.tolist(),
        "name":        user_name or user_id,
        "enrolled_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "dim":         512,
    }
    loop.run_in_executor(_pool, _db_save, user_id, _DB[user_id])

    ms = int((time.time() - t0) * 1000)
    log.info(f"ENROLL {user_id} {ms}ms")
    return {
        "ok":          True,
        "user_id":     user_id,
        "name":        _DB[user_id]["name"],
        "dim":         512,
        "ms":          ms,
        "enrolled_at": _DB[user_id]["enrolled_at"],
        "embedding":   mean.tolist(),
    }

# ── /verify ─────────────────────────────────────────────────────────────────────
@app.post("/verify", tags=["Biometric"],
          summary="تحقق stateless — WAV + embedding JSON")
async def verify(
    audio:     UploadFile = File(...,  description="WAV segment"),
    embedding: str        = Form(...,  description='JSON array [0.01, -0.03, ...] (512 float)'),
    threshold: float      = Form(THRESHOLD),
    user_id:   str        = Form("",   description="للـ logging فقط"),
):
    if not _ok:
        raise HTTPException(503, "WavLM غير محمّل")
    try:
        stored = np.array(json.loads(embedding), np.float32)
        if stored.size < 64:
            raise ValueError("embedding صغير جداً")
    except Exception as e:
        raise HTTPException(400, f"embedding غير صالح: {e}")
    t0  = time.time()
    raw = await audio.read()
    wav = load_wav(raw)
    new = embed(wav)
    score = cosine(new, stored)
    match = bool(score >= threshold)
    ms    = int((time.time() - t0) * 1000)
    log.info(f"VERIFY user={user_id or '-'} {score:.4f} match={match} {ms}ms")
    return {
        "ok":          True,
        "match":       match,
        "score":       round(score, 4),
        "score_pct":   f"{round(score*100,1)}%",
        "threshold":   threshold,
        "user_id":     user_id,
        "ms":          ms,
        "sos_trigger": match,
    }

# ── /verify_user_id ─────────────────────────────────────────────────────────────
@app.post("/verify_user_id", tags=["Biometric"],
          summary="تحقق بالـ user_id — WAV + user_id → match")
async def verify_user_id(
    user_id:   str        = Form(..., description="معرف المستخدم"),
    audio:     UploadFile = File(..., description="WAV segment"),
    threshold: float      = Form(THRESHOLD, description="عتبة التشابه"),
):
    if not _ok:
        raise HTTPException(503, "WavLM غير محمّل")
    if user_id not in _DB:
        raise HTTPException(404, f"'{user_id}' غير مسجّل — استدعِ /enroll أولاً")
    t0  = time.time()
    raw = await audio.read()
    wav = load_wav(raw)
    new = embed(wav)
    stored = np.array(_DB[user_id]["embedding"], np.float32)
    score  = cosine(new, stored)
    match  = bool(score >= threshold)
    ms     = int((time.time() - t0) * 1000)
    log.info(f"VERIFY_USER_ID {user_id} {score:.4f} match={match} {ms}ms")
    return {
        "ok":          True,
        "match":       match,
        "score":       round(score, 4),
        "score_pct":   f"{round(score*100,1)}%",
        "threshold":   threshold,
        "user_id":     user_id,
        "name":        _DB[user_id]["name"],
        "ms":          ms,
        "sos_trigger": match,
    }

# ── /users ──────────────────────────────────────────────────────────────────────
@app.get("/users", tags=["Users"], summary="قائمة المستخدمين")
async def list_users():
    return {"ok": True, "count": len(_DB),
            "users": [{"user_id":k,"name":v["name"],
                        "enrolled_at":v["enrolled_at"],"dim":v["dim"]}
                       for k,v in _DB.items()]}

@app.get("/embedding/{user_id}", tags=["Users"],
         summary="جلب البصمة الخام للحفظ في MySQL")
async def get_embedding(user_id: str):
    if user_id not in _DB:
        raise HTTPException(404, f"'{user_id}' غير موجود")
    v = _DB[user_id]
    return {"ok":True,"user_id":user_id,"name":v["name"],
            "embedding":v["embedding"],"dim":v["dim"],"enrolled_at":v["enrolled_at"]}

@app.delete("/users/{user_id}", tags=["Users"], summary="حذف مستخدم")
async def delete_user(user_id: str):
    if user_id not in _DB:
        raise HTTPException(404, f"'{user_id}' غير موجود")
    del _DB[user_id]
    _pool.submit(_db_del, user_id)
    return {"ok": True, "deleted": user_id}

# ── /health ──────────────────────────────────────────────────────────────────────
@app.get("/health", tags=["System"])
async def health():
    return {"ok":True,"wavlm":_ok,"users":len(_DB),
            "threshold":THRESHOLD,"sr":SR,"version":"2.0"}

@app.get("/", include_in_schema=False)
async def root():
    return JSONResponse({"service":"VoxGuard Biometric API","version":"2.0",
                         "docs":"/docs","health":"/health"})

# ── asyncio ─────────────────────────────────────────────────────────────────────
import asyncio

# ── Startup ─────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    log.info("="*50)
    log.info("  VoxGuard Voice Biometric API v2.0")
    log.info(f"  Swagger : http://localhost:{PORT}/docs")
    log.info(f"  Health  : http://localhost:{PORT}/health")
    log.info(f"  WavLM   : {'✓ OK' if _ok else '✗ FAILED'}")
    log.info(f"  DB      : {DB_PATH} ({len(_DB)} users)")
    log.info("="*50)
    uvicorn.run(app, host="0.0.0.0", port=PORT, log_level="warning")