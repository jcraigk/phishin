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
import { EditorContext } from "./AdminShowEditor";
import WaveformScrubber from "./WaveformScrubber";
import useJobRunner from "./useJobRunner";
import { adminPost, fetchJobAudio } from "./adminApi";

const round = (value) => Math.round(value * 100) / 100;

const formatTime = (seconds) => {
  const total = Math.max(seconds || 0, 0);
  const minutes = Math.floor(total / 60);
  const rest = total - minutes * 60;
  return `${minutes}:${rest.toFixed(2).padStart(5, "0")}`;
};

const parseTime = (text) => {
  const match = text.trim().match(/^(?:(\d+):)?(\d+(?:\.\d+)?)$/);
  if (!match) return null;
  return Number(match[1] || 0) * 60 + Number(match[2]);
};

const TimeField = ({ label, value, onCommit, disabled }) => {
  const [draft, setDraft] = useState(null);
  const commit = () => {
    if (draft == null) return;
    const parsed = parseTime(draft);
    if (parsed != null) onCommit(parsed);
    setDraft(null);
  };
  return (
    <label className="admin-audio-field">
      <span>{label}</span>
      <input
        type="text"
        value={draft ?? formatTime(value)}
        disabled={disabled}
        onChange={(e) => setDraft(e.target.value)}
        onBlur={commit}
        onKeyDown={(e) => {
          if (e.key === "Enter") commit();
        }}
      />
    </label>
  );
};

const ClipPlayer = ({ label, url, audioRef }) => {
  const [playing, setPlaying] = useState(false);
  const [time, setTime] = useState(0);
  const [clipDuration, setClipDuration] = useState(null);

  if (!url) return null;

  return (
    <div className="admin-preview-player">
      <audio
        src={url}
        ref={audioRef}
        onTimeUpdate={(e) => setTime(e.target.currentTime)}
        onLoadedMetadata={(e) => setClipDuration(e.target.duration)}
        onPlay={() => setPlaying(true)}
        onPause={() => setPlaying(false)}
      />
      <button
        type="button"
        className="admin-trim-play"
        onClick={() => {
          const audio = audioRef.current;
          if (!audio) return;
          if (audio.paused) audio.play();
          else audio.pause();
        }}
      >
        <FontAwesomeIcon icon={playing ? faPause : faPlay} />
      </button>
      <button
        type="button"
        className="admin-trim-play"
        onClick={() => {
          const audio = audioRef.current;
          if (!audio) return;
          audio.currentTime = 0;
          audio.play();
        }}
      >
        <FontAwesomeIcon icon={faArrowRotateLeft} />
      </button>
      <div
        className="admin-preview-scrubber"
        role="button"
        onClick={(e) => {
          const audio = audioRef.current;
          if (!audio || !clipDuration) return;
          const rect = e.currentTarget.getBoundingClientRect();
          const fraction = Math.min(Math.max((e.clientX - rect.left) / rect.width, 0), 1);
          audio.currentTime = fraction * clipDuration;
        }}
      >
        <div
          className="admin-preview-scrubber-fill"
          style={{ width: `${clipDuration ? Math.min(time / clipDuration, 1) * 100 : 0}%` }}
        />
      </div>
      <span className="admin-preview-tag">{label}</span>
    </div>
  );
};

const TrimPanel = ({ track, onClose }) => {
  const { reload } = useContext(EditorContext);
  const duration = (track.duration || 0) / 1000;
  const [trimStart, setTrimStart] = useState(0);
  const [trimEnd, setTrimEnd] = useState(round(duration));
  const [fadeIn, setFadeIn] = useState(0.2);
  const [fadeOut, setFadeOut] = useState(6.0);
  const [delay, setDelay] = useState(2.5);
  const [previewUrls, setPreviewUrls] = useState([null, null]);
  const [previewedAt, setPreviewedAt] = useState(null);
  const [playhead, setPlayhead] = useState(0);
  const [originalPlaying, setOriginalPlaying] = useState(false);
  const audioRef = useRef(null);
  const headPreviewRef = useRef(null);
  const tailPreviewRef = useRef(null);
  const lastEditedRef = useRef("tail");
  const { run, cancel, busy, status, error, setError } = useJobRunner();

  useEffect(() => {
    // Capture phase so this wins over the bottom Player's own space handler.
    const onKeyDown = (e) => {
      if (e.key !== " " || e.shiftKey) return;
      const active = document.activeElement;
      if (["INPUT", "TEXTAREA", "SELECT"].includes(active?.tagName) || active?.isContentEditable) return;
      const players = [
        headPreviewRef.current,
        tailPreviewRef.current,
        audioRef.current,
      ].filter(Boolean);
      if (players.length === 0) return;
      const target =
        players.find((p) => !p.paused) || players.find((p) => p.currentTime > 0) || players[0];
      e.preventDefault();
      e.stopPropagation();
      if (target.paused) target.play();
      else target.pause();
    };
    window.addEventListener("keydown", onKeyDown, true);
    return () => window.removeEventListener("keydown", onKeyDown, true);
  }, []);

  // The end marker is where the music stops; the committed audio keeps `delay`
  // seconds beyond it and then fades for `fadeOut`, so the real trim point
  // sent to the server sits delay + fadeOut past the marker.
  const fadeTail = delay + fadeOut;
  const trimEndParam = round(Math.min(trimEnd + fadeTail, duration));
  const values = {
    trim_start: trimStart,
    trim_end: trimEndParam,
    fade_in: fadeIn,
    fade_out: fadeOut,
    tail_pad: round(delay + 2),
  };
  const signature = JSON.stringify(values);
  const previewCurrent = previewedAt === signature;
  const cutSeconds = trimStart + Math.max(duration - trimEndParam, 0);

  const clearPreview = () => {
    setPreviewUrls([null, null]);
    setPreviewedAt(null);
  };

  const setValue = (setter, side) => (value) => {
    setter(value);
    if (side) lastEditedRef.current = side;
    setError(null);
    cancelledRef.current = false;
    clearPreview();
  };

  const moveMarker = (name, seconds) => {
    if (name === "start") setValue(setTrimStart, "head")(round(Math.min(seconds, trimEnd)));
    else
      setValue(setTrimEnd, "tail")(
        round(Math.min(Math.max(seconds, trimStart), Math.max(duration - fadeTail, trimStart)))
      );
  };

  const modeRef = useRef("preview");

  const autoPlayRef = useRef(null);

  const renderPreview = () => {
    modeRef.current = "preview";
    return run(
      () => adminPost(`/tracks/${track.id}/trim_preview`, values),
      async (job) => {
        const [head, tail] = await Promise.all([
          fetchJobAudio(job.id, 0),
          fetchJobAudio(job.id, 1),
        ]);
        autoPlayRef.current = lastEditedRef.current;
        setPreviewUrls([head, tail]);
        setPreviewedAt(signature);
      }
    );
  };

  useEffect(() => {
    if (!previewUrls[0]) return undefined;
    const side = autoPlayRef.current;
    autoPlayRef.current = null;
    if (side) {
      if (audioRef.current) audioRef.current.pause();
      const target = side === "head" ? headPreviewRef.current : tailPreviewRef.current;
      if (target) target.play();
    }
    return () => previewUrls.forEach((url) => url && URL.revokeObjectURL(url));
  }, [previewUrls]);

  const initialSignatureRef = useRef(signature);
  const dirtyRef = useRef(false);
  const cancelledRef = useRef(false);

  useEffect(() => {
    if (!dirtyRef.current) {
      if (signature === initialSignatureRef.current) return undefined;
      dirtyRef.current = true;
    }
    if (busy || previewCurrent || error || cancelledRef.current) return undefined;
    if (cutSeconds < 0.5) return undefined;
    const timer = setTimeout(renderPreview, 800);
    return () => clearTimeout(timer);
  }, [signature, busy, previewCurrent, error]);

  const applyTrim = () => {
    if (!window.confirm(`Apply this trim to "${track.title}"? The original is backed up.`)) return;
    modeRef.current = "apply";
    run(
      () => adminPost(`/tracks/${track.id}/trim_apply`, values),
      async () => {
        clearPreview();
        await reload();
      }
    );
  };

  const numberField = (label, value, setter, side, extra = {}) => (
    <label className="admin-audio-field is-narrow">
      <span>{label}</span>
      <input
        type="number"
        step="0.1"
        min="0"
        value={value}
        disabled={busy}
        onChange={(e) => setValue(setter, side)(Number(e.target.value))}
        {...extra}
      />
    </label>
  );

  return (
    <div className="admin-audio-panel">
      <h4>Trim</h4>
      <WaveformScrubber
        waveformUrl={track.waveform_url}
        duration={duration}
        playheadSeconds={playhead}
        markers={[
          { name: "start", seconds: trimStart, color: "var(--blue)" },
          { name: "end", seconds: trimEnd, color: "var(--alert-red)" },
        ]}
        onMarkerChange={moveMarker}
        onSeek={(seconds) => {
          if (audioRef.current) audioRef.current.currentTime = seconds;
          setPlayhead(seconds);
        }}
      />

      <div className="admin-audio-fields">
        <TimeField
          label="Trim start"
          value={trimStart}
          disabled={busy}
          onCommit={(seconds) =>
            setValue(setTrimStart, "head")(round(Math.min(Math.max(seconds, 0), trimEnd)))
          }
        />
        <TimeField
          label="Music end"
          value={trimEnd}
          disabled={busy}
          onCommit={(seconds) =>
            setValue(setTrimEnd, "tail")(
              round(
                Math.min(Math.max(seconds, trimStart), Math.max(duration - fadeTail, trimStart))
              )
            )
          }
        />
        {numberField("Fade in", fadeIn, setFadeIn, "head")}
        {numberField("Delay", delay, setDelay, "tail")}
        {numberField("Fade out", fadeOut, setFadeOut, "tail")}
        <button
          type="button"
          className="admin-trim-play"
          onClick={() => {
            const audio = audioRef.current;
            if (!audio) return;
            if (audio.paused) audio.play();
            else audio.pause();
          }}
        >
          <FontAwesomeIcon icon={originalPlaying ? faPause : faPlay} />
        </button>
      </div>

      <audio
        ref={audioRef}
        src={track.mp3_url}
        onTimeUpdate={(e) => setPlayhead(e.target.currentTime)}
        onPlay={() => setOriginalPlaying(true)}
        onPause={() => setOriginalPlaying(false)}
      />

      {trimStart > 0 && (
        <ClipPlayer label="Fade in" url={previewUrls[0]} audioRef={headPreviewRef} />
      )}
      {trimEndParam < duration - 0.1 && (
        <ClipPlayer label="Fade out" url={previewUrls[1]} audioRef={tailPreviewRef} />
      )}

      <div className="admin-audio-actions">
        <button type="button" onClick={applyTrim} disabled={busy || !previewCurrent}>
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
        {status && (
          <span className="admin-audio-status">
            <MoonLoader color="#c7c8ca" size={14} />{" "}
            {modeRef.current === "apply" ? "Applying..." : "Rendering..."}
          </span>
        )}
        {cutSeconds > 0 && cutSeconds < 0.5 && (
          <span className="admin-audio-status">
            Only {cutSeconds.toFixed(2)}s would be cut; at least 0.5s is required.
          </span>
        )}
      </div>

      {error && <p className="admin-error">{error}</p>}
    </div>
  );
};

export default TrimPanel;
