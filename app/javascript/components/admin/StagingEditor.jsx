import React, { useContext, useEffect, useMemo, useRef, useState } from "react";
import { useNavigate } from "react-router";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faArrowRotateLeft, faCheck, faClockRotateLeft, faPause, faPlay, faSpinner, faTrashCan } from "@fortawesome/free-solid-svg-icons";
import { EditorContext } from "./AdminShowEditor";
import WaveformScrubber from "./WaveformScrubber";
import StagedTrackRow from "./StagedTrackRow";
import useJobRunner from "./useJobRunner";
import { StagingPlayer } from "./StagingPlayer";
import { adminPatch, adminPost, adminPut, adminDelete } from "./adminApi";
import { round1 } from "./stagingMath";
import { setName, groupBySet, withPendingSets, addableSets as computeAddableSets } from "./sets";
import AddSetMenu from "./AddSetMenu";
import IssueList from "./IssueList";
import Spinner from "./Spinner";
import { authFetch, formatDate, formatDurationShow } from "../helpers/utils";

const EDGE_PAD_S = 30;
const MIN_TRACK_S = 1;
const SEAM_COLOR = "#d8b24a";

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
  const [loading, setLoading] = useState(false);
  const [dragEdges, setDragEdges] = useState(null);
  const [peakData, setPeakData] = useState(null);
  const [busy, setBusy] = useState(false);

  // One fetch of the whole timeline's peaks (about 100KB for a long show);
  // every track's window is drawn from it client-side.
  useEffect(() => {
    if (!staging.peaks_url) {
      setPeakData(null);
      return undefined;
    }
    let cancelled = false;
    authFetch(staging.peaks_url)
      .then((res) => (res.ok ? res.arrayBuffer() : Promise.reject(new Error(`Waveform fetch failed (${res.status})`))))
      .then((buffer) => {
        if (!cancelled) setPeakData(new Uint8Array(buffer));
      })
      .catch((e) => {
        if (!cancelled) setError(e.message);
      });
    return () => {
      cancelled = true;
    };
  }, [staging.peaks_url]);
  const [error, setError] = useState(null);
  const playerRef = useRef(null);
  const { run, resume, busy: jobBusy, status, progress, error: jobError } = useJobRunner();

  // staging.sources is a new array on every mutation response (a title edit,
  // a boundary nudge), even when the underlying source files have not
  // changed. The player must survive those: it reads sources through a ref
  // rather than a closed-over value, and the effect below is keyed on the
  // sources' identity (their ids), not the array's, so a PATCH response does
  // not tear down and rebuild the player, revoke its object URLs and close
  // its AudioContext out from under an in-progress audition.
  const sourcesRef = useRef(staging.sources);
  sourcesRef.current = staging.sources;
  const tracksRef = useRef(staging.tracks);
  tracksRef.current = staging.tracks;
  const sourceKey = staging.sources.map((s) => s.id).join(",");

  useEffect(() => {
    const player = new StagingPlayer({
      getSources: () => sourcesRef.current,
      // Whole-track playback runs on into the next track: continuously across
      // a seam, or jumping over the dropped audio when the two are cut apart.
      // The selection stays put; editing is one track at a time.
      getFollowing: (track) => {
        const list = tracksRef.current;
        const index = list.findIndex((t) => t.id === track.id);
        const following = index >= 0 ? list[index + 1] : null;
        if (!following) return null;
        const touching = Math.abs(track.end_s - following.start_s) < 0.0005;
        return { track: following, jumpTo: touching ? null : following.start_s };
      },
      onTime: setPlayhead,
      onStop: () => setPlaying(false),
      onLoading: setLoading,
      onError: (e) => setError(e.message),
    });
    playerRef.current = player;
    return () => player.dispose();
  }, [sourceKey]);

  const tracks = staging.tracks;
  const [pendingSets, setPendingSets] = useState([]);
  const groups = useMemo(() => withPendingSets(groupBySet(tracks), pendingSets), [tracks, pendingSets]);
  const addableSets = computeAddableSets(tracks, pendingSets);

  const selected = useMemo(() => tracks.find((t) => t.id === selectedId) || tracks[0] || null, [tracks, selectedId]);
  const selectedIndex = selected ? tracks.indexOf(selected) : -1;
  const nextOf = (index) => tracks[index + 1] || null;

  // Each side of a track is a seam (continuous with the neighbor) or a trim
  // (its own edge). Adjacent tracks in the same set share a seam; a set or
  // encore boundary, like the show's first start and last end, is a trim.
  const isSeam = (a, b) => Boolean(a && b && a.set === b.set);
  const kindsAt = (index) => {
    const t = tracks[index];
    const prev = tracks[index - 1];
    const following = tracks[index + 1];
    return {
      startKind: isSeam(prev, t) ? "seam" : "trim",
      endKind: isSeam(t, following) ? "seam" : "trim",
    };
  };

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
  const uncombine = (track) => apply()(() => adminPost(`${base}/tracks/${track.id}/uncombine`));
  const boundary = (track, at) => apply()(() => adminPut(`${base}/tracks/${track.id}/boundary`, { at_s: at }));
  const changeSet = (track, set) => {
    setPendingSets((prev) => prev.filter((s) => s !== set));
    return patch(track, { set });
  };

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

  // Play resumes from wherever the playhead sits, even in the neighbor room
  // around the track; the track under the playhead supplies the fade
  // envelope, and the selection stays put.
  const playFromPlayhead = () => {
    if (!selected) return;
    const t = playhead ?? selected.start_s;
    const host = tracks.find((tr) => t >= tr.start_s && t < tr.end_s)
      || tracks.find((tr) => t >= tr.start_s && t <= tr.end_s)
      || selected;
    playerRef.current.play(host, t);
    setPlaying(true);
  };

  // Starts at the seam and runs on, so the opening of the next track is heard
  // exactly as it will be exported. The selection stays on the current track.
  const playFromSeam = (track) => {
    const following = tracks[tracks.indexOf(track) + 1];
    if (!following) return;
    playerRef.current.play(following, following.start_s);
    setPlaying(true);
  };

  // Space toggles playback of the selected track, unless the user is typing
  // in a field (where space is a character) or on a button (where it clicks).
  useEffect(() => {
    const onKeyDown = (e) => {
      if (e.code !== "Space" || !selected) return;
      const tag = e.target.tagName;
      if (["INPUT", "TEXTAREA", "SELECT", "BUTTON"].includes(tag) || e.target.isContentEditable) return;
      e.preventDefault();
      if (playing) {
        stop();
        return;
      }
      playFromPlayhead();
    };
    document.addEventListener("keydown", onKeyDown);
    return () => document.removeEventListener("keydown", onKeyDown);
  });

  // What the commit refuses: the server checks the same things, but the
  // reasons are only shown when someone reaches for the button.
  const commitIssues = [
    ...(show.venue_id ? [] : ["Choose a venue"]),
    ...tracks.filter((t) => t.songs.length === 0).map((t) => `${t.title} has no song`),
  ];
  const [commitIssuesShown, setCommitIssuesShown] = useState(false);
  useEffect(() => {
    if (commitIssues.length === 0) setCommitIssuesShown(false);
  }, [commitIssues.length]);

  const commit = () => {
    if (commitIssues.length > 0) {
      setCommitIssuesShown(true);
      return;
    }
    if (!window.confirm(`Commit ${tracks.length} tracks for ${formatDate(show.date)}? Audio renders once from the lossless source.`)) return;
    stop();
    run(() => adminPost(`${base}/commit`), () => reload());
  };

  // A page loaded while a commit is running picks the job back up rather
  // than showing an editor for tracks that are being rendered.
  useEffect(() => {
    if (staging.commit_job_id && !jobBusy) {
      resume(staging.commit_job_id, () => reload());
    }
  }, [staging.commit_job_id]);

  const discard = async () => {
    if (!window.confirm(`Discard staging for ${formatDate(show.date)}? The staged audio is deleted.`)) return;
    stop();
    try {
      await adminDelete(base);
      navigate("/admin");
    } catch (e) {
      setError(e.message);
    }
  };

  // The scrubber shows the selected track with some room on either side so
  // its start and end markers can be dragged outward; a drag is held locally
  // and PATCHed once the mouse goes up.
  const edges = dragEdges || (selected && { start_s: selected.start_s, end_s: selected.end_s });
  // The window is fixed when a track is selected and stays put while its
  // edges move, so the waveform does not re-scale under a drag; picking a
  // track again re-centers it. Room is left only beyond a seam, and never
  // past the neighbor on that side, so at most one track shows on each side;
  // a trim (set break or show edge) sits flush against the window's edge.
  const windowFor = (track) => {
    if (!track) return { start: 0, end: staging.total_s };
    const list = tracksRef.current;
    const index = list.findIndex((t) => t.id === track.id);
    const prev = list[index - 1];
    const following = list[index + 1];
    const pad = Math.max(EDGE_PAD_S, (track.end_s - track.start_s) / 2);
    // A trim side reaches out to where the ingest put the edge, so audio
    // trimmed away stays in view as the shaded band it became.
    return {
      start: prev && prev.set === track.set
        ? Math.max(track.start_s - pad, prev.start_s)
        : Math.min(track.start_s, track.original_start_s ?? track.start_s),
      end: following && following.set === track.set
        ? Math.min(track.end_s + pad, following.end_s)
        : Math.max(track.end_s, track.original_end_s ?? track.end_s),
    };
  };
  const [viewSpan, setViewSpan] = useState(() => windowFor(selected));
  // Selecting a track parks the playhead at its start (its seam or trim), so
  // play begins there until the playhead is moved.
  useEffect(() => {
    const track = tracksRef.current.find((t) => t.id === selectedId) || tracksRef.current[0] || null;
    if (track && !playing) setPlayhead(track.start_s);
  }, [selectedId]);

  // A set change turns a seam into a trim or back, which changes how much
  // room the window leaves on that side.
  const setKey = tracks.map((t) => t.set).join(",");
  // A trim edge dragged out past its ingest position (which no seam can do)
  // would leave the window; the window follows it once the move settles.
  const reachKey = selected
    ? `${Math.min(selected.start_s, selected.original_start_s ?? selected.start_s)}:${Math.max(selected.end_s, selected.original_end_s ?? selected.end_s)}`
    : "";
  useEffect(() => {
    setViewSpan(windowFor(tracksRef.current.find((t) => t.id === selectedId) || tracksRef.current[0] || null));
  }, [selectedId, setKey, reachKey]);
  const span = viewSpan;

  // Where the ingest put this track's edges (its source file boundaries).
  // Deltas, ghost lines, highlight bands and the reset button all measure
  // from here, so any amount of nudging reads as one move from the original.
  const originEdges = selected && {
    start_s: selected.original_start_s ?? selected.start_s,
    end_s: selected.original_end_s ?? selected.end_s,
  };
  // The shaded room on either side is the neighbors' audio: each side is
  // labeled with that track, with a dashed guide where it begins or ends if
  // that edge is in view.
  const selectedKinds = selected ? kindsAt(selectedIndex) : null;

  const neighborRange = (() => {
    if (!edges) return null;
    const prev = tracks[selectedIndex - 1];
    const following = nextOf(selectedIndex);
    const guides = [];
    const cuts = [];
    // Every other track that falls inside the window is shaded and labeled,
    // clipped to the window, so a short neighbor does not leave the track
    // beyond it anonymous.
    const segments = tracks
      .filter((t) => t.id !== selected.id && t.end_s > span.start && t.start_s < span.end)
      .map((t) => ({
        name: `seg-${t.id}`,
        start: Math.max(t.start_s, span.start) - span.start,
        end: Math.min(t.end_s, span.end) - span.start,
        label: t.title,
        side: t.start_s < selected.start_s ? "before" : "after",
        boundary: t.start_s > span.start && t.id !== following?.id,
      }));
    // A seam's neighbor moves with it, so the space opened by dragging a seam
    // is not a cut; only trim sides can have dropped audio next to them.
    if (prev && selectedKinds.startKind === "trim" && edges.start_s - prev.end_s > 0.0005) {
      cuts.push({ name: "before", start: prev.end_s - span.start, end: edges.start_s - span.start });
    }
    if (following && selectedKinds.endKind === "trim" && following.start_s - edges.end_s > 0.0005) {
      cuts.push({ name: "after", start: edges.end_s - span.start, end: following.start_s - span.start });
    }
    // Everything an edge has moved across since the track was picked is
    // highlighted, with a ghost line fixed where the edge started, so the
    // total change stays visible in the audio whether dragging or settled.
    const shifts = [];
    if (originEdges) {
      ["start_s", "end_s"].forEach((key) => {
        const now = dragEdges ? dragEdges[key] : selected[key];
        const from = originEdges[key];
        if (Math.abs(now - from) < 0.05) return;
        const side = key === "start_s" ? "start" : "end";
        const kind = selectedKinds[`${side}Kind`] === "seam" ? "seam" : side;
        shifts.push({
          name: key,
          kind,
          start: Math.min(now, from) - span.start,
          end: Math.max(now, from) - span.start,
          settled: !dragEdges,
        });
        guides.push({ name: `origin-${key}`, kind, seconds: from - span.start, label: `${from.toFixed(1)}s`, origin: true });
      });
    }
    return {
      start: edges.start_s - span.start,
      end: edges.end_s - span.start,
      segments,
      guides,
      cuts,
      shifts,
    };
  })();

  const markers = edges
    ? [
        {
          name: "start",
          seconds: edges.start_s - span.start,
          seam: selectedKinds.startKind === "seam",
          label: selectedKinds.startKind === "seam" ? "seam" : "start",
          color: selectedKinds.startKind === "seam" ? SEAM_COLOR : "var(--blue)",
        },
        {
          name: "end",
          seconds: edges.end_s - span.start,
          seam: selectedKinds.endKind === "seam",
          label: selectedKinds.endKind === "seam" ? "seam" : "end",
          color: selectedKinds.endKind === "seam" ? SEAM_COLOR : "var(--alert-red)",
        },
      ]
    : [];

  // Dragging a seam moves the boundary, so the neighbor gives up or takes on
  // that audio and nothing is dropped; the seam can travel anywhere inside the
  // two tracks. Dragging a trim moves only this track's edge, and can go as
  // far as the neighbor's edge (or the timeline's end).
  const moveEdge = (name, seconds) => {
    if (!selected) return;
    const t = span.start + seconds;
    const prev = tracks[selectedIndex - 1];
    const following = nextOf(selectedIndex);
    const { startKind, endKind } = kindsAt(selectedIndex);
    setDragEdges((current) => {
      const base = current || { start_s: selected.start_s, end_s: selected.end_s };
      if (name === "start") {
        const low = startKind === "seam" ? prev.start_s + MIN_TRACK_S : prev ? prev.end_s : 0;
        return { ...base, start_s: Math.min(Math.max(round1(t), low), base.end_s - MIN_TRACK_S) };
      }
      const high = endKind === "seam" ? following.end_s - MIN_TRACK_S : following ? following.start_s : staging.total_s;
      return { ...base, end_s: Math.max(Math.min(round1(t), high), base.start_s + MIN_TRACK_S) };
    });
  };

  // The dragged position stays on screen until the server answers, so the
  // marker does not flash back to its old spot while the request is in flight.
  const commitEdge = (name) => {
    if (!dragEdges || !selected) return;
    const key = name === "start" ? "start_s" : "end_s";
    const value = dragEdges[key];
    if (Math.abs(value - selected[key]) <= 0.001) {
      setDragEdges(null);
      return;
    }
    const prev = tracks[selectedIndex - 1];
    const following = nextOf(selectedIndex);
    const { startKind, endKind } = kindsAt(selectedIndex);
    let request;
    if (name === "start" && startKind === "seam") {
      request = boundary(prev, value);
    } else if (name === "end" && endKind === "seam") {
      request = boundary(selected, value);
    } else {
      request = patch(selected, { [key]: value });
    }
    request.finally(() => setDragEdges(null));
  };

  // Puts both edges back where the ingest placed them, using the same
  // seam-or-trim rules as a drag so neighbors follow a seam.
  const edgesDirty = originEdges && selected &&
    (Math.abs(selected.start_s - originEdges.start_s) > 0.001 || Math.abs(selected.end_s - originEdges.end_s) > 0.001);
  const resetEdges = async () => {
    if (!edgesDirty) return;
    const prev = tracks[selectedIndex - 1];
    const { startKind, endKind } = kindsAt(selectedIndex);
    if (Math.abs(selected.start_s - originEdges.start_s) > 0.001) {
      if (startKind === "seam") await boundary(prev, originEdges.start_s);
      else await patch(selected, { start_s: originEdges.start_s });
    }
    const current = tracksRef.current.find((t) => t.id === selected.id) || selected;
    if (Math.abs(current.end_s - originEdges.end_s) > 0.001) {
      if (endKind === "seam") await boundary(current, originEdges.end_s);
      else await patch(current, { end_s: originEdges.end_s });
    }
  };

  // The scrubber and transport live inside whichever track is expanded, so
  // the page reads as a track list rather than a player with a list under it.
  const transport = selected && (
    <div className="admin-staging-transport">
      <WaveformScrubber
        waveformUrl={null}
        duration={span.end - span.start}
        playheadSeconds={playhead == null ? null : playhead - span.start}
        markers={markers}
        range={edges && neighborRange}
        peaks={peakData && { data: peakData, rate: staging.peaks_rate, offset: span.start }}
        onMarkerChange={moveEdge}
        onMarkerCommit={commitEdge}
        onSeek={(s) => {
          const t = span.start + s;
          setPlayhead(t);
          if (playing) playerRef.current.seek(t);
        }}
      />
      <div className="admin-audio-actions">
        <button
          type="button"
          className="admin-trim-play"
          title={loading ? "Loading audio" : playing ? "Pause" : "Play"}
          aria-label={loading ? "Loading audio" : playing ? "Pause" : "Play"}
          disabled={loading}
          onClick={(e) => {
            e.stopPropagation();
            if (playing) {
              stop();
              return;
            }
            playFromPlayhead();
          }}
        >
          <FontAwesomeIcon icon={loading ? faSpinner : playing ? faPause : faPlay} spin={loading} />
        </button>
        <button
          type="button"
          className="admin-trim-play"
          title="Restart"
          aria-label="Restart"
          onClick={(e) => {
            e.stopPropagation();
            play(selected);
          }}
        >
          <FontAwesomeIcon icon={faArrowRotateLeft} />
        </button>
        <button
          type="button"
          className="admin-trim-play"
          title="Reset start and end to where the ingest placed them"
          aria-label="Reset start and end"
          disabled={!edgesDirty || busy}
          onClick={(e) => {
            e.stopPropagation();
            resetEdges();
          }}
        >
          <FontAwesomeIcon icon={faClockRotateLeft} />
        </button>
        {playhead != null && (
          <span className="admin-audio-status">{playhead.toFixed(1)}s</span>
        )}
      </div>
    </div>
  );

  // While the commit renders, the editor gives way to a progress card like
  // the import page's: the tracks are no longer editable and the job reports
  // which one it is on.
  if (jobBusy) {
    return (
      <div className="admin-staging">
        <section className="admin-card admin-card-narrow">
          <header className="admin-card-header">
            <h2>Committing {formatDate(show.date)}</h2>
          </header>
          <div className="admin-card-body">
            <div className="admin-stage">
              <div className="admin-stage-progress">
                <div className="admin-stage-bar" role="progressbar" aria-valuenow={progress ?? 0} aria-valuemin={0} aria-valuemax={100}>
                  <div className="admin-stage-fill" style={{ width: `${progress ?? 0}%` }} />
                </div>
                <span className="admin-stage-pct">{Math.round(progress ?? 0)}%</span>
              </div>
              <div className="admin-stage-detail">
                <Spinner accent />
                <span>{status || "Starting..."}</span>
              </div>
            </div>
          </div>
        </section>
      </div>
    );
  }

  return (
    <div className="admin-staging">
      {(error || jobError) && <p className="admin-error">{error || jobError}</p>}

      <div className="admin-tracks-toolbar">
        <AddSetMenu
          options={addableSets}
          disabled={busy || jobBusy}
          onAdd={(set) => setPendingSets((prev) => [...prev, set])}
        />
      </div>

      <ul className="admin-staging-tracks">
        {groups.map((group, groupIndex) => [
          <li key={`set-${group.set}`} className="admin-staging-set-header">
            <span>{setName(group.set)}</span>
            {group.pending && (
              <button
                type="button"
                className="admin-trash-button admin-set-dismiss"
                title="Remove this empty set"
                onClick={() => setPendingSets((prev) => prev.filter((s) => s !== group.set))}
              >
                <FontAwesomeIcon icon={faTrashCan} />
              </button>
            )}
            {group.tracks.length > 0 && (
              <span className="admin-set-duration">
                {formatDurationShow(group.tracks.reduce((sum, { track }) => sum + (track.end_s - track.start_s), 0) * 1000)}
              </span>
            )}
          </li>,
          ...group.tracks.map(({ track, index }, itemIndex) => (
          <StagedTrackRow
            key={track.id}
            track={track}
            prev={tracks[index - 1] || null}
            next={nextOf(index)}
            startKind={kindsAt(index).startKind}
            endKind={kindsAt(index).endKind}
            moveUpTo={itemIndex === 0 && groupIndex > 0 ? groups[groupIndex - 1].set : null}
            moveDownTo={itemIndex === group.tracks.length - 1 && groupIndex < groups.length - 1 ? groups[groupIndex + 1].set : null}
            onChangeSet={changeSet}
            setName={setName}
            onPlayFromSeam={playFromSeam}
            selected={selected?.id === track.id}
            onSelect={(t) => setSelectedId(t.id)}
            onPlay={play}
            onPatch={patch}
            onSplit={split}
            onCombine={combine}
            onUncombine={uncombine}
            onBoundary={boundary}
            onRemove={remove}
            playhead={selectedIndex === index ? playhead : null}
            transport={selectedIndex === index ? transport : null}
            busy={busy || jobBusy}
            loading={loading}
          />
          )),
        ])}
      </ul>

      <div className="admin-staging-commit">
        <button
          type="button"
          disabled={busy || jobBusy || tracks.length === 0}
          title="Render the tracks and create the show"
          onClick={commit}
        >
          <FontAwesomeIcon icon={faCheck} /> Commit
        </button>
        <button type="button" className="admin-danger" disabled={busy || jobBusy} onClick={discard}>
          <FontAwesomeIcon icon={faTrashCan} /> Discard
        </button>
      </div>
      {commitIssuesShown && commitIssues.length > 0 && (
        <IssueList issues={commitIssues} label="blocking the commit" />
      )}
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
