import { formatFileSize } from "../utils";
import { openFile, deleteHistoryItem, clearHistory } from "../api";

export default function HistoryList({ history, onHistoryChange }) {
  if (!history || history.length === 0) return null;

  const handleDelete = async (idx) => {
    await deleteHistoryItem(idx);
    onHistoryChange();
  };

  const handleClearAll = async () => {
    await clearHistory();
    onHistoryChange();
  };

  return (
    <div className="history-section">
      <div className="history-header">
        <h2 className="history-title">최근 다운로드</h2>
        <button className="btn-clear-all" onClick={handleClearAll}>
          전체 삭제
        </button>
      </div>
      <ul className="history-list">
        {history.map((item, idx) => (
          <li key={idx} className="history-item">
            <div className="history-item-info">
              <span className="history-format-badge">{item.format.toUpperCase()}</span>
              <div className="history-text">
                <p className="history-item-title">{item.title}</p>
                <p className="history-item-meta">
                  {item.downloaded_at} &middot; {formatFileSize(item.filesize)}
                </p>
              </div>
            </div>
            <div className="history-actions">
              <button
                className="btn-open"
                onClick={() => openFile(item.filepath)}
                title="Finder에서 열기"
              >
                열기
              </button>
              <button
                className="btn-delete"
                onClick={() => handleDelete(idx)}
                title="목록에서 삭제"
              >
                ✕
              </button>
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}
