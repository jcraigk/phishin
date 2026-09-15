import React, { useEffect, useRef, useState } from "react";

const WaveformScrubber = ({
  waveformUrl,
  duration,
  markers = [],
  onMarkerChange,
  onMarkerCommit,
  playheadSeconds,
  onSeek,
  range,
  peaks,
}) => {
  const containerRef = useRef(null);
  const canvasRef = useRef(null);
  const [dragging, setDragging] = useState(null);
  const justDraggedRef = useRef(false);

  const span = duration > 0 ? duration : 1;

  // With peak data the waveform is drawn here for whatever window the caller
  // shows: `peaks.data` is one byte per 1/rate seconds over the whole
  // timeline and `peaks.offset` is where this window starts in it. Each pixel
  // column takes the loudest peak it covers, so nothing brief disappears.
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !peaks?.data) return;
    const width = canvas.width;
    const height = canvas.height;
    const ctx = canvas.getContext("2d");
    ctx.clearRect(0, 0, width, height);
    ctx.fillStyle = peaks.color || "#8a8c90";
    const { data, rate, offset = 0 } = peaks;
    const perPixel = (span * rate) / width;
    for (let x = 0; x < width; x += 1) {
      const from = Math.floor(offset * rate + x * perPixel);
      const to = Math.max(from + 1, Math.floor(offset * rate + (x + 1) * perPixel));
      let peak = 0;
      for (let i = from; i < to && i < data.length; i += 1) {
        if (data[i] > peak) peak = data[i];
      }
      const bar = Math.max(1, (peak / 255) * height);
      ctx.fillRect(x, (height - bar) / 2, 1, bar);
    }
  }, [peaks, span]);

  const secondsAt = (clientX) => {
    const rect = containerRef.current.getBoundingClientRect();
    const x = Math.min(Math.max(clientX - rect.left, 0), rect.width);
    return (x / rect.width) * span;
  };

  // A drag follows the mouse anywhere on the page, so leaving the (short)
  // scrubber strip mid-drag neither drops the marker nor ends the drag early.
  // The release is remembered so the click it also produces does not seek.
  useEffect(() => {
    if (!dragging) return undefined;
    const onMove = (e) => {
      if (onMarkerChange) onMarkerChange(dragging, secondsAt(e.clientX));
    };
    const onUp = () => {
      justDraggedRef.current = true;
      if (onMarkerCommit) onMarkerCommit(dragging);
      setDragging(null);
    };
    window.addEventListener("mousemove", onMove);
    window.addEventListener("mouseup", onUp);
    return () => {
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("mouseup", onUp);
    };
  });

  const leftPercent = (seconds) =>
    `${Math.min(Math.max(seconds / span, 0), 1) * 100}%`;

  return (
    <div
      ref={containerRef}
      className="waveform-scrubber"
      onClick={(e) => {
        if (justDraggedRef.current) {
          justDraggedRef.current = false;
          return;
        }
        if (!dragging && onSeek) onSeek(secondsAt(e.clientX));
      }}
    >
      {waveformUrl ? (
        <img src={waveformUrl} alt="Track waveform" draggable={false} />
      ) : peaks?.data ? (
        <canvas ref={canvasRef} className="wf-canvas" width={1600} height={80} />
      ) : (
        <div className="wf-placeholder" />
      )}
      {range && (
        <>
          <div className="wf-shade" style={{ left: 0, width: leftPercent(range.start) }} />
          <div className="wf-shade" style={{ left: leftPercent(range.end), right: 0 }} />
          {(range.segments || []).map((seg) => (
            <div
              key={seg.name}
              className={`wf-segment is-${seg.side}${seg.boundary ? " has-boundary" : ""}`}
              style={{ left: leftPercent(seg.start), width: `${Math.max(0, ((seg.end - seg.start) / span) * 100)}%` }}
            >
              <span>{seg.label}</span>
            </div>
          ))}
        </>
      )}
      {(range?.guides || []).map((g) => (
        <div key={g.name} className={`wf-guide${g.origin ? " is-origin" : ""}${g.kind ? ` is-${g.kind}` : ""}${g.seconds / span > 0.9 ? " is-near-end" : ""}`} style={{ left: leftPercent(g.seconds) }}>
          {g.label && <span>{g.label}</span>}
        </div>
      ))}
      {(range?.shifts || []).map((s) => (
        <div
          key={s.name}
          className={`wf-shift${s.settled ? " is-settled" : ""}${s.kind ? ` is-${s.kind}` : ""}`}
          style={{ left: leftPercent(s.start), width: `${Math.max(0, ((s.end - s.start) / span) * 100)}%` }}
        />
      ))}
      {(range?.cuts || []).map((c) => (
        <div
          key={c.name}
          className="wf-cut"
          style={{ left: leftPercent(c.start), width: `${Math.max(0, ((c.end - c.start) / span) * 100)}%` }}
        />
      ))}
      {playheadSeconds != null && (
        <div className="wf-playhead" style={{ left: leftPercent(playheadSeconds) }} />
      )}
      {markers.map((m) => (
        <div
          key={m.name}
          className={`wf-marker${m.seam ? " is-seam" : ""}${m.seconds / span > 0.9 ? " is-near-end" : ""}`}
          style={{ left: leftPercent(m.seconds), background: m.color }}
          onMouseDown={(e) => {
            e.stopPropagation();
            setDragging(m.name);
          }}
        >
          <span>{m.label || m.name}</span>
        </div>
      ))}
    </div>
  );
};

export default WaveformScrubber;
