import yt_dlp
import asyncio
import json
import os
import shutil
import sys
import time
from pathlib import Path
from typing import AsyncGenerator, Optional

DOWNLOADS_DIR = Path(__file__).parent.parent / "downloads"
DOWNLOADS_DIR.mkdir(exist_ok=True)

HISTORY_FILE = DOWNLOADS_DIR / ".history.json"


def load_history() -> list:
    if not HISTORY_FILE.exists():
        return []
    try:
        with open(HISTORY_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return []


def save_history(entry: dict):
    history = load_history()
    history.insert(0, entry)
    history = history[:50]  # 최대 50개 유지
    with open(HISTORY_FILE, "w", encoding="utf-8") as f:
        json.dump(history, f, ensure_ascii=False, indent=2)


# ── OS별 실행 파일 경로 자동 탐지 ─────────────────────────────────────────────

def _find_node() -> str:
    """Node.js 실행 파일 경로 자동 탐지 (macOS / Windows 공통)"""
    # 1순위: PATH에서 찾기
    node = shutil.which("node")
    if node:
        return node

    # 2순위: OS별 일반 경로
    if sys.platform == "darwin":
        candidates = [
            "/opt/homebrew/bin/node",   # Apple Silicon Mac
            "/usr/local/bin/node",      # Intel Mac (Homebrew)
        ]
    elif sys.platform == "win32":
        candidates = [
            r"C:\Program Files\nodejs\node.exe",
            r"C:\Program Files (x86)\nodejs\node.exe",
            os.path.expandvars(r"%APPDATA%\npm\node.exe"),
            os.path.expandvars(r"%ProgramFiles%\nodejs\node.exe"),
        ]
    else:
        candidates = ["/usr/bin/node", "/usr/local/bin/node"]

    for path in candidates:
        if os.path.isfile(path):
            return path

    return "node"  # fallback — PATH에 있을 것으로 기대


def _find_ffmpeg_dir() -> str:
    """ffmpeg 디렉토리 자동 탐지 (macOS / Windows 공통)"""
    # 1순위: PATH에서 찾기
    ffmpeg_bin = "ffmpeg.exe" if sys.platform == "win32" else "ffmpeg"
    ffmpeg = shutil.which(ffmpeg_bin)
    if ffmpeg:
        return str(Path(ffmpeg).parent)

    # 2순위: OS별 일반 경로
    if sys.platform == "darwin":
        candidates = [
            "/opt/homebrew/bin",   # Apple Silicon Mac
            "/usr/local/bin",      # Intel Mac
        ]
    elif sys.platform == "win32":
        candidates = [
            r"C:\ffmpeg\bin",
            r"C:\ProgramData\chocolatey\bin",
            os.path.expandvars(r"%ProgramFiles%\ffmpeg\bin"),
        ]
    else:
        candidates = ["/usr/bin", "/usr/local/bin"]

    for path in candidates:
        if os.path.isfile(os.path.join(path, ffmpeg_bin)):
            return path

    return ""  # yt-dlp가 PATH에서 직접 탐색


NODE_PATH = _find_node()
FFMPEG_DIR = _find_ffmpeg_dir()

print(f"[config] Node.js: {NODE_PATH}")
print(f"[config] ffmpeg: {FFMPEG_DIR or '(PATH에서 탐색)'}")


# ── 브라우저 쿠키 탐지 ─────────────────────────────────────────────────────────

_COOKIES_OPTS = None  # type: Optional[dict]

def _get_browser_cookies_opts() -> dict:
    """YouTube 세션 쿠키를 가진 브라우저를 자동 탐지 (최초 1회만 실행)"""
    global _COOKIES_OPTS
    if _COOKIES_OPTS is not None:
        return _COOKIES_OPTS

    import tempfile

    # Windows는 Edge도 지원 (기본 브라우저)
    browsers = ("chrome", "edge", "firefox") if sys.platform == "win32" else ("chrome", "firefox")

    for browser in browsers:
        try:
            tmp = tempfile.mktemp(suffix=".txt")
            test_opts = {
                "quiet": True,
                "no_warnings": True,
                "cookiesfrombrowser": (browser, None, None, None),
                "cookiefile": tmp,
            }
            with yt_dlp.YoutubeDL(test_opts) as ydl:
                ydl.extract_info("https://www.youtube.com/watch?v=dQw4w9WgXcQ", download=False)
            if os.path.exists(tmp):
                content = open(tmp).read()
                os.unlink(tmp)
                if any(c in content for c in ("SID\t", "LOGIN_INFO\t", "__Secure-3PSID\t")):
                    print(f"[cookies] YouTube 로그인 세션 발견: {browser}")
                    _COOKIES_OPTS = {"cookiesfrombrowser": (browser, None, None, None)}
                    return _COOKIES_OPTS
        except Exception:
            pass

    print("[cookies] YouTube 로그인 세션 없음. Chrome 익명 쿠키 사용")
    _COOKIES_OPTS = {"cookiesfrombrowser": ("chrome", None, None, None)}
    return _COOKIES_OPTS


# ── 공통 yt-dlp 기본 옵션 ─────────────────────────────────────────────────────

def _base_ydl_opts() -> dict:
    opts = {
        "quiet": True,
        "no_warnings": True,
        "js_runtimes": {"node": {"path": NODE_PATH}},
    }
    if FFMPEG_DIR:
        opts["ffmpeg_location"] = FFMPEG_DIR
    return opts


# ── 영상 정보 조회 ─────────────────────────────────────────────────────────────

def get_video_info(url: str) -> dict:
    cookies_opts = _get_browser_cookies_opts()
    ydl_opts = {
        **_base_ydl_opts(),
        "extract_flat": False,
        **cookies_opts,
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=False)
        formats = []
        seen = set()
        for f in info.get("formats", []):
            height = f.get("height")
            ext = f.get("ext")
            if height and ext in ("mp4", "webm") and height not in seen:
                seen.add(height)
                formats.append({
                    "format_id": f["format_id"],
                    "height": height,
                    "ext": ext,
                    "label": f"{height}p",
                })
        formats.sort(key=lambda x: x["height"], reverse=True)

        return {
            "title": info.get("title", "Unknown"),
            "thumbnail": info.get("thumbnail", ""),
            "duration": info.get("duration", 0),
            "channel": info.get("uploader", ""),
            "formats": formats,
        }


# ── 다운로드 ───────────────────────────────────────────────────────────────────

async def download_video(
    url: str,
    format_type: str,
    quality: str,
) -> AsyncGenerator[str, None]:
    """SSE 스트림으로 진행률을 yield하며 다운로드"""
    loop = asyncio.get_event_loop()
    progress_queue: asyncio.Queue = asyncio.Queue()

    def progress_hook(d):
        if d["status"] == "downloading":
            downloaded = d.get("downloaded_bytes", 0)
            total = d.get("total_bytes") or d.get("total_bytes_estimate", 0)
            speed = d.get("speed", 0) or 0
            percent = (downloaded / total * 100) if total else 0
            payload = {
                "status": "downloading",
                "percent": round(percent, 1),
                "downloaded": downloaded,
                "total": total,
                "speed": speed,
            }
            loop.call_soon_threadsafe(progress_queue.put_nowait, payload)
        elif d["status"] == "finished":
            loop.call_soon_threadsafe(progress_queue.put_nowait, {"status": "processing"})

    # 포맷 옵션 결정
    if format_type == "mp3":
        format_selector = "bestaudio/best"
        postprocessors = [{
            "key": "FFmpegExtractAudio",
            "preferredcodec": "mp3",
            "preferredquality": "192",
        }]
        outtmpl = str(DOWNLOADS_DIR / "%(title)s.%(ext)s")
    else:
        if quality == "best":
            format_selector = (
                f"bestvideo[ext={format_type}]+bestaudio/best"
                f"/bestvideo+bestaudio/best"
            )
        else:
            height = quality.replace("p", "")
            format_selector = (
                f"bestvideo[height<={height}][ext={format_type}]+bestaudio/best"
                f"/bestvideo[height<={height}]+bestaudio/best"
                f"/best[height<={height}]/best"
            )
        postprocessors = []
        outtmpl = str(DOWNLOADS_DIR / "%(title)s.%(ext)s")

    cookies_opts = _get_browser_cookies_opts()

    ydl_opts = {
        **_base_ydl_opts(),
        "format": format_selector,
        "outtmpl": outtmpl,
        "progress_hooks": [progress_hook],
        "postprocessors": postprocessors,
        "merge_output_format": format_type if format_type != "mp3" else None,
        **cookies_opts,
    }

    result = {"filepath": None, "title": None, "error": None}

    def run_download():
        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=True)
                filename = ydl.prepare_filename(info)
                if format_type == "mp3":
                    filename = os.path.splitext(filename)[0] + ".mp3"
                result["filepath"] = filename
                result["title"] = info.get("title", "Unknown")
        except Exception as e:
            result["error"] = str(e)
        finally:
            loop.call_soon_threadsafe(progress_queue.put_nowait, {"status": "done"})

    download_task = loop.run_in_executor(None, run_download)

    while True:
        payload = await progress_queue.get()
        yield f"data: {json.dumps(payload)}\n\n"
        if payload["status"] == "done":
            break

    await download_task

    if result["error"]:
        yield f"data: {json.dumps({'status': 'error', 'message': result['error']})}\n\n"
    else:
        filepath = result["filepath"]
        filesize = os.path.getsize(filepath) if filepath and os.path.exists(filepath) else 0
        entry = {
            "title": result["title"],
            "filepath": filepath,
            "filename": os.path.basename(filepath) if filepath else "",
            "filesize": filesize,
            "format": format_type,
            "quality": quality,
            "downloaded_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        }
        save_history(entry)
        yield f"data: {json.dumps({'status': 'complete', **entry})}\n\n"
