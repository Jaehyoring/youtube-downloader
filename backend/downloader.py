import yt_dlp
import asyncio
import json
import os
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


_COOKIES_OPTS = None  # type: Optional[dict]

def _get_browser_cookies_opts() -> dict:
    """YouTube 세션 쿠키를 가진 브라우저를 자동 탐지 (최초 1회만 실행)"""
    global _COOKIES_OPTS
    if _COOKIES_OPTS is not None:
        return _COOKIES_OPTS

    import tempfile
    for browser in ("chrome", "firefox"):
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
                # 로그인 세션 쿠키 확인
                if any(c in content for c in ("SID\t", "LOGIN_INFO\t", "__Secure-3PSID\t")):
                    print(f"[cookies] YouTube 로그인 세션 발견: {browser}")
                    _COOKIES_OPTS = {"cookiesfrombrowser": (browser, None, None, None)}
                    return _COOKIES_OPTS
        except Exception:
            pass

    # 로그인 세션 없음 - 익명 Chrome 쿠키 사용
    print("[cookies] YouTube 로그인 세션 없음. Chrome 익명 쿠키 사용")
    _COOKIES_OPTS = {"cookiesfrombrowser": ("chrome", None, None, None)}
    return _COOKIES_OPTS


def get_video_info(url: str) -> dict:
    cookies_opts = _get_browser_cookies_opts()
    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "extract_flat": False,
        "js_runtimes": {"node": {"path": "/usr/local/bin/node"}},
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
            payload = {"status": "processing"}
            loop.call_soon_threadsafe(progress_queue.put_nowait, payload)

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

    # 브라우저 쿠키 선택 (YouTube 로그인 세션 필요)
    cookies_opts = _get_browser_cookies_opts()

    ydl_opts = {
        "format": format_selector,
        "outtmpl": outtmpl,
        "progress_hooks": [progress_hook],
        "postprocessors": postprocessors,
        "quiet": True,
        "no_warnings": True,
        "ffmpeg_location": "/opt/homebrew/bin",
        "merge_output_format": format_type if format_type != "mp3" else None,
        # Node.js로 YouTube JS 챌린지(nsig/sig) 해결 - yt-dlp 2026.02.21 필요
        "js_runtimes": {"node": {"path": "/usr/local/bin/node"}},
        **cookies_opts,
    }

    result = {"filepath": None, "title": None, "error": None}

    def run_download():
        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=True)
                filename = ydl.prepare_filename(info)
                # mp3의 경우 확장자 변경
                if format_type == "mp3":
                    filename = os.path.splitext(filename)[0] + ".mp3"
                result["filepath"] = filename
                result["title"] = info.get("title", "Unknown")
        except Exception as e:
            result["error"] = str(e)
        finally:
            loop.call_soon_threadsafe(progress_queue.put_nowait, {"status": "done"})

    # 별도 스레드에서 다운로드 실행
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
