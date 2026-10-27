#!/usr/bin/env python3
"""voice-tts -- an OpenAI-compatible text-to-speech endpoint for the LAN.

WHY. The sibling of `voice-stt.py`: the same contract, the other direction. Any
client that speaks the OpenAI audio API can ask this machine to speak without a
key in transit and without a third party hearing the text. Measured on this
machine 2026-10-25 (see ../shootout/results.md): Kokoro-82M, 4.1x realtime,
541 ms to the first word of a sentence, one core, no GPU.

NOT A PUBLIC SERVICE. It binds the LAN, requires a bearer token, and is meant to
be reachable only on the home network. It holds no state beyond the loaded model.

    voice_tts.py serve [--host H] [--port P] [--token T | --token-file F]
    voice_tts.py selftest "text" [-o out.wav]

Endpoints
    GET  /health               {ok, model, voices, sample_rate}
    GET  /v1/models            OpenAI model list
    GET  /v1/audio/voices      {voices: [...], default}
    POST /v1/audio/speech      {model, input, voice, response_format, speed}
                               response_format: wav | pcm | mp3

A sentence is the unit of synthesis: one request in, one utterance out. Latency
that matters is per sentence, so a client that splits its text can start playing
after ~0.5 s and stay ahead of playback on this machine.
"""

from __future__ import annotations

import argparse
import io
import json
import os
import re
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MODEL_DIR = os.environ.get(
    "VOICE_TTS_MODELS", os.path.expanduser("~/02_AREAS/B_Tech/tts/models")
)
DEFAULT_VOICE = os.environ.get("VOICE_TTS_VOICE", "af_heart")
MODEL_ID = "kokoro-82m"
MAX_CHARS = 20000  # a request above this is refused with 413; `say` sends one sentence

_model = None
_voices: list[str] = []
_load_lock = threading.Lock()
_infer_lock = threading.Lock()  # one synthesis at a time; the session is not reentrant


def get_model():
    global _model, _voices
    with _load_lock:
        if _model is None:
            from kokoro_onnx import Kokoro

            t0 = time.perf_counter()
            _model = Kokoro(
                os.path.join(MODEL_DIR, "kokoro-v1.0.onnx"),
                os.path.join(MODEL_DIR, "voices-v1.0.bin"),
            )
            _voices = _model.get_voices()
            print(f"loaded {MODEL_ID} in {time.perf_counter() - t0:.2f}s", file=sys.stderr)
        return _model


def lang_for(voice: str) -> str:
    """Kokoro voice ids carry their language in the first letter."""
    return {
        "a": "en-us",
        "b": "en-gb",
        "j": "ja",
        "z": "cmn",
        "e": "es",
        "f": "fr",
        "h": "hi",
        "i": "it",
        "p": "pt-br",
    }.get(voice[:1], "en-us")


def synthesise(text: str, voice: str, speed: float) -> tuple[bytes, int]:
    """Text -> float32 samples. Returns (samples, sample_rate)."""
    k = get_model()
    if voice not in _voices:
        raise ValueError(f"unknown voice {voice!r}; GET /v1/audio/voices")
    with _infer_lock:
        samples, sr = k.create(text, voice=voice, speed=speed, lang=lang_for(voice))
    return samples, sr


def wav_bytes(samples, sr: int) -> bytes:
    import soundfile as sf

    buf = io.BytesIO()
    sf.write(buf, samples, sr, format="WAV", subtype="PCM_16")
    return buf.getvalue()


def pcm_bytes(samples) -> bytes:
    import numpy as np

    return (np.clip(samples, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()


def mp3_bytes(samples, sr: int) -> bytes:
    raw = pcm_bytes(samples)
    proc = subprocess.run(
        ["ffmpeg", "-v", "error", "-f", "s16le", "-ar", str(sr), "-ac", "1",
         "-i", "pipe:0", "-f", "mp3", "-b:a", "128k", "pipe:1"],
        input=raw, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    if proc.returncode != 0:
        raise ValueError(proc.stderr.decode("utf-8", "replace")[:300] or "ffmpeg failed")
    return proc.stdout


class Handler(BaseHTTPRequestHandler):
    server_version = "voice-tts/1"
    token: str = ""
    access_log: bool = True

    def log_message(self, fmt, *args):  # one line per request, no timestamp noise
        if Handler.access_log:
            sys.stderr.write("%s %s\n" % (self.address_string(), fmt % args))

    def log_request(self, code="-", size="-"):
        """The request line plus what a speech request was: size, voice, time.

        Never the text: the log is a journal anyone in the session can read.
        """
        extra = getattr(self, "_speech", None)
        if extra is None:
            return super().log_request(code, size)
        self.log_message('"%s" %s %s', self.requestline, str(code), extra)

    def handle_one_request(self):
        """Serve one request; a client that has gone is a normal event.

        `say --stop` kills the client while the service may still be writing
        the sentence it asked for. The write raised BrokenPipeError out of the
        handler, and socketserver printed a traceback for each one.
        """
        self._speech = None
        try:
            super().handle_one_request()
        except (BrokenPipeError, ConnectionResetError):
            self.close_connection = True
            self.log_message('"%s" client gone before the reply was written',
                             getattr(self, "requestline", "-"))

    def _json(self, code: int, obj: dict):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _authorised(self) -> bool:
        if not Handler.token:
            return True
        got = self.headers.get("Authorization", "")
        return got == f"Bearer {Handler.token}"

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/health":
            m = get_model()
            return self._json(
                200,
                {"ok": True, "model": MODEL_ID, "voices": len(_voices), "default": DEFAULT_VOICE,
                 "sample_rate": 24000},
            )
        if not self._authorised():
            return self._json(401, {"error": {"message": "bad token"}})
        if path == "/v1/models":
            return self._json(
                200,
                {"object": "list",
                 "data": [{"id": MODEL_ID, "object": "model", "owned_by": "local"}]},
            )
        if path == "/v1/audio/voices":
            get_model()
            return self._json(200, {"voices": _voices, "default": DEFAULT_VOICE})
        return self._json(404, {"error": {"message": "not found"}})

    def do_POST(self):
        path = self.path.split("?")[0]
        if not self._authorised():
            return self._json(401, {"error": {"message": "bad token"}})
        if path != "/v1/audio/speech":
            return self._json(404, {"error": {"message": "not found"}})

        length = int(self.headers.get("Content-Length") or 0)
        if length > 1 << 20:
            return self._json(413, {"error": {"message": "body too large"}})
        try:
            req = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError as exc:
            return self._json(400, {"error": {"message": f"bad json: {exc}"}})

        text = (req.get("input") or "").strip()
        if not text:
            return self._json(400, {"error": {"message": "input is required"}})
        if len(text) > MAX_CHARS:
            return self._json(
                413, {"error": {"message": f"input longer than {MAX_CHARS} characters"}}
            )

        voice = req.get("voice") or DEFAULT_VOICE
        speed = float(req.get("speed") or 1.0)
        fmt = (req.get("response_format") or "wav").lower()

        t0 = time.perf_counter()
        try:
            samples, sr = synthesise(text, voice, speed)
            if fmt == "wav":
                body, ctype = wav_bytes(samples, sr), "audio/wav"
            elif fmt == "pcm":
                body, ctype = pcm_bytes(samples), "audio/pcm"
            elif fmt == "mp3":
                body, ctype = mp3_bytes(samples, sr), "audio/mpeg"
            else:
                return self._json(400, {"error": {"message": f"unsupported format {fmt}"}})
        except ValueError as exc:
            return self._json(400, {"error": {"message": str(exc)}})
        except Exception as exc:  # noqa: BLE001 - a failed synthesis must not kill the service
            return self._json(500, {"error": {"message": f"{type(exc).__name__}: {exc}"}})

        ms = (time.perf_counter() - t0) * 1000
        self._speech = f"chars={len(text)} voice={voice} format={fmt} synth_ms={ms:.0f}"
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-Synthesis-Ms", f"{ms:.0f}")
        self.end_headers()
        self.wfile.write(body)


def serve(host: str, port: int, token: str):
    Handler.token = token
    get_model()  # fail fast, and pay the load before the first request
    httpd = ThreadingHTTPServer((host, port), Handler)
    print(f"voice-tts on http://{host}:{port}  model={MODEL_ID}  voice={DEFAULT_VOICE}",
          file=sys.stderr)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()


def selftest(text: str, voice: str, out: str | None):
    t0 = time.perf_counter()
    samples, sr = synthesise(text, voice, 1.0)
    wall = time.perf_counter() - t0
    dur = len(samples) / sr
    print(f"{MODEL_ID} voice={voice} {len(text)} chars -> {dur:.2f}s audio "
          f"in {wall * 1000:.0f}ms ({dur / wall:.2f}x realtime)")
    if out:
        with open(out, "wb") as fh:
            fh.write(wav_bytes(samples, sr))
        print(f"wrote {out}")


def read_token(args) -> str:
    if args.token:
        return args.token
    if args.token_file:
        with open(os.path.expanduser(args.token_file)) as fh:
            return fh.read().strip()
    return os.environ.get("VOICE_TTS_TOKEN", "")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="OpenAI-compatible local TTS")
    sub = ap.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("serve", help="run the HTTP service")
    s.add_argument("--host", default="0.0.0.0")
    s.add_argument("--port", type=int, default=8001)
    s.add_argument("--token")
    s.add_argument("--token-file")

    t = sub.add_parser("selftest", help="synthesise without HTTP")
    t.add_argument("text")
    t.add_argument("-o", "--out")
    t.add_argument("--voice", default=DEFAULT_VOICE)

    args = ap.parse_args(argv)
    if args.cmd == "serve":
        serve(args.host, args.port, read_token(args))
    else:
        selftest(args.text, args.voice, args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
