import { formatDuration } from "../utils";

export default function VideoInfo({ info }) {
  if (!info) return null;

  return (
    <div className="video-info">
      <img
        className="video-thumbnail"
        src={info.thumbnail}
        alt="thumbnail"
      />
      <div className="video-meta">
        <p className="video-title">{info.title}</p>
        <p className="video-channel">{info.channel}</p>
        <p className="video-duration">재생 시간: {formatDuration(info.duration)}</p>
      </div>
    </div>
  );
}
