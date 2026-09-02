import React, { useContext, useEffect, useRef, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCheck } from "@fortawesome/free-solid-svg-icons";
import { EditorContext } from "./AdminShowEditor";
import WaveformScrubber from "./WaveformScrubber";
import PreviewPlayer from "./PreviewPlayer";
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

const TrimPanel = ({ track }) => {
  const { reload } = useContext(EditorContext);
  const duration = (track.duration || 0) / 1000;
  const [trimStart, setTrimStart] = useState(0);
  const [trimEnd, setTrimEnd] = useState(round(duration));
  const [fadeIn, setFadeIn] = useState(0.2);
  const [fadeOut, setFadeOut] = useState(6.0);
  const [previewUrl, setPreviewUrl] = useState(null);
  const [previewedAt, setPreviewedAt] = useState(null);
  const [playhead, setPlayhead] = useState(0);
  const audioRef = useRef(null);
  const previewAudioRef = useRef(null);
  const { run, busy, status, error } = useJobRunner();

  useEffect(() => {
    // Capture phase so this wins over the bottom Player's own space handler.
    const onKeyDown = (e) => {
      if (e.key !== " " || e.shiftKey) return;
      const active = document.activeElement;
      if (["INPUT", "TEXTAREA", "SELECT"].includes(active?.tagName) || active?.isContentEditable) return;
      const players = [previewAudioRef.current, audioRef.current].filter(Boolean);
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

  const values = { trim_start: trimStart, trim_end: trimEnd, fade_in: fadeIn, fade_out: fadeOut };
  const signature = JSON.stringify(values);
  const previewCurrent = previewedAt === signature;

  const clearPreview = () => {
    setPreviewUrl(null);
    setPreviewedAt(null);
  };

  const setValue = (setter) => (value) => {
    setter(value);
    clearPreview();
  };

  const moveMarker = (name, seconds) => {
    if (name === "start") setValue(setTrimStart)(round(Math.min(seconds, trimEnd)));
    else setValue(setTrimEnd)(round(Math.max(seconds, trimStart)));
  };

  const renderPreview = () =>
    run(
      () => adminPost(`/tracks/${track.id}/trim_preview`, values),
      async (job) => {
        setPreviewUrl(await fetchJobAudio(job.id));
        setPreviewedAt(signature);
      }
    );

  const initialSignatureRef = useRef(signature);
  const dirtyRef = useRef(false);

  useEffect(() => {
    if (!dirtyRef.current) {
      if (signature === initialSignatureRef.current) return undefined;
      dirtyRef.current = true;
    }
    if (busy || previewCurrent) return undefined;
    const timer = setTimeout(renderPreview, 800);
    return () => clearTimeout(timer);
  }, [signature, busy, previewCurrent]);

  const applyTrim = () => {
    if (!window.confirm(`Apply this trim to "${track.title}"? The original is backed up.`)) return;
    run(
      () => adminPost(`/tracks/${track.id}/trim_apply`, values),
      async () => {
        clearPreview();
        await reload();
      }
    );
  };

  const numberField = (label, value, setter, extra = {}) => (
    <label className="admin-audio-field is-narrow">
      <span>{label}</span>
      <input
        type="number"
        step="0.1"
        min="0"
        value={value}
        disabled={busy}
        onChange={(e) => setValue(setter)(Number(e.target.value))}
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
            setValue(setTrimStart)(round(Math.min(Math.max(seconds, 0), trimEnd)))
          }
        />
        <TimeField
          label="Trim end"
          value={trimEnd}
          disabled={busy}
          onCommit={(seconds) =>
            setValue(setTrimEnd)(round(Math.min(Math.max(seconds, trimStart), duration)))
          }
        />
        {numberField("Fade in", fadeIn, setFadeIn)}
        {numberField("Fade out", fadeOut, setFadeOut)}
      </div>

      <div className="admin-preview-player">
        <audio
          ref={audioRef}
          controls
          src={track.mp3_url}
          onTimeUpdate={(e) => setPlayhead(e.target.currentTime)}
        />
      </div>

      <PreviewPlayer
        label="Preview - this exact audio will be committed"
        url={previewUrl}
        audioRef={previewAudioRef}
      />

      <div className="admin-audio-actions">
        <button type="button" onClick={renderPreview} disabled={busy}>
          Render Preview
        </button>
        <button type="button" onClick={applyTrim} disabled={busy || !previewCurrent}>
          <FontAwesomeIcon icon={faCheck} /> Apply
        </button>
        {previewUrl && !previewCurrent && (
          <span className="admin-audio-status">
            Values changed. Render a new preview before applying.
          </span>
        )}
        {status && <span className="admin-audio-status">{status}</span>}
      </div>

      {error && <p className="admin-error">{error}</p>}
    </div>
  );
};

export default TrimPanel;
