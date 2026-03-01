const BASE = "http://localhost:8000";

export async function fetchVideoInfo(url) {
  const res = await fetch(`${BASE}/api/info?url=${encodeURIComponent(url)}`);
  if (!res.ok) {
    const err = await res.json();
    throw new Error(err.detail || "영상 정보를 가져오지 못했습니다.");
  }
  return res.json();
}

export async function fetchHistory() {
  const res = await fetch(`${BASE}/api/history`);
  if (!res.ok) throw new Error("이력을 불러오지 못했습니다.");
  return res.json();
}

export async function openFile(path) {
  await fetch(`${BASE}/api/open?path=${encodeURIComponent(path)}`);
}

export async function deleteHistoryItem(index) {
  await fetch(`${BASE}/api/history/${index}`, { method: "DELETE" });
}

export async function clearHistory() {
  await fetch(`${BASE}/api/history`, { method: "DELETE" });
}

export function startDownload(url, formatType, quality, onProgress, onComplete, onError) {
  const controller = new AbortController();

  fetch(`${BASE}/api/download`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ url, format_type: formatType, quality }),
    signal: controller.signal,
  }).then(async (res) => {
    if (!res.ok) {
      onError("다운로드 요청에 실패했습니다.");
      return;
    }
    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n\n");
      buffer = lines.pop();

      for (const line of lines) {
        const dataLine = line.replace(/^data: /, "").trim();
        if (!dataLine) continue;
        try {
          const payload = JSON.parse(dataLine);
          if (payload.status === "downloading") {
            onProgress(payload);
          } else if (payload.status === "processing") {
            onProgress({ status: "processing", percent: 99 });
          } else if (payload.status === "complete") {
            onComplete(payload);
          } else if (payload.status === "error") {
            onError(payload.message);
          }
        } catch (_) {}
      }
    }
  }).catch((err) => {
    if (err.name !== "AbortError") onError(err.message);
  });

  return () => controller.abort();
}
