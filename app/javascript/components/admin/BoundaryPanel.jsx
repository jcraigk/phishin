import React, { useContext, useEffect, useRef, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import {
  faArrowRotateLeft,
  faCheck,
  faPause,
  faPlay,
  faXmark,
} from "@fortawesome/free-solid-svg-icons";
import MoonLoader from "react-spinners/MoonLoader";
import { GaplessEngine } from "../player/GaplessEngine";
import { WebAudioBackend } from "../player/WebAudioBackend";
import { EditorContext } from "./AdminShowEditor";
import useJobRunner from "./useJobRunner";
import { adminPost, fetchJobAudio } from "./adminApi";

// Mirrors Admin::ShiftBoundaryJob::MIN_PART_S: both sides must keep real audio,
// so the allowed range shown here is the same one the API enforces.
const MIN_PART_S = 1.0;

const round = (value) => Math.round(value * 10) / 10;

const seconds = (ms) => round((ms || 0) / 1000);

const BoundaryPanel = ({ track, next, onClose }) => {
  const { show, reload, setGapsStale } = useContext(EditorContext);
  const [deltaS, setDeltaS] = useState(0);
  const [previewUrls, setPreviewUrls] = useState([null, null]);
  const [previewedAt, setPreviewedAt] = useState(null);
  const [dragging, setDragging] = useState(false);
  const [playhead, setPlayhead] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [previewPlaying, setPreviewPlaying] = useState(false);
  const [previewIndex, setPreviewIndex] = useState(0);
  const [previewTime, setPreviewTime] = useState(0);
  const [previewDurations, setPreviewDurations] = useState([null, null]);
  const containerRef = useRef(null);
  const firstAudioRef = useRef(null);
  const secondAudioRef = useRef(null);
  const engineRef = useRef(null);
  const suppressClickRef = useRef(false);
  const cancelledRef = useRef(false);
  const modeRef = useRef("preview");
  const { run, cancel, busy, status, error, setError } = useJobRunner();

  const firstSeconds = seconds(track.duration);
  const secondSeconds = seconds(next.duration);
  const total = firstSeconds + secondSeconds;
  const low = round(MIN_PART_S - firstSeconds);
  const high = round(secondSeconds - MIN_PART_S);
  const delta = Number.isFinite(deltaS) ? deltaS : 0;
  const inRange = delta >= low && delta <= high;
  const previewCurrent = previewedAt === delta;

  const clearPreview = () => {
    setPreviewUrls([null, null]);
    setPreviewedAt(null);
  };

  const changeDelta = (value) => {
    setDeltaS(round(value));
    setError(null);
    cancelledRef.current = false;
    setPreviewedAt(null);
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

  const syncPlaying = () =>
    setPlaying(
      Boolean(
        (firstAudioRef.current && !firstAudioRef.current.paused) ||
          (secondAudioRef.current && !secondAudioRef.current.paused)
      )
    );

  const seekTo = (combined) => {
    const first = firstAudioRef.current;
    const second = secondAudioRef.current;
    if (!first || !second) return;
    const wasPlaying = !first.paused || !second.paused;
    if (combined < firstSeconds) {
      second.pause();
      first.currentTime = combined;
      if (wasPlaying) first.play();
    } else {
      first.pause();
      second.currentTime = combined - firstSeconds;
      if (wasPlaying) second.play();
    }
    setPlayhead(combined);
  };

  const togglePlay = () => {
    const first = firstAudioRef.current;
    const second = secondAudioRef.current;
    if (!first || !second) return;
    if (!first.paused || !second.paused) {
      first.pause();
      second.pause();
      return;
    }
    (playhead < firstSeconds ? first : second).play();
  };

  const autoPlayRef = useRef(false);

  const renderPreview = () => {
    modeRef.current = "preview";
    return run(
      () => adminPost(`/tracks/${track.id}/shift_boundary_preview`, { delta_s: delta }),
      async (job) => {
        const [first, second] = await Promise.all([
          fetchJobAudio(job.id, 0),
          fetchJobAudio(job.id, 1),
        ]);
        autoPlayRef.current = true;
        setPreviewUrls([first, second]);
        setPreviewedAt(delta);
      }
    );
  };

  // The two rendered sides play through the site's gapless engine so the
  // boundary crossing is sample-accurate instead of two chained elements.
  useEffect(() => {
    if (!previewUrls[0] || !previewUrls[1]) return undefined;
    let disposed = false;
    const backend = new WebAudioBackend();
    const engine = new GaplessEngine(backend);
    engine.onPlayChange = (isPlaying) => {
      setPreviewPlaying(isPlaying);
      if (isPlaying) {
        document.querySelectorAll("audio").forEach((el) => {
          if (!el.paused) el.pause();
        });
        window.dispatchEvent(new Event("phishin:pause-player"));
      }
    };
    engine.onTrackChange = (index) => {
      setPreviewIndex(index);
      setPreviewTime(0);
    };
    engine.onTime = (time) => setPreviewTime(time);
    engine.load(previewUrls.map((url) => ({ url, offset: 0, end: null })));
    engineRef.current = engine;
    setPreviewIndex(0);
    setPreviewTime(0);
    setPreviewDurations([null, null]);
    Promise.all([backend.buffer(0), backend.buffer(1)])
      .then((buffers) => {
        if (!disposed) setPreviewDurations(buffers.map((b) => b.duration));
      })
      .catch(() => {});
    if (autoPlayRef.current) {
      autoPlayRef.current = false;
      engine.goto(0, { play: true });
    }
    return () => {
      disposed = true;
      engine.destroy();
      engineRef.current = null;
      setPreviewPlaying(false);
      previewUrls.forEach((url) => URL.revokeObjectURL(url));
    };
  }, [previewUrls]);

  const togglePreviewClip = (index) => {
    const engine = engineRef.current;
    if (!engine) return;
    if (previewPlaying && previewIndex === index) engine.pause();
    else engine.goto(index, { play: true });
  };

  const seekClip = (index, e) => {
    const engine = engineRef.current;
    const duration = previewDurations[index];
    if (!engine || !duration) return;
    const rect = e.currentTarget.getBoundingClientRect();
    const fraction = Math.min(Math.max((e.clientX - rect.left) / rect.width, 0), 1);
    if (previewIndex !== index) engine.goto(index);
    engine.seek(fraction * duration);
  };

  // Any audio element starting elsewhere pauses the engine preview.
  useEffect(() => {
    const onPlay = (e) => {
      if (e.target instanceof HTMLMediaElement && engineRef.current) engineRef.current.pause();
    };
    document.addEventListener("play", onPlay, true);
    return () => document.removeEventListener("play", onPlay, true);
  }, []);

  useEffect(() => {
    if (busy || previewCurrent || error || cancelledRef.current) return undefined;
    if (!inRange || delta === 0) return undefined;
    const timer = setTimeout(renderPreview, 800);
    return () => clearTimeout(timer);
  }, [delta, busy, previewCurrent, error]);

  const applyShift = () => {
    const message =
      `Move the boundary between "${track.title}" and "${next.title}" by ` +
      `${delta.toFixed(1)}s? Both original audio files are backed up.`;
    if (!window.confirm(message)) return;
    modeRef.current = "apply";
    run(
      () => adminPost(`/tracks/${track.id}/shift_boundary_apply`, { delta_s: delta }),
      async () => {
        clearPreview();
        await reload();
        if (show.published) setGapsStale(true);
      }
    );
  };

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

      <div className="admin-audio-fields">
        <label className="admin-audio-field is-medium">
          <span>Shift seconds</span>
          <input
            type="number"
            step="0.1"
            min={low}
            max={high}
            value={deltaS}
            disabled={busy}
            onChange={(e) => changeDelta(Number(e.target.value))}
          />
        </label>
        <button type="button" className="admin-trim-play" onClick={togglePlay}>
          <FontAwesomeIcon icon={playing ? faPause : faPlay} />
        </button>
      </div>

      <audio
        ref={firstAudioRef}
        src={track.mp3_url}
        onTimeUpdate={(e) => setPlayhead(e.target.currentTime)}
        onPlay={() => setPlaying(true)}
        onPause={syncPlaying}
        onEnded={() => {
          const second = secondAudioRef.current;
          if (!second) return;
          second.currentTime = 0;
          second.play();
        }}
      />
      <audio
        ref={secondAudioRef}
        src={next.mp3_url}
        onTimeUpdate={(e) => setPlayhead(firstSeconds + e.target.currentTime)}
        onPlay={() => setPlaying(true)}
        onPause={syncPlaying}
      />

      {previewUrls[0] && previewUrls[1] && (
        <>
          {[
            `End of "${track.title}"`,
            `Start of "${next.title}"`,
          ].map((label, index) => (
            <div className="admin-preview-player" key={label}>
              <button
                type="button"
                className="admin-trim-play"
                onClick={() => togglePreviewClip(index)}
              >
                <FontAwesomeIcon
                  icon={previewPlaying && previewIndex === index ? faPause : faPlay}
                />
              </button>
              <button
                type="button"
                className="admin-trim-play"
                onClick={() => {
                  const engine = engineRef.current;
                  if (engine) engine.goto(index, { play: true });
                }}
              >
                <FontAwesomeIcon icon={faArrowRotateLeft} />
              </button>
              <div
                className="admin-preview-scrubber"
                role="button"
                onClick={(e) => seekClip(index, e)}
              >
                <div
                  className="admin-preview-scrubber-fill"
                  style={{
                    width: `${
                      previewIndex === index && previewDurations[index]
                        ? Math.min(previewTime / previewDurations[index], 1) * 100
                        : 0
                    }%`,
                  }}
                />
              </div>
              <span className="admin-preview-tag">{label}</span>
            </div>
          ))}
        </>
      )}

      <div className="admin-audio-actions">
        <button
          type="button"
          onClick={applyShift}
          disabled={busy || !inRange || delta === 0 || !previewCurrent}
        >
          <FontAwesomeIcon icon={faCheck} /> Apply
        </button>
        <button
          type="button"
          onClick={() => {
            cancelledRef.current = true;
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
            <MoonLoader color="#c7c8ca" size={14} />{" "}
            {modeRef.current === "apply" ? "Applying..." : "Rendering..."}
          </span>
        )}
      </div>

      {error && <p className="admin-error">{error}</p>}
    </div>
  );
};

export default BoundaryPanel;
