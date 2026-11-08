import base64
import json
import os
import re
import secrets
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import anthropic

PORT = int(os.environ.get("BOARD_PORT", "4199"))
PAGE = Path(os.environ["BOARD_HTML"])
RUNTIME = Path(os.environ.get("BOARD_RUNTIME", Path(os.environ["XDG_RUNTIME_DIR"]) / "board"))
PENDING = RUNTIME / "pending"
LEARN = Path(os.environ.get("BOARD_LEARN", Path.home() / "learn"))
BOARDS = LEARN / "board"
CHATS = BOARDS / "chats"
STYLE_GUIDE = Path.home() / ".claude" / "krish-llm.md"
TEACH_SKILL = Path.home() / ".claude" / "skills" / "teach"
CLAUDE = Path.home() / ".local" / "bin" / "claude"
SECRET_TOOL = os.environ["BOARD_SECRET_TOOL"]
PROVIDERS_FILE = Path(os.environ.get("BOARD_PROVIDERS", Path.home() / ".config" / "board" / "providers.json"))
BEDROCK_REGION = "us-east-1"
BEDROCK_MAX_TOKENS = 32000
COMPATIBLE_MAX_TOKENS = 8000
COMPATIBLE_TIMEOUT_SECONDS = 300
CLAUDE_TIMEOUT_SECONDS = 600
COMPATIBLE_URLS = {
    "openrouter": "https://openrouter.ai/api/v1/chat/completions",
    "gemini": "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
    "groq": "https://api.groq.com/openai/v1/chat/completions",
}
MAX_REQUEST_BYTES = 1_000_000
MAX_IMAGE_REQUEST_BYTES = 40_000_000
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
TITLE_LENGTH = 60
ALLOWED_HOSTS = {f"127.0.0.1:{PORT}", f"localhost:{PORT}"}
MODELS = {
    "claude-code": ["opus", "sonnet", "haiku"],
    "bedrock": [
        "us.anthropic.claude-opus-5-5",
        "us.anthropic.claude-sonnet-5-5",
        "us.anthropic.claude-haiku-5-5",
    ],
    "openrouter": [
        "anthropic/claude-opus-5.5",
        "anthropic/claude-sonnet-5.5",
        "anthropic/claude-haiku-5.5",
    ],
    "gemini": ["gemini-3.5-flash", "gemini-flash-latest", "gemini-flash-lite-latest"],
    "groq": ["openai/gpt-oss-120b", "qwen/qwen3.8-27b", "openai/gpt-oss-20b"],
}
SYSTEM_PROMPT = """You are explaining things to one person in a small window beside their work.
Answer in plain text, without Markdown formatting.
When a diagram, animation, 3D scene, or typeset math would help, also write exactly one fenced code block tagged html that holds a complete HTML document. The window draws it on a board above the chat.
The document runs in a sandboxed iframe. Give it background #171717, text #ececec and accent #10a37f so it matches the window. It can load scripts and styles from https://cdn.jsdelivr.net, for example three, katex and mermaid, and can animate with canvas or SVG. It has no access to local files or to this conversation.
Assume the person has never seen this kind of picture. Say on the board what every shape, colour and number means, using a short legend, even though the style guide avoids text in paper figures. Start with the smallest example that shows the idea, and add one thing at a time.
Images in a message are screenshots the person selected from their screen."""
FILES_PROMPT = f"""You can read and write files in {LEARN}, and nothing outside it. You cannot run commands or use the web.
Each folder in {LEARN} is a course or topic, with notes, revision sheets, past papers, and learn/ for session logs.
When asked to teach, read {TEACH_SKILL}/SKILL.md and {TEACH_SKILL}/setup.md first and follow them. Ask quiz questions in plain text, because the question tool is not available here."""
MAX_SAVED_FILES = 2
SAVE_SUFFIXES = {".md", ".txt", ".typ"}
SAVE_BLOCK = re.compile(r"^=== save: (.+?) ===[ \t]*\n(.*?)^=== end ===[ \t]*$", re.DOTALL | re.MULTILINE)
NO_FILES_PROMPT = f"""You cannot read the person's files, only this chat. If they ask about a file, tell them to paste it or use the claude-code backend.
When they ask you to save something, you can create new text files under {LEARN}. For each file, at most {MAX_SAVED_FILES} in a reply, write a line "=== save: relative/path.md ===", then the content, then a line "=== end ===". The path is relative to {LEARN}, for example RL/learn/notes.md, and must end in .md, .txt or .typ. You cannot change a file that already exists. Only do this when they ask."""
BOARD_BLOCK = re.compile(r"```html[ \t]*\n(.*?)```", re.DOTALL)
BOARD_NAME = re.compile(r"^[0-9-]+\.html$")
PROVIDER_NAME = re.compile(r"^[a-z0-9][a-z0-9-]{0,31}$")
CHAT_ID = re.compile(r"^[a-zA-Z0-9-]{1,64}$")
SHOT_NAME = re.compile(r"^[0-9]+\.png$")
TOKEN = ""


def load_token() -> str:
    path = RUNTIME / "token"
    try:
        existing = path.read_text().strip()
    except FileNotFoundError:
        existing = ""
    if existing:
        return existing
    token = secrets.token_urlsafe(32)
    descriptor = os.open(path, os.O_CREAT | os.O_WRONLY | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, "w") as token_file:
        token_file.write(token)
    return token


def blank_chat() -> dict:
    return {
        "id": uuid.uuid4().hex,
        "title": "New chat",
        "updated": None,
        "backend": None,
        "model": None,
        "session_id": None,
        "messages": [],
        "log": [],
        "board": None,
    }


busy = threading.Lock()
state = blank_chat()
chat_index: dict[str, dict] = {}


class BoardError(Exception):
    pass


def chat_path(chat_id: str) -> Path:
    if not CHAT_ID.match(chat_id):
        raise BoardError("That is not a valid chat.")
    return CHATS / f"{chat_id}.json"


def save_chat() -> None:
    state["updated"] = datetime.now().isoformat(timespec="seconds")
    target = chat_path(state["id"])
    temporary = target.with_suffix(".tmp")
    descriptor = os.open(temporary, os.O_CREAT | os.O_WRONLY | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, "w") as chat_file:
        json.dump(state, chat_file)
    temporary.replace(target)
    chat_index[state["id"]] = {"id": state["id"], "title": state["title"], "updated": state["updated"]}


def load_chat_index() -> None:
    for path in CHATS.glob("*.json"):
        try:
            saved = json.loads(path.read_text())
            chat_index[saved["id"]] = {"id": saved["id"], "title": saved["title"], "updated": saved["updated"]}
        except (OSError, json.JSONDecodeError, KeyError) as error:
            print(f"Skipping unreadable chat {path}: {error}", file=sys.stderr)


def start_new_chat() -> None:
    state.clear()
    state.update(blank_chat())


def open_chat(chat_id: str) -> None:
    try:
        saved = json.loads(chat_path(chat_id).read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise BoardError(f"Could not open that chat: {error}") from error
    state.clear()
    state.update(saved)


def delete_chat(chat_id: str) -> None:
    chat_path(chat_id).unlink(missing_ok=True)
    chat_index.pop(chat_id, None)
    if state["id"] == chat_id:
        start_new_chat()


def add_shot(data: str) -> None:
    try:
        image = base64.b64decode(data, validate=True)
    except ValueError as error:
        raise BoardError("That image could not be read.") from error
    if not image.startswith(PNG_SIGNATURE):
        raise BoardError("That image is not a PNG.")
    (PENDING / f"{time.time_ns()}.png").write_bytes(image)


def delete_shot(name: str) -> None:
    if not SHOT_NAME.match(name):
        raise BoardError("That is not a valid attachment.")
    (PENDING / name).unlink(missing_ok=True)


def read_key(name: str) -> str:
    completed = subprocess.run(
        [SECRET_TOOL, "lookup", "service", "board", "key", name],
        capture_output=True,
        text=True,
    )
    key = completed.stdout.strip()
    if completed.returncode != 0 or not key:
        raise BoardError(f"No {name} key in the keyring: {completed.stderr.strip()[:200]}")
    return key


def key_is_stored(name: str) -> bool:
    try:
        read_key(name)
    except BoardError:
        return False
    return True


def store_key(name: str, value: str) -> None:
    value = value.strip()
    if not value:
        raise BoardError("The key is empty.")
    completed = subprocess.run(
        [SECRET_TOOL, "store", f"--label=Board {name} key", "service", "board", "key", name],
        input=value,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        raise BoardError(f"Could not save the {name} key: {completed.stderr.strip()[:200]}")


def clear_key(name: str) -> None:
    subprocess.run(
        [SECRET_TOOL, "clear", "service", "board", "key", name],
        capture_output=True,
        text=True,
    )
    if key_is_stored(name):
        raise BoardError(f"Could not delete the {name} key.")


def custom_providers() -> dict:
    try:
        return json.loads(PROVIDERS_FILE.read_text())
    except FileNotFoundError:
        return {}
    except (OSError, json.JSONDecodeError) as error:
        raise BoardError(f"Could not read {PROVIDERS_FILE}: {error}") from error


def save_providers(providers: dict) -> None:
    PROVIDERS_FILE.parent.mkdir(parents=True, exist_ok=True)
    temporary = PROVIDERS_FILE.with_suffix(".tmp")
    temporary.write_text(json.dumps(providers, indent=2))
    temporary.replace(PROVIDERS_FILE)


def all_models() -> dict:
    custom = {name: provider["models"] for name, provider in custom_providers().items()}
    return {**MODELS, **custom}


def compatible_url(backend: str) -> str:
    if backend in COMPATIBLE_URLS:
        return COMPATIBLE_URLS[backend]
    return custom_providers()[backend]["url"]


def key_backends() -> list[dict]:
    custom = custom_providers()
    names = [name for name in MODELS if name != "claude-code"] + list(custom)
    return [
        {"name": name, "stored": key_is_stored(name), "custom": name in custom}
        for name in names
    ]


def set_key(name: str, value: str) -> None:
    if name not in all_models() or name == "claude-code":
        raise BoardError(f"Unknown backend: {name}")
    store_key(name, value)


def delete_key(name: str) -> None:
    if name not in all_models() or name == "claude-code":
        raise BoardError(f"Unknown backend: {name}")
    clear_key(name)


def add_provider(name: str, url: str, models: list, key: str) -> None:
    if not PROVIDER_NAME.match(name):
        raise BoardError("A provider name uses lowercase letters, digits and dashes, up to 32 characters.")
    if name in MODELS or name in custom_providers():
        raise BoardError(f"{name} already exists.")
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or not parsed.hostname:
        raise BoardError("The URL must start with https://, so the key is never sent unencrypted.")
    cleaned = [str(model).strip() for model in models if str(model).strip()]
    if not cleaned:
        raise BoardError("Add at least one model name.")
    store_key(name, key)
    save_providers({**custom_providers(), name: {"url": url, "models": cleaned}})


def delete_provider(name: str) -> None:
    providers = custom_providers()
    if name not in providers:
        raise BoardError(f"{name} is not a provider you added.")
    clear_key(name)
    del providers[name]
    save_providers(providers)
    if state["backend"] == name:
        state.update(backend=None, session_id=None, messages=[])


def system_prompt(has_files: bool) -> str:
    try:
        guide = STYLE_GUIDE.read_text()
    except OSError as error:
        raise BoardError(f"Could not read the style guide: {error}") from error
    access = FILES_PROMPT if has_files else NO_FILES_PROMPT
    return f"{SYSTEM_PROMPT}\n{access}\n\nFollow this style guide in everything you write:\n\n{guide}"


def allowed_tools() -> str:
    linked = [TEACH_SKILL / "SKILL.md", TEACH_SKILL / "setup.md", LEARN / "krish-llm.md", STYLE_GUIDE]
    rules = [f"Read(/{LEARN}/**)", f"Write(/{LEARN}/**)", f"Edit(/{LEARN}/**)"]
    for path in linked:
        rules += [f"Read(/{path})", f"Read(/{path.resolve()})"]
    return ",".join(rules)


def pending_shots() -> list[Path]:
    return sorted(PENDING.glob("*.png"))


def encode_shot(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


def user_content(text: str, shots: list[Path]) -> list[dict]:
    images = [
        {
            "type": "image",
            "source": {"type": "base64", "media_type": "image/png", "data": encode_shot(shot)},
        }
        for shot in shots
    ]
    return images + [{"type": "text", "text": text}]


def call_claude_code(model: str, text: str, shots: list[Path]) -> dict:
    arguments = [
        str(CLAUDE),
        "--print",
        "--input-format", "stream-json",
        "--output-format", "stream-json",
        "--verbose",
        "--model", model,
        "--tools", "Read,Write,Edit,Glob,Grep",
        "--permission-mode", "dontAsk",
        "--allowedTools", allowed_tools(),
        "--strict-mcp-config",
        "--setting-sources", "local",
        "--system-prompt", system_prompt(True),
    ]
    if state["session_id"]:
        arguments += ["--resume", state["session_id"]]
    environment = {
        name: value
        for name, value in os.environ.items()
        if not name.startswith(("ANTHROPIC_", "CLAUDE", "AWS_"))
    }
    message = {"type": "user", "message": {"role": "user", "content": user_content(text, shots)}}
    try:
        completed = subprocess.run(
            arguments,
            input=json.dumps(message) + "\n",
            capture_output=True,
            text=True,
            cwd=LEARN,
            env=environment,
            timeout=CLAUDE_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired as error:
        raise BoardError(f"Claude Code did not finish within {CLAUDE_TIMEOUT_SECONDS} s") from error
    result = None
    for line in completed.stdout.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") == "result":
            result = event
    if result is None:
        raise BoardError(f"Claude Code exited {completed.returncode}: {completed.stderr.strip()[:500]}")
    if result.get("is_error"):
        raise BoardError(f"Claude Code failed: {str(result.get('result'))[:500]}")
    state["session_id"] = result["session_id"]
    usage = result.get("usage", {})
    return {
        "text": result.get("result", ""),
        "input_tokens": usage.get("input_tokens"),
        "output_tokens": usage.get("output_tokens"),
    }


def call_bedrock(model: str, text: str, shots: list[Path]) -> dict:
    client = anthropic.AnthropicBedrock(
        api_key=read_key("bedrock"),
        aws_region=BEDROCK_REGION,
    )
    outgoing = state["messages"] + [{"role": "user", "content": user_content(text, shots)}]
    try:
        with client.messages.stream(
            model=model,
            max_tokens=BEDROCK_MAX_TOKENS,
            thinking={"type": "adaptive"},
            output_config={"effort": "medium"},
            system=system_prompt(False),
            messages=outgoing,
        ) as stream:
            response = stream.get_final_message()
    except anthropic.APIStatusError as error:
        raise BoardError(f"Bedrock returned {error.status_code}: {error.message[:500]}") from error
    except anthropic.APIConnectionError as error:
        raise BoardError(f"Could not reach Bedrock: {error}") from error
    if response.stop_reason == "refusal":
        raise BoardError("Bedrock declined this message. Try rewording it or switching model.")
    content = [block.model_dump(mode="json", exclude_unset=True) for block in response.content]
    state["messages"] = outgoing + [{"role": "assistant", "content": content}]
    reply = "".join(block.text for block in response.content if block.type == "text")
    if response.stop_reason == "max_tokens":
        reply += f"\n\n[Cut off at the {BEDROCK_MAX_TOKENS} token limit.]"
    return {
        "text": reply,
        "input_tokens": response.usage.input_tokens,
        "output_tokens": response.usage.output_tokens,
    }


def call_compatible(backend: str, model: str, text: str, shots: list[Path]) -> dict:
    images = [
        {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{encode_shot(shot)}"}}
        for shot in shots
    ]
    content = images + [{"type": "text", "text": text}] if images else text
    outgoing = state["messages"] + [{"role": "user", "content": content}]
    request = urllib.request.Request(
        compatible_url(backend),
        data=json.dumps({
            "model": model,
            "max_tokens": COMPATIBLE_MAX_TOKENS,
            "messages": [{"role": "system", "content": system_prompt(False)}] + outgoing,
        }).encode(),
        headers={
            "Authorization": f"Bearer {read_key(backend)}",
            "Content-Type": "application/json",
            "User-Agent": "board/1",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=COMPATIBLE_TIMEOUT_SECONDS) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as error:
        raise BoardError(f"{backend} returned {error.code}: {error.read().decode(errors='replace')[:500]}") from error
    except (urllib.error.URLError, TimeoutError) as error:
        raise BoardError(f"Could not reach {backend}: {error}") from error
    try:
        choice = payload["choices"][0]
        reply = choice["message"]["content"] or ""
    except (KeyError, IndexError, TypeError) as error:
        raise BoardError(f"Unexpected {backend} response: {json.dumps(payload)[:500]}") from error
    if not reply:
        raise BoardError(f"{backend} returned no text, finish reason {choice.get('finish_reason')}.")
    state["messages"] = outgoing + [{"role": "assistant", "content": reply}]
    if choice.get("finish_reason") == "length":
        reply += f"\n\n[Cut off at the {COMPATIBLE_MAX_TOKENS} token limit.]"
    usage = payload.get("usage") or {}
    return {
        "text": reply,
        "input_tokens": usage.get("prompt_tokens"),
        "output_tokens": usage.get("completion_tokens"),
    }


def call_backend(backend: str, model: str, text: str, shots: list[Path]) -> dict:
    if backend == "claude-code":
        return call_claude_code(model, text, shots)
    if backend == "bedrock":
        return call_bedrock(model, text, shots)
    return call_compatible(backend, model, text, shots)


def save_file(relative: str, content: str) -> str:
    root = LEARN.resolve()
    target = (root / relative.strip()).resolve()
    if not target.is_relative_to(root) or target.is_relative_to(BOARDS.resolve()) or target == root:
        return f"[not saved, outside the allowed folders: {relative}]"
    if target.suffix not in SAVE_SUFFIXES:
        return f"[not saved, only .md, .txt and .typ files: {relative}]"
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("x") as new_file:
            new_file.write(content)
    except FileExistsError:
        return f"[not saved, a file already exists there: {relative}]"
    except OSError as error:
        return f"[not saved, {error.strerror}: {relative}]"
    return f"[saved ~/learn/{target.relative_to(root)}]"


def save_files(reply: str) -> str:
    saved = 0

    def replace(match: re.Match) -> str:
        nonlocal saved
        saved += 1
        if saved > MAX_SAVED_FILES:
            return f"[not saved, only {MAX_SAVED_FILES} files per reply: {match.group(1)}]"
        return save_file(match.group(1), match.group(2))

    return SAVE_BLOCK.sub(replace, reply)


def save_board(reply: str) -> tuple[str, str | None]:
    matches = BOARD_BLOCK.findall(reply)
    if not matches:
        return reply, None
    name = datetime.now().strftime("%Y-%m-%d-%H%M%S-%f") + ".html"
    (BOARDS / name).write_text(matches[-1])
    return BOARD_BLOCK.sub("[drawn on the board]", reply).strip(), name


def chat(backend: str, model: str, text: str) -> None:
    models = all_models()
    if backend not in models or model not in models[backend]:
        raise BoardError(f"Unknown backend or model: {backend} {model}")
    if not text.strip():
        raise BoardError("The message is empty.")
    if state["backend"] != backend:
        if state["backend"] is not None:
            state["log"].append({"role": "note", "text": f"Switched to {backend}. It can't see the messages above."})
        state.update(backend=backend, session_id=None, messages=[])
    state["model"] = model
    if not state["log"]:
        state["title"] = " ".join(text.split())[:TITLE_LENGTH]
    shots = pending_shots()
    state["log"].append({"role": "user", "text": text, "shots": len(shots)})
    save_chat()
    try:
        reply = call_backend(backend, model, text, shots)
    except BoardError as error:
        state["log"].append({"role": "error", "text": str(error)})
        save_chat()
        raise
    for shot in shots:
        shot.unlink(missing_ok=True)
    answer = reply["text"] if backend == "claude-code" else save_files(reply["text"])
    shown, board = save_board(answer)
    if board:
        state["board"] = board
    state["log"].append({
        "role": "assistant",
        "text": shown,
        "model": model,
        "board": board,
        "input_tokens": reply["input_tokens"],
        "output_tokens": reply["output_tokens"],
    })
    save_chat()


def public_state() -> dict:
    return {
        "models": all_models(),
        "chat": {key: state[key] for key in ("id", "title", "backend", "model", "log", "board")},
        "chats": sorted(chat_index.values(), key=lambda summary: summary["updated"] or "", reverse=True),
        "busy": busy.locked(),
        "pending": [shot.name for shot in pending_shots()],
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format: str, *args: object) -> None:
        return

    def send_bytes(self, status: int, content_type: str, body: bytes, headers: dict | None = None) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for name, value in (headers or {}).items():
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(body)

    def send_json(self, status: int, payload: dict) -> None:
        self.send_bytes(status, "application/json", json.dumps(payload).encode())

    def host_allowed(self) -> bool:
        if self.headers.get("Host") in ALLOWED_HOSTS:
            return True
        self.send_json(403, {"error": "Wrong host."})
        return False

    def token_allowed(self) -> bool:
        if secrets.compare_digest(self.headers.get("X-Board-Token", ""), TOKEN):
            return True
        self.send_json(403, {"error": "Wrong token."})
        return False

    def do_GET(self) -> None:
        if not self.host_allowed():
            return
        path = self.path.split("?", 1)[0]
        if path == "/":
            self.send_bytes(200, "text/html; charset=utf-8", PAGE.read_bytes())
        elif path.startswith("/board/"):
            self.serve_board(path.removeprefix("/board/"))
        elif path.startswith("/api/shots/"):
            if self.token_allowed():
                self.serve_shot(path.removeprefix("/api/shots/"))
        elif path in ("/api/state", "/api/keys"):
            if self.token_allowed():
                try:
                    self.send_json(200, public_state() if path == "/api/state" else {"keys": key_backends()})
                except BoardError as error:
                    self.send_json(502, {"error": str(error)})
        else:
            self.send_json(404, {"error": "Not found."})

    def serve_board(self, name: str) -> None:
        target = BOARDS / name
        if not BOARD_NAME.match(name) or not target.is_file():
            self.send_json(404, {"error": "No such board."})
            return
        self.send_bytes(
            200,
            "text/html; charset=utf-8",
            target.read_bytes(),
            {"Content-Security-Policy": "sandbox allow-scripts"},
        )

    def serve_shot(self, name: str) -> None:
        target = PENDING / name
        if not SHOT_NAME.match(name) or not target.is_file():
            self.send_json(404, {"error": "No such attachment."})
            return
        self.send_bytes(200, "image/png", target.read_bytes())

    def do_POST(self) -> None:
        if not self.host_allowed() or not self.token_allowed():
            return
        is_image = self.path == "/api/shots"
        length = int(self.headers.get("Content-Length", "0"))
        if length > (MAX_IMAGE_REQUEST_BYTES if is_image else MAX_REQUEST_BYTES):
            self.send_json(413, {"error": "That is too large to send."})
            return
        try:
            body = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            self.send_json(400, {"error": "The request is not valid JSON."})
            return
        if self.path in ("/api/shots", "/api/shots/delete"):
            try:
                if is_image:
                    add_shot(str(body.get("data", "")))
                else:
                    delete_shot(str(body.get("name", "")))
                self.send_json(200, public_state())
            except BoardError as error:
                self.send_json(502, {"error": str(error)})
            return
        if not busy.acquire(blocking=False):
            self.send_json(409, {"error": "Still answering the last message."})
            return
        try:
            if self.path == "/api/chat":
                chat(str(body.get("backend")), str(body.get("model")), str(body.get("text", "")))
            elif self.path == "/api/chats/new":
                start_new_chat()
            elif self.path == "/api/chats/open":
                open_chat(str(body.get("id", "")))
            elif self.path == "/api/chats/delete":
                delete_chat(str(body.get("id", "")))
            elif self.path == "/api/keys":
                set_key(str(body.get("name")), str(body.get("value", "")))
            elif self.path == "/api/keys/delete":
                delete_key(str(body.get("name")))
            elif self.path == "/api/providers":
                add_provider(
                    str(body.get("name", "")),
                    str(body.get("url", "")),
                    list(body.get("models") or []),
                    str(body.get("key", "")),
                )
            elif self.path == "/api/providers/delete":
                delete_provider(str(body.get("name")))
            else:
                self.send_json(404, {"error": "Not found."})
                return
            snapshot = public_state()
        except BoardError as error:
            self.send_json(502, {"error": str(error)})
            return
        finally:
            busy.release()
        self.send_json(200, snapshot)


def main() -> None:
    global TOKEN
    PENDING.mkdir(parents=True, exist_ok=True, mode=0o700)
    BOARDS.mkdir(parents=True, exist_ok=True)
    CHATS.mkdir(exist_ok=True, mode=0o700)
    load_chat_index()
    TOKEN = load_token()
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
