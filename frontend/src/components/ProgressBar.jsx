import { formatFileSize, formatSpeed } from "../utils";

export default function ProgressBar({ progress }) {
  if (!progress) return null;

  const { status, percent = 0, downloaded, total, speed } = progress;
  const isProcessing = status === "processing";

  return (
    <div className="progress-wrapper">
      <div className="progress-bar-track">
        <div
          className={`progress-bar-fill ${isProcessing ? "processing" : ""}`}
          style={{ width: `${percent}%` }}
        />
      </div>
      <div className="progress-info">
        {isProcessing ? (
          <span>변환 중...</span>
        ) : (
          <>
            <span>{percent.toFixed(1)}%</span>
            <span>
              {formatFileSize(downloaded)} / {formatFileSize(total)}
            </span>
            <span>{formatSpeed(speed)}</span>
          </>
        )}
      </div>
    </div>
  );
}
