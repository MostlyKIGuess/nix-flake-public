import asyncio
import io
import json
import math
import signal
import subprocess
import sys
import wave
from array import array
from pathlib import Path

import httpx
from websockets.asyncio.client import connect

SAMPLE_RATE = 16000
BYTES_PER_SAMPLE = 2
LIVE_PREVIEW_CHARS = 300

DEEPGRAM_URL = (
    "wss://api.deepgram.com/v1/listen?model=nova-3&encoding=linear16"
    f"&sample_rate={SAMPLE_RATE}&channels=1&smart_format=true"
)
DEEPGRAM_CHUNK_BYTES = SAMPLE_RATE * BYTES_PER_SAMPLE // 10

GROQ_URL = "https://api.groq.com/openai/v1/audio/transcriptions"
GROQ_MODEL = "whisper-large-v3-turbo"
GROQ_PROMPT_CHARS = 200
FRAME_SECONDS = 0.03
FRAME_BYTES = int(SAMPLE_RATE * FRAME_SECONDS) * BYTES_PER_SAMPLE
MIN_PHRASE_SECONDS = 6.0
MAX_PHRASE_SECONDS = 25.0
PAUSE_SECONDS = 0.7
MIN_SPEECH_SECONDS = 0.3
SPEECH_OVER_NOISE_FLOOR = 3.0
MIN_SPEECH_RMS = 300.0


class LiveNotification:
    def __init__(self, title: str, id_path: Path) -> None:
        self.title = title
        self.id_path = id_path
        self.notification_id: str | None = None

    def show(self, text: str) -> None:
        command = ["notify-send", "-p", "-t", "0", self.title, text[-LIVE_PREVIEW_CHARS:]]
        if self.notification_id is not None:
            command[2:2] = ["-r", self.notification_id]
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        self.notification_id = result.stdout.strip()
        self.id_path.write_text(self.notification_id)


class Transcript:
    def __init__(self, out_path: Path, backend: str) -> None:
        self.phrases: list[str] = []
        self.live_path = out_path.with_suffix(".live")
        self.notification = LiveNotification(
            f"Dictation ({backend}-stream)", out_path.with_suffix(".notification")
        )
        self.notification.show("Listening, press again to stop")

    def text(self) -> str:
        return " ".join(self.phrases)

    def add(self, phrase: str) -> None:
        phrase = phrase.strip()
        if not any(character.isalnum() for character in phrase):
            return
        typed = f" {phrase}" if self.phrases else phrase
        subprocess.run(["wtype", "--", typed], check=True)
        self.phrases.append(phrase)
        self.live_path.write_text(self.text())
        self.notification.show(self.text())


async def start_recorder() -> asyncio.subprocess.Process:
    return await asyncio.create_subprocess_exec(
        "pw-record", "--rate", str(SAMPLE_RATE), "--channels", "1",
        "--format", "s16", "--raw", "-",
        stdout=asyncio.subprocess.PIPE,
    )


async def read_frame(recorder: asyncio.subprocess.Process, size: int) -> bytes:
    assert recorder.stdout is not None
    try:
        return await recorder.stdout.readexactly(size)
    except asyncio.IncompleteReadError as error:
        raise RuntimeError(f"recorder exited with code {await recorder.wait()}") from error


async def stop_recorder(recorder: asyncio.subprocess.Process) -> bytes:
    assert recorder.stdout is not None
    recorder.terminate()
    remaining = await recorder.stdout.read()
    await recorder.wait()
    whole_samples = len(remaining) - len(remaining) % BYTES_PER_SAMPLE
    return remaining[:whole_samples]


async def stream_deepgram(key: str, stop: asyncio.Event, transcript: Transcript) -> None:
    recorder = await start_recorder()
    async with connect(DEEPGRAM_URL, additional_headers={"Authorization": f"Token {key}"}) as connection:

        async def send_audio() -> None:
            while not stop.is_set():
                await connection.send(await read_frame(recorder, DEEPGRAM_CHUNK_BYTES))
            remaining = await stop_recorder(recorder)
            if remaining:
                await connection.send(remaining)
            await connection.send(json.dumps({"type": "CloseStream"}))

        async def receive_phrases() -> None:
            async for message in connection:
                data = json.loads(message)
                if data.get("type") == "Results" and data.get("is_final"):
                    transcript.add(data["channel"]["alternatives"][0]["transcript"])

        await asyncio.gather(send_audio(), receive_phrases())


class PhraseSplitter:
    """Cuts the recording at pauses into phrases long enough to be worth one request."""

    def __init__(self) -> None:
        self.audio = bytearray()
        self.speech_frames = 0
        self.silent_run = 0
        self.noise_floor: float | None = None

    def push(self, frame: bytes) -> bytes | None:
        samples = array("h", frame)
        rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples))
        threshold = max(MIN_SPEECH_RMS, (self.noise_floor or rms) * SPEECH_OVER_NOISE_FLOOR)
        if rms > threshold:
            self.speech_frames += 1
            self.silent_run = 0
        else:
            self.silent_run += 1
            self.noise_floor = rms if self.noise_floor is None else 0.95 * self.noise_floor + 0.05 * rms
        self.audio += frame
        seconds = len(self.audio) / (SAMPLE_RATE * BYTES_PER_SAMPLE)
        paused = self.silent_run * FRAME_SECONDS >= PAUSE_SECONDS
        if (seconds >= MIN_PHRASE_SECONDS and paused) or seconds >= MAX_PHRASE_SECONDS:
            return self.take()
        return None

    def take(self) -> bytes | None:
        has_speech = self.speech_frames * FRAME_SECONDS >= MIN_SPEECH_SECONDS
        audio = bytes(self.audio)
        self.audio.clear()
        self.speech_frames = 0
        self.silent_run = 0
        return audio if has_speech else None


def wav_bytes(pcm: bytes) -> bytes:
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(BYTES_PER_SAMPLE)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(pcm)
    return buffer.getvalue()


async def transcribe_groq(client: httpx.AsyncClient, key: str, pcm: bytes, prompt: str) -> str:
    response = await client.post(
        GROQ_URL,
        headers={"Authorization": f"Bearer {key}"},
        files={"file": ("phrase.wav", wav_bytes(pcm), "audio/wav")},
        data={"model": GROQ_MODEL, "response_format": "json", "prompt": prompt},
    )
    if response.is_error:
        raise RuntimeError(f"groq returned {response.status_code}: {response.text}")
    return response.json()["text"]


async def stream_groq(key: str, stop: asyncio.Event, transcript: Transcript) -> None:
    recorder = await start_recorder()
    pending: asyncio.Queue[asyncio.Task[str] | None] = asyncio.Queue()
    splitter = PhraseSplitter()
    async with httpx.AsyncClient(timeout=30) as client:

        def submit(pcm: bytes | None) -> None:
            if pcm is None:
                return
            prompt = transcript.text()[-GROQ_PROMPT_CHARS:]
            pending.put_nowait(asyncio.create_task(transcribe_groq(client, key, pcm, prompt)))

        async def type_in_order() -> None:
            while (task := await pending.get()) is not None:
                transcript.add(await task)

        typing = asyncio.create_task(type_in_order())
        while not stop.is_set():
            if typing.done():
                typing.result()
            submit(splitter.push(await read_frame(recorder, FRAME_BYTES)))
        remaining = await stop_recorder(recorder)
        for start in range(0, len(remaining) - FRAME_BYTES + 1, FRAME_BYTES):
            end = start + FRAME_BYTES
            submit(splitter.push(remaining[start:end]))
        submit(splitter.take())
        pending.put_nowait(None)
        await typing


async def stream(backend: str, key_path: Path, out_path: Path) -> None:
    key = key_path.read_text().strip()
    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for signum in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(signum, stop.set)
    transcript = Transcript(out_path, backend)
    if backend == "deepgram":
        await stream_deepgram(key, stop, transcript)
    elif backend == "groq":
        await stream_groq(key, stop, transcript)
    else:
        raise ValueError(f"no streaming mode for backend {backend}")
    out_path.write_text(transcript.text())


def main() -> None:
    if len(sys.argv) != 4:
        sys.exit("usage: dictate-stream <deepgram|groq> <key-file> <transcript-file>")
    asyncio.run(stream(sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])))


if __name__ == "__main__":
    main()
