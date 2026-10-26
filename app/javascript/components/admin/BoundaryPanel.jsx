import React, { useContext, useEffect, useRef, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import {
  faCheck,
  faLocationCrosshairs,
  faPause,
  faPlay,
  faXmark,
} from "@fortawesome/free-solid-svg-icons";
import Spinner from "./Spinner";
import { EditorContext } from "./AdminShowEditor";
import useJobRunner from "./useJobRunner";
import { adminPost } from "./adminApi";
import { round1 } from "./stagingMath";
import { BoundaryPlayer } from "./BoundaryPlayer";

const MIN_PART_S = 1.0;

const seconds = (ms) => round1((ms || 0) / 1000);

const BoundaryPanel = ({ track, next, onClose }) => {
  const { show, reload, setGapsStale } = useContext(EditorContext);
  const [deltaS, setDeltaS] = useState(0);
  const [dragging, setDragging] = useState(false);
  const [position, setPosition] = useState({ index: 0, offset: 0 });
  const [playing, setPlaying] = useState(false);
  const [loading, setLoading] = useState(false);
  const containerRef = useRef(null);
  const playerRef = useRef(null);
  const suppressClickRef = useRef(false);
  const { run, cancel, busy, status, error, setError } = useJobRunner();

  const firstSeconds = seconds(track.duration);
  const secondSeconds = seconds(next.duration);
  const total = firstSeconds + secondSeconds;
  const low = round1(MIN_PART_S - firstSeconds);
  const high = round1(secondSeconds - MIN_PART_S);
  const delta = Number.isFinite(deltaS) ? deltaS : 0;
  const inRange = delta >= low && delta <= high;

  const changeDelta = (value) => {
    setDeltaS(round1(value));
    setError(null);
  };

  const secondsAt = (clientX) => {
    const rect = containerRef.current.getBoundingClientRect();
    const x = Math.min(Math.max(clientX - rect.left, 0), rect.width);
    return (x / rect.width) * total;
  };

  const dragTo = (clientX) => {
    const raw = secondsAt(clientX) - firstSeconds;
    changeDelta(Math.min(Math.max(raw, low), high));
  };

  useEffect(() => {
    const player = new BoundaryPlayer({
      urls: [track.mp3_url, next.mp3_url],
      onTime: setPosition,
      onPlayChange: setPlaying,
      onLoading: setLoading,
      onError: (e) => setError(e.message),
    });
    playerRef.current = player;
    setPosition({ index: 0, offset: 0 });
    setPlaying(false);
    player.load().catch(() => {});
    return () => {
      player.destroy();
      if (playerRef.current === player) playerRef.current = null;
    };
  }, [track.mp3_url, next.mp3_url]);

  const playhead = position.index === 0 ? position.offset : firstSeconds + position.offset;

  const playFrom = (index, offset) => {
    setPosition({ index, offset });
    if (playerRef.current) playerRef.current.play(index, offset);
  };

  const seekTo = (combined) => {
    const target =
      combined < firstSeconds
        ? { index: 0, offset: combined }
        : { index: 1, offset: combined - firstSeconds };
    if (playing) playFrom(target.index, target.offset);
    else setPosition(target);
  };

  const togglePlay = () => {
    const player = playerRef.current;
    if (!player) return;
    if (player.isPlaying()) player.pause();
    else player.play(position.index, position.offset);
  };

  const firstDecoded = () => playerRef.current?.duration(0) ?? firstSeconds;

  const playFromBoundary = () => {
    if (delta >= 0) playFrom(1, delta);
    else playFrom(0, Math.max(firstDecoded() + delta, 0));
  };

  useEffect(() => {
    const onKeyDown = (e) => {
      if (e.key !== " " || e.shiftKey) return;
      const active = document.activeElement;
      if (["INPUT", "TEXTAREA", "SELECT"].includes(active?.tagName) || active?.isContentEditable) return;
      e.preventDefault();
      e.stopPropagation();
      togglePlay();
    };
    window.addEventListener("keydown", onKeyDown, true);
    return () => window.removeEventListener("keydown", onKeyDown, true);
  });

  const applyShift = () => {
    const message =
      `Move the boundary between "${track.title}" and "${next.title}" by ` +
      `${delta.toFixed(1)}s? Both original audio files are backed up.`;
    if (!window.confirm(message)) return;
    run(
      () => adminPost(`/tracks/${track.id}/shift_boundary_apply`, { delta_s: delta }),
      async () => {
        setDeltaS(0);
        await reload();
        if (show.published) setGapsStale(true);
      }
    );
  };

  const hereDelta = round1(
    position.index === 1 ? position.offset : position.offset - firstDecoded()
  );
  const hereValid = hereDelta >= low && hereDelta <= high && hereDelta !== delta;

  const boundaryPercent = `${Math.min(Math.max((firstSeconds + delta) / total, 0), 1) * 100}%`;

  return (
    <div className="admin-audio-panel">
      <h4>Move Boundary</h4>

      <div
        ref={containerRef}
        className="waveform-scrubber admin-boundary-scrubber"
        onMouseMove={(e) => {
          if (dragging) dragTo(e.clientX);
        }}
        onMouseUp={() => {
          if (dragging) suppressClickRef.current = true;
          setDragging(false);
        }}
        onMouseLeave={() => setDragging(false)}
        onClick={(e) => {
          if (suppressClickRef.current) {
            suppressClickRef.current = false;
            return;
          }
          seekTo(secondsAt(e.clientX));
        }}
      >
        <div className="admin-boundary-waves">
          <img
            src={track.waveform_url}
            alt={`Waveform of ${track.title}`}
            style={{ width: `${(firstSeconds / total) * 100}%` }}
            draggable={false}
          />
          <img
            src={next.waveform_url}
            alt={`Waveform of ${next.title}`}
            style={{ width: `${(secondSeconds / total) * 100}%` }}
            draggable={false}
          />
        </div>
        <div className="wf-playhead" style={{ left: `${(playhead / total) * 100}%` }} />
        <div
          className="wf-marker"
          style={{ left: boundaryPercent, background: "var(--blue)" }}
          onMouseDown={(e) => {
            e.stopPropagation();
            setDragging(true);
          }}
        >
          <span>boundary</span>
        </div>
      </div>

      <div className="admin-audio-actions admin-audio-transport">
        <button
          type="button"
          className="admin-trim-play"
          title={playing ? "Pause" : "Play"}
          aria-label={playing ? "Pause" : "Play"}
          onClick={togglePlay}
        >
          <FontAwesomeIcon icon={playing ? faPause : faPlay} />
        </button>
        <span className="admin-audio-status">{playhead.toFixed(1)}s</span>
        {loading && (
          <span className="admin-audio-status">
            <Spinner /> Loading audio...
          </span>
        )}
      </div>

      <div className="admin-audio-fields">
        <label className="admin-audio-field">
          <span>Shift seconds</span>
          <span className="admin-fade-controls">
            <input
              type="number"
              step="0.1"
              min={low}
              max={high}
              value={deltaS}
              disabled={busy}
              onChange={(e) => changeDelta(Number(e.target.value))}
            />
            <button
              type="button"
              className="admin-trim-play"
              title={`Move the boundary to the playhead (${hereDelta.toFixed(1)}s)`}
              aria-label="Move the boundary to the playhead"
              disabled={busy || !hereValid}
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                changeDelta(hereDelta);
              }}
            >
              <FontAwesomeIcon icon={faLocationCrosshairs} />
            </button>
            <button
              type="button"
              className="admin-trim-play"
              title={`Play from the new boundary (${(firstSeconds + delta).toFixed(1)}s)`}
              aria-label="Play from the new boundary"
              disabled={!inRange}
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                playFromBoundary();
              }}
            >
              <FontAwesomeIcon icon={faPlay} />
            </button>
          </span>
        </label>
      </div>

      <div className="admin-audio-actions">
        <button
          type="button"
          onClick={applyShift}
          disabled={busy || !inRange || delta === 0}
        >
          <FontAwesomeIcon icon={faCheck} /> Apply
        </button>
        <button
          type="button"
          onClick={() => {
            cancel();
            if (onClose) onClose();
          }}
        >
          <FontAwesomeIcon icon={faXmark} /> Cancel
        </button>
        {!inRange && (
          <span className="admin-audio-status">
            Shift must be between {low.toFixed(1)}s and {high.toFixed(1)}s.
          </span>
        )}
        {status && (
          <span className="admin-audio-status">
            <Spinner /> Applying...
          </span>
        )}
      </div>

      {error && <p className="admin-error">{error}</p>}
    </div>
  );
};

export default BoundaryPanel;
