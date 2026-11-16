import difflib
import gc
import io
import json
import os
import re
import shutil
import subprocess
import time
import traceback
import urllib.request
import uuid

import av

_av_open = av.open


def _open(*args, metadata_errors=None, **kwargs):
    return _av_open(*args, **kwargs)


av.open = _open

from faster_whisper import WhisperModel

API = os.environ.get("IMMICH_API", "http://127.0.0.1:2283/api")
ML = os.environ.get("IMMICH_ML", "http://127.0.0.1:3003")
DATA = os.environ.get("DATA_DIR", "/data")
CACHE = os.environ.get("CACHE_DIR", "/cache")
KEY = open(os.environ.get("KEY_FILE", os.path.join(DATA, "api-key"))).read().strip()
DEADLINE = float(os.environ.get("DEADLINE") or "inf")
LIMIT = int(os.environ.get("LIMIT") or "0")
ONLY = set(filter(None, os.environ.get("ONLY", "").split(",")))
VERSION = 1
MAX_ATTEMPTS = 3
OCR_RESERVE = 75 * 60
MIN_FREE_MB = 3000
FRAME_STEP = 2.0
MAX_FRAMES = 300
MAX_OCR_LINES = 500
MAX_SPEECH_CHARS = 20000
MAX_OCR_CHARS = 5000
LANGUAGE_REMAP = {"ur": "hi"}
LANGUAGES = {"en", "hi", "gu", "mr", "ur", "ja", "ta", "te", "kn", "ml", "bn", "pa", "ko", "es", "fr", "de"}
HALLUCINATION = re.compile(
    r"thank(s| you) (so much )?for watching|terima kasih|takk for|takk skal|subscribe|sampai jumpa"
    r"|untertitel|sous-titres|amara\.org|ご視聴ありがとう|字幕|продолжение следует",
    re.I,
)
BEGIN = "[video text]"
END = "[/video text]"
CLOCK = re.compile(r"\W{0,3}\d{1,2}[:.]\d{2}(?:[:.]\d{2})?\s*(?:[AaPp][Mm])?\W{0,3}")
BLOCK = re.compile(r"\s*\[video text\].*?\[/video text\]\s*", re.S)
OCR_ENTRIES = json.dumps(
    {
        "ocr": {
            "detection": {"modelName": "PP-OCRv5_mobile", "options": {"minScore": 0.5, "maxResolution": 736}},
            "recognition": {"modelName": "PP-OCRv5_mobile", "options": {"minScore": 0.8}},
        }
    }
)
VIDEOS = os.path.join(DATA, "videos")
SPEECH = os.path.join(DATA, "speech")
FAILED = os.path.join(DATA, "failed.json")
TMP = os.path.join(CACHE, "tmp")


def log(*parts):
    print(*parts, flush=True)


def call(method, path, body=None):
    req = urllib.request.Request(
        API + path,
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"x-api-key": KEY, "content-type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=120) as res:
        raw = res.read()
        return json.loads(raw) if raw else None


def download(asset):
    ext = os.path.splitext(asset["originalFileName"])[1] or ".mp4"
    path = os.path.join(TMP, asset["id"] + ext)
    req = urllib.request.Request(f"{API}/assets/{asset['id']}/original", headers={"x-api-key": KEY})
    with urllib.request.urlopen(req, timeout=600) as res, open(path, "wb") as f:
        shutil.copyfileobj(res, f, 1 << 20)
    return path


def read_json(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        return default


def write_json(path, value):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(value, f, ensure_ascii=False)
    os.replace(tmp, path)


def list_videos():
    items, page = [], 1
    while page:
        result = call("POST", "/search/metadata", {"type": "VIDEO", "withExif": True, "size": 1000, "page": page})["assets"]
        items += result["items"]
        page = int(result["nextPage"]) if result.get("nextPage") else None
    items = [a for a in items if not a.get("isTrashed") and not a.get("isOffline") and a.get("visibility") != "hidden"]
    if ONLY:
        items = [a for a in items if a["id"] in ONLY]
    items.sort(key=lambda a: a["fileCreatedAt"], reverse=True)
    return items


def gpu_free_mb():
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=memory.free", "--format=csv,noheader,nounits"],
            capture_output=True,
            text=True,
            timeout=30,
        ).stdout
        return int(out.split()[0])
    except Exception:
        return None


def wait_for_gpu(limit=900):
    started = time.time()
    while time.time() - started < limit:
        free = gpu_free_mb()
        if free is None or free >= MIN_FREE_MB:
            return
        time.sleep(15)
    log(f"gpu still has under {MIN_FREE_MB}MB free after {limit}s, trying anyway")


def gpu_error(error):
    text = str(error).lower()
    return isinstance(error, RuntimeError) and any(k in text for k in ("out of memory", "cuda", "cublas", "cudnn"))


class Whisper:
    def __init__(self):
        self.model = None

    def load(self):
        for attempt in range(4):
            wait_for_gpu()
            try:
                self.model = WhisperModel("large-v3", device="cuda", compute_type="int8_float16")
                return
            except RuntimeError as error:
                if attempt == 3 or not gpu_error(error):
                    raise
                log(f"gpu busy loading whisper ({error}), waiting")

    def unload(self):
        if self.model is None:
            return
        try:
            self.model.model.unload_model()
        except Exception:
            pass
        self.model = None
        gc.collect()

    def run(self, path, language=None, task="transcribe"):
        for attempt in range(4):
            if self.model is None:
                self.load()
            try:
                segments, info = self.model.transcribe(
                    path,
                    beam_size=5,
                    vad_filter=True,
                    condition_on_previous_text=False,
                    language=language,
                    task=task,
                )
                return list(segments), info
            except RuntimeError as error:
                if attempt == 3 or not gpu_error(error):
                    raise
                log(f"gpu busy during {task} ({error}), reloading whisper")
                self.unload()


def keep(segments):
    return [
        {"start": round(s.start, 2), "end": round(s.end, 2), "text": s.text.strip()}
        for s in segments
        if s.text.strip()
        and s.compression_ratio <= 2.4
        and not (s.no_speech_prob > 0.6 and s.avg_logprob < -1.0)
        and not HALLUCINATION.search(s.text)
    ]


def transcribe(whisper, path):
    segments, info = whisper.run(path)
    if info.duration_after_vad < 3:
        segments = []
    language = info.language
    if language not in LANGUAGES:
        probs = dict(info.all_language_probs or [])
        language = max(LANGUAGES, key=lambda code: probs.get(code, 0))
    language = LANGUAGE_REMAP.get(language, language)
    if segments and language != info.language:
        segments, _ = whisper.run(path, language=language)
    segments = keep(segments)
    english = []
    if segments and language != "en":
        translated, _ = whisper.run(path, language=language, task="translate")
        english = keep(translated)
    return {
        "language": language if segments else None,
        "detectedLanguage": info.language,
        "languageProbability": round(info.language_probability, 3),
        "speechSeconds": round(info.duration_after_vad, 1),
        "segments": segments,
        "english": english,
    }


def ocr(image):
    image.thumbnail((1280, 1280))
    buffer = io.BytesIO()
    image.convert("RGB").save(buffer, "JPEG", quality=90)
    boundary = uuid.uuid4().hex
    body = (
        f'--{boundary}\r\nContent-Disposition: form-data; name="entries"\r\n\r\n{OCR_ENTRIES}\r\n'
        f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="frame.jpg"\r\n'
        f"Content-Type: image/jpeg\r\n\r\n"
    ).encode() + buffer.getvalue() + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(
        ML + "/predict", data=body, headers={"content-type": f"multipart/form-data; boundary={boundary}"}
    )
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=120) as res:
                return json.load(res).get("ocr", {}).get("text", [])
        except Exception as error:
            if attempt == 3:
                raise
            log(f"ocr failed ({error}), retrying in 60s")
            time.sleep(60)


def add_line(lines, text, at):
    text = re.sub(r"\s+", " ", text).strip()
    if len(text) < 3 or len(lines) >= MAX_OCR_LINES or CLOCK.fullmatch(text):
        return
    low = text.lower()
    for line in lines:
        if difflib.SequenceMatcher(None, low, line["text"].lower()).ratio() > 0.85:
            return
    lines.append({"t": round(at, 2), "text": text})


def frame_text(path, duration):
    step = max(FRAME_STEP, duration / MAX_FRAMES) if duration else FRAME_STEP
    frames, lines = [], []
    with av.open(path) as container:
        if not container.streams.video:
            return frames, lines
        stream = container.streams.video[0]
        stream.codec_context.skip_frame = "NONKEY"
        next_at = 0.0
        for frame in container.decode(stream):
            if frame.time is None or frame.time + 1e-6 < next_at:
                continue
            next_at = frame.time + step
            image = frame.to_image()
            rotation = getattr(frame, "rotation", 0) or 0
            if rotation:
                image = image.rotate(rotation, expand=True)
            for text in ocr(image):
                add_line(lines, text, frame.time)
            frames.append(round(frame.time, 2))
            if len(frames) >= MAX_FRAMES:
                break
    return frames, lines


def has_audio(path):
    with av.open(path) as container:
        return len(container.streams.audio) > 0


def block(result):
    parts = []
    speech = result.get("speech") or {}
    if speech.get("segments"):
        text = " ".join(s["text"] for s in speech["segments"])[:MAX_SPEECH_CHARS]
        parts.append(f"speech ({speech['language']}): {text}")
    if speech.get("english"):
        text = " ".join(s["text"] for s in speech["english"])[:MAX_SPEECH_CHARS]
        parts.append(f"speech in english: {text}")
    if result.get("ocr"):
        parts.append("on screen: " + " | ".join(line["text"] for line in result["ocr"])[:MAX_OCR_CHARS])
    return f"{BEGIN}\n" + "\n".join(parts) + f"\n{END}" if parts else ""


def described(current, result):
    base = BLOCK.sub("\n\n", current or "").strip()
    text = block(result)
    return f"{base}\n\n{text}".strip() if text else base


def apply(asset, result):
    current = (asset.get("exifInfo") or {}).get("description") or ""
    wanted = described(current, result)
    if wanted != current:
        call("PUT", f"/assets/{asset['id']}", {"description": wanted})
        return True
    return False


def stale(result):
    speech = result.get("speech") or {}
    if not speech.get("segments"):
        return False
    if speech.get("detectedLanguage") not in LANGUAGES:
        return True
    return any(HALLUCINATION.search(s["text"]) for s in speech["segments"] + speech.get("english", []))


def main():
    os.nice(19)
    for folder in (VIDEOS, SPEECH):
        os.makedirs(folder, exist_ok=True)
    shutil.rmtree(TMP, ignore_errors=True)
    os.makedirs(TMP)
    failed = read_json(FAILED, {})
    assets = list_videos()

    pending, reapplied, redo = [], 0, 0
    for asset in assets:
        result = read_json(os.path.join(VIDEOS, asset["id"] + ".json"), None)
        if result and result.get("checksum") == asset["checksum"] and result.get("version") == VERSION:
            if not stale(result):
                reapplied += apply(asset, result)
                continue
            redo += 1
        miss = failed.get(asset["id"])
        if miss and miss.get("checksum") == asset["checksum"] and miss["attempts"] >= MAX_ATTEMPTS:
            continue
        pending.append(asset)
    if LIMIT:
        pending = pending[:LIMIT]
    log(f"videos {len(assets)} pending {len(pending)} (redo {redo}) descriptions restored {reapplied}")

    def fail(asset, error):
        traceback.print_exc()
        miss = failed.get(asset["id"], {})
        attempts = miss.get("attempts", 0) + 1 if miss.get("checksum") == asset["checksum"] else 1
        failed[asset["id"]] = {"checksum": asset["checksum"], "attempts": attempts, "error": repr(error)[:500]}
        write_json(FAILED, failed)
        log(f"failed {asset['originalFileName']} attempt {attempts}: {error!r}")

    def heard_path(asset):
        return os.path.join(SPEECH, asset["id"] + ".json")

    def heard(asset):
        saved = read_json(heard_path(asset), None)
        return saved if saved and saved.get("checksum") == asset["checksum"] else None

    whisper = Whisper()
    listened = 0
    for asset in pending:
        if time.time() >= DEADLINE - OCR_RESERVE:
            log("leaving the rest of the night for on-screen text")
            break
        if heard(asset):
            continue
        path = None
        try:
            path = download(asset)
            speech = transcribe(whisper, path) if has_audio(path) else None
            write_json(heard_path(asset), {"checksum": asset["checksum"], "speech": speech})
            listened += 1
        except Exception as error:
            fail(asset, error)
        finally:
            if path:
                os.remove(path)
    whisper.unload()
    log(f"speech pass done for {listened} videos")

    done = 0
    for asset in pending:
        if time.time() >= DEADLINE:
            log("deadline reached, stopping")
            break
        saved = heard(asset)
        if not saved:
            continue
        started = time.time()
        duration = (asset.get("duration") or 0) / 1000
        path = None
        try:
            path = download(asset)
            frames, lines = frame_text(path, duration)
            result = {
                "version": VERSION,
                "assetId": asset["id"],
                "checksum": asset["checksum"],
                "originalFileName": asset["originalFileName"],
                "duration": round(duration, 2),
                "speech": saved["speech"],
                "frames": frames,
                "ocr": lines,
                "processedAt": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            }
            write_json(os.path.join(VIDEOS, asset["id"] + ".json"), result)
            apply(asset, result)
            os.remove(heard_path(asset))
        except Exception as error:
            fail(asset, error)
            continue
        finally:
            if path:
                os.remove(path)
        if failed.pop(asset["id"], None):
            write_json(FAILED, failed)
        done += 1
        speech = saved["speech"] or {}
        log(
            f"{asset['originalFileName']} {duration:.0f}s"
            f" speech {speech.get('language') or '-'} {speech.get('speechSeconds', 0):.0f}s"
            f" {len(speech.get('segments', []))} segments, {len(lines)} text lines"
            f" from {len(frames)} frames, ocr took {time.time() - started:.0f}s"
        )
    log(f"done {done}, left {len(pending) - done}, failed so far {len(failed)}")


main()
