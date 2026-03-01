import { useState, useEffect, useRef } from "react";
import { fetchVideoInfo, fetchHistory, startDownload } from "./api";
import VideoInfo from "./components/VideoInfo";
import ProgressBar from "./components/ProgressBar";
import HistoryList from "./components/HistoryList";

const FORMAT_OPTIONS = [
  { value: "mp4", label: "MP4 (영상)" },
  { value: "webm", label: "WebM (영상)" },
  { value: "mp3", label: "MP3 (오디오만)" },
];

const QUALITY_OPTIONS = [
  { value: "best", label: "최고화질" },
  { value: "1080p", label: "1080p" },
  { value: "720p", label: "720p" },
  { value: "480p", label: "480p" },
  { value: "360p", label: "360p" },
];

export default function App() {
  const [url, setUrl] = useState("");
  const [formatType, setFormatType] = useState("mp4");
  const [quality, setQuality] = useState("best");

  const [videoInfo, setVideoInfo] = useState(null);
  const [infoLoading, setInfoLoading] = useState(false);
  const [infoError, setInfoError] = useState("");

  const [downloadState, setDownloadState] = useState("idle"); // idle | downloading | complete | error
  const [progress, setProgress] = useState(null);
  const [completeInfo, setCompleteInfo] = useState(null);
  const [downloadError, setDownloadError] = useState("");

  const [history, setHistory] = useState([]);

  const abortRef = useRef(null);

  useEffect(() => {
    fetchHistory().then(setHistory).catch(() => {});
  }, []);

  const handleUrlChange = (e) => {
    setUrl(e.target.value);
    setVideoInfo(null);
    setInfoError("");
    setDownloadState("idle");
    setProgress(null);
    setCompleteInfo(null);
  };

  const handleFetchInfo = async () => {
    if (!url.trim()) return;
    setInfoLoading(true);
    setInfoError("");
    setVideoInfo(null);
    setDownloadState("idle");
    setProgress(null);
    setCompleteInfo(null);
    try {
      const info = await fetchVideoInfo(url.trim());
      setVideoInfo(info);
    } catch (err) {
      setInfoError(err.message);
    } finally {
      setInfoLoading(false);
    }
  };

  const handleKeyDown = (e) => {
    if (e.key === "Enter") handleFetchInfo();
  };

  const handleDownload = () => {
    if (!url.trim()) return;
    setDownloadState("downloading");
    setProgress({ status: "downloading", percent: 0 });
    setDownloadError("");

    abortRef.current = startDownload(
      url.trim(),
      formatType,
      quality,
      (p) => setProgress(p),
      (data) => {
        setDownloadState("complete");
        setCompleteInfo(data);
        setProgress(null);
        fetchHistory().then(setHistory).catch(() => {});
      },
      (msg) => {
        setDownloadState("error");
        setDownloadError(msg);
        setProgress(null);
      }
    );
  };

  const handleReset = () => {
    if (abortRef.current) abortRef.current();
    setUrl("");
    setVideoInfo(null);
    setInfoError("");
    setDownloadState("idle");
    setProgress(null);
    setCompleteInfo(null);
    setDownloadError("");
  };

  const isDownloading = downloadState === "downloading";
  const canDownload = url.trim() && !isDownloading;

  return (
    <div className="app">
      <header className="app-header">
        <div className="logo">
          <span className="logo-icon">▶</span>
          <span className="logo-text">YouTube Downloader</span>
        </div>
      </header>

      <main className="app-main">
        <div className="card">
          {/* URL 입력 */}
          <div className="url-row">
            <input
              className="url-input"
              type="text"
              placeholder="YouTube URL을 붙여넣으세요..."
              value={url}
              onChange={handleUrlChange}
              onKeyDown={handleKeyDown}
              disabled={isDownloading}
            />
            <button
              className="btn-primary"
              onClick={handleFetchInfo}
              disabled={!url.trim() || infoLoading || isDownloading}
            >
              {infoLoading ? "로딩..." : "정보 가져오기"}
            </button>
          </div>

          {infoError && <p className="error-msg">{infoError}</p>}

          {/* 영상 정보 */}
          {videoInfo && <VideoInfo info={videoInfo} />}

          {/* 포맷 & 품질 선택 */}
          <div className="options-row">
            <div className="select-group">
              <label>포맷</label>
              <select
                value={formatType}
                onChange={(e) => setFormatType(e.target.value)}
                disabled={isDownloading}
              >
                {FORMAT_OPTIONS.map((o) => (
                  <option key={o.value} value={o.value}>
                    {o.label}
                  </option>
                ))}
              </select>
            </div>

            {formatType !== "mp3" && (
              <div className="select-group">
                <label>해상도</label>
                <select
                  value={quality}
                  onChange={(e) => setQuality(e.target.value)}
                  disabled={isDownloading}
                >
                  {QUALITY_OPTIONS.map((o) => (
                    <option key={o.value} value={o.value}>
                      {o.label}
                    </option>
                  ))}
                </select>
              </div>
            )}

            <button
              className="btn-download"
              onClick={handleDownload}
              disabled={!canDownload}
            >
              {isDownloading ? "다운로드 중..." : "다운로드"}
            </button>
          </div>

          {/* 진행률 */}
          {isDownloading && <ProgressBar progress={progress} />}

          {/* 완료 */}
          {downloadState === "complete" && completeInfo && (
            <div className="complete-banner">
              <span className="complete-icon">✓</span>
              <div className="complete-text">
                <p className="complete-title">다운로드 완료!</p>
                <p className="complete-filename">{completeInfo.filename}</p>
              </div>
              <button className="btn-reset" onClick={handleReset}>
                새로 다운로드
              </button>
            </div>
          )}

          {/* 에러 */}
          {downloadState === "error" && (
            <div className="error-banner">
              <div className="error-content">
                <p className="error-main">{downloadError}</p>
                {(downloadError.includes("403") || downloadError.toLowerCase().includes("empty")) && (
                  <p className="error-hint">
                    Chrome 브라우저에서 YouTube에 로그인한 후 다시 시도하세요.
                  </p>
                )}
              </div>
              <button className="btn-reset" onClick={handleReset}>
                다시 시도
              </button>
            </div>
          )}
        </div>

        {/* 다운로드 이력 */}
        <HistoryList
          history={history}
          onHistoryChange={() => fetchHistory().then(setHistory).catch(() => {})}
        />
      </main>
    </div>
  );
}
