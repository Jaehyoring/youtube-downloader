from fastapi import FastAPI, Query, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import asyncio
import os
import subprocess
import sys

from downloader import get_video_info, download_video, load_history, save_history, DOWNLOADS_DIR

app = FastAPI(title="YouTube Downloader API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://localhost:4173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class DownloadRequest(BaseModel):
    url: str
    format_type: str = "mp4"   # mp4 | webm | mp3
    quality: str = "best"      # best | 1080p | 720p | 480p | 360p


@app.get("/api/info")
async def video_info(url: str = Query(..., description="YouTube URL")):
    try:
        info = await asyncio.to_thread(get_video_info, url)
        return info
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/api/download")
async def start_download(req: DownloadRequest):
    async def event_stream():
        async for chunk in download_video(req.url, req.format_type, req.quality):
            yield chunk

    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )


@app.get("/api/history")
async def get_history():
    return load_history()


@app.delete("/api/history")
async def clear_history():
    from downloader import HISTORY_FILE
    HISTORY_FILE.write_text("[]", encoding="utf-8")
    return {"ok": True}


@app.delete("/api/history/{index}")
async def delete_history_item(index: int):
    import json
    from downloader import HISTORY_FILE
    history = load_history()
    if index < 0 or index >= len(history):
        raise HTTPException(status_code=404, detail="Item not found")
    history.pop(index)
    with open(HISTORY_FILE, "w", encoding="utf-8") as f:
        json.dump(history, f, ensure_ascii=False, indent=2)
    return {"ok": True}


@app.get("/api/open")
async def open_file(path: str = Query(..., description="File path to open")):
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="File not found")
    try:
        if sys.platform == "darwin":
            subprocess.Popen(["open", "-R", path])
        elif sys.platform == "win32":
            subprocess.Popen(["explorer", "/select,", path])
        else:
            subprocess.Popen(["xdg-open", os.path.dirname(path)])
        return {"ok": True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/health")
async def health():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000, reload=True)
