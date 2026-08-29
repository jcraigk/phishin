import React, { useContext, useEffect, useMemo, useRef, useState } from "react";
import { useNavigate } from "react-router";
import { EditorContext } from "./AdminShowEditor";
import WaveformScrubber from "./WaveformScrubber";
import StagedTrackRow from "./StagedTrackRow";
import useJobRunner from "./useJobRunner";
import { StagingPlayer } from "./StagingPlayer";
import { adminPatch, adminPost, adminPut, adminDelete } from "./adminApi";

// The show editor while a show is staged. Every write answers with the full
// staging payload, which replaces show.staging; the rows re-render from that
// rather than from local guesses about who moved after a split or combine.
const StagingEditor = () => {
  const { show, setShow, reload } = useContext(EditorContext);
  const navigate = useNavigate();
  const staging = show.staging;
  const [selectedId, setSelectedId] = useState(staging.tracks[0]?.id ?? null);
  const [playhead, setPlayhead] = useState(null);
  const [playing, setPlaying] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const playerRef = useRef(null);
  const { run, busy: jobBusy, status, error: jobError } = useJobRunner();

  // staging.sources is a new array on every mutation response (a title edit,
  // a boundary nudge), even when the underlying source files have not
  // changed. The player must survive those: it reads sources through a ref
  // rather than a closed-over value, and the effect below is keyed on the
  // sources' identity (their ids), not the array's, so a PATCH response does
  // not tear down and rebuild the player, revoke its object URLs and close
  // its AudioContext out from under an in-progress audition.
  const sourcesRef = useRef(staging.sources);
  sourcesRef.current = staging.sources;
  const sourceKey = staging.sources.map((s) => s.id).join(",");

  useEffect(() => {
    const player = new StagingPlayer({
      getSources: () => sourcesRef.current,
      onTime: setPlayhead,
      onStop: () => setPlaying(false),
      onError: (e) => setError(e.message),
    });
    playerRef.current = player;
    return () => player.dispose();
  }, [sourceKey]);

  const tracks = staging.tracks;
  const selected = useMemo(() => tracks.find((t) => t.id === selectedId) || tracks[0] || null, [tracks, selectedId]);
  const selectedIndex = selected ? tracks.indexOf(selected) : -1;
  const nextOf = (index) => tracks[index + 1] || null;

  const apply = (setter) => async (request) => {
    setError(null);
    setBusy(true);
    try {
      const payload = await request();
      setShow((prev) => ({ ...prev, staging: payload }));
      if (setter) setter(payload);
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  const base = `/shows/${show.date}/staging`;
  const patch = (track, changes) => apply()(() => adminPatch(`${base}/tracks/${track.id}`, changes));
  const split = (track, at) => apply()(() => adminPost(`${base}/tracks/${track.id}/split`, { at_s: at }));
  const combine = (track) => apply()(() => adminPost(`${base}/tracks/${track.id}/combine`));
  const boundary = (track, at) => apply()(() => adminPut(`${base}/tracks/${track.id}/boundary`, { at_s: at }));
  const remove = (track) => {
    if (!window.confirm(`Remove "${track.title}" from the show? Its audio will not be exported.`)) return;
    const index = tracks.indexOf(track);
    apply((payload) => setSelectedId(payload.tracks[Math.min(index, payload.tracks.length - 1)]?.id ?? null))(
      () => adminDelete(`${base}/tracks/${track.id}`)
    );
  };

  // A seam audition spans two tracks; the fade envelope applied is the first
  // track's until the boundary and the next track's after it, so the player
  // is handed a merged span with both fades in place.
  const play = (track, fromS, toS, next) => {
    setSelectedId(track.id);
    const envelope = next ? seamEnvelope(track, next) : track;
    playerRef.current.play(envelope, fromS, toS);
    setPlaying(true);
  };

  const stop = () => playerRef.current.stop();

  const commit = () => {
    if (!window.confirm(`Commit ${tracks.length} tracks for ${show.date}? Audio renders once from the lossless source.`)) return;
    stop();
    run(() => adminPost(`${base}/commit`), () => reload());
  };

  const discard = async () => {
    if (!window.confirm(`Discard staging for ${show.date}? The staged audio is deleted.`)) return;
    stop();
    try {
      await adminDelete(base);
      navigate("/admin");
    } catch (e) {
      setError(e.message);
    }
  };

  const span = selected ? { start: selected.start_s, end: selected.end_s } : { start: 0, end: staging.total_s };
  const markers = selected
    ? [
        { name: "start", seconds: selected.start_s - span.start, color: "var(--blue)" },
        { name: "end", seconds: selected.end_s - span.start, color: "var(--alert-red)" },
      ]
    : [];

  return (
    <div className="admin-staging">
      <div className="admin-staging-header">
        <h2>Staging</h2>
        {staging.source_url && (
          <a href={staging.source_url} target="_blank" rel="noreferrer">{staging.source_url}</a>
        )}
        <span className="admin-audio-note">
          {staging.sources.length} source files, {Math.round(staging.total_s / 60)} minutes. Edits apply to the lossless timeline at commit.
        </span>
      </div>

      {(error || jobError) && <p className="admin-error">{error || jobError}</p>}

      <div className="admin-staging-transport">
        <WaveformScrubber
          waveformUrl={null}
          duration={span.end - span.start}
          playheadSeconds={playhead == null ? null : playhead - span.start}
          markers={markers}
          onSeek={(s) => {
            const t = span.start + s;
            setPlayhead(t);
            if (playing) playerRef.current.seek(t);
          }}
        />
        <div className="admin-audio-actions">
          <button
            type="button"
            disabled={!selected}
            onClick={() => {
              if (playing) {
                stop();
                return;
              }
              const scrubbed = playhead != null && playhead >= selected.start_s && playhead <= selected.end_s;
              play(selected, scrubbed ? playhead : undefined);
            }}
          >
            {playing ? "Stop" : "Play"}
          </button>
          <span className="admin-audio-status">
            {selected ? selected.title : "No track selected"}
            {playhead != null && ` at ${playhead.toFixed(1)}s`}
          </span>
        </div>
      </div>

      <ul className="admin-staging-tracks">
        {tracks.map((track, index) => (
          <StagedTrackRow
            key={track.id}
            track={track}
            next={nextOf(index)}
            selected={selected?.id === track.id}
            onSelect={(t) => setSelectedId(t.id)}
            onPlay={play}
            onPatch={patch}
            onSplit={split}
            onCombine={combine}
            onBoundary={boundary}
            onRemove={remove}
            playhead={selectedIndex === index ? playhead : null}
            busy={busy || jobBusy}
          />
        ))}
      </ul>

      <div className="admin-staging-commit">
        <button type="button" disabled={busy || jobBusy || tracks.length === 0} onClick={commit}>
          Commit {tracks.length} tracks
        </button>
        <button type="button" className="admin-danger" disabled={busy || jobBusy} onClick={discard}>
          Discard staging
        </button>
        {status && <span className="admin-audio-status">{status}</span>}
      </div>
    </div>
  );
};

// gainAt takes one track; a seam audition covers two. Represent the pair as a
// single span whose fade-out is the first track's and whose fade-in belongs to
// the second, by stitching the two envelopes at the boundary.
const seamEnvelope = (first, second) => ({
  start_s: first.start_s,
  end_s: second.end_s,
  fade_in_s: first.fade_in_s,
  fade_out_s: 0,
  seam: { at: first.end_s, out: first.fade_out_s, in: second.fade_in_s },
});

export default StagingEditor;
