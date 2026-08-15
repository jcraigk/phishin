import React, { useRef, useState } from "react";

const WaveformScrubber = ({
  waveformUrl,
  duration,
  markers = [],
  onMarkerChange,
  playheadSeconds,
  onSeek,
}) => {
  const containerRef = useRef(null);
  const [dragging, setDragging] = useState(null);

  const span = duration > 0 ? duration : 1;

  const secondsAt = (clientX) => {
    const rect = containerRef.current.getBoundingClientRect();
    const x = Math.min(Math.max(clientX - rect.left, 0), rect.width);
    return (x / rect.width) * span;
  };

  const leftPercent = (seconds) =>
    `${Math.min(Math.max(seconds / span, 0), 1) * 100}%`;

  return (
    <div
      ref={containerRef}
      className="waveform-scrubber"
      onMouseMove={(e) => {
        if (dragging && onMarkerChange) onMarkerChange(dragging, secondsAt(e.clientX));
      }}
      onMouseUp={() => setDragging(null)}
      onMouseLeave={() => setDragging(null)}
      onClick={(e) => {
        if (!dragging && onSeek) onSeek(secondsAt(e.clientX));
      }}
    >
      {waveformUrl ? (
        <img src={waveformUrl} alt="Track waveform" draggable={false} />
      ) : (
        <div className="wf-placeholder">No waveform</div>
      )}
      {playheadSeconds != null && (
        <div className="wf-playhead" style={{ left: leftPercent(playheadSeconds) }} />
      )}
      {markers.map((m) => (
        <div
          key={m.name}
          className="wf-marker"
          style={{ left: leftPercent(m.seconds), background: m.color }}
          onMouseDown={(e) => {
            e.stopPropagation();
            setDragging(m.name);
          }}
        >
          <span>{m.name}</span>
        </div>
      ))}
    </div>
  );
};

export default WaveformScrubber;
