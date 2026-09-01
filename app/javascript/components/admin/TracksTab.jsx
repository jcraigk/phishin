import React, { useContext, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faTrashCan, faCheck, faXmark } from "@fortawesome/free-solid-svg-icons";
import { EditorContext } from "./AdminShowEditor";
import TrackRow from "./TrackRow";
import useJobRunner from "./useJobRunner";
import { adminPost, adminPut } from "./adminApi";

const GapBanner = () => {
  const { show, setGapsStale } = useContext(EditorContext);
  const { run, busy, status, error } = useJobRunner();

  return (
    <div className="admin-gap-banner">
      <span>Set lists changed. Recompute gaps.</span>
      <button
        type="button"
        disabled={busy}
        onClick={() =>
          run(
            () => adminPost(`/shows/${show.date}/recompute_gaps`),
            () => setGapsStale(false)
          )
        }
      >
        Recompute Gaps
      </button>
      {status && <span className="admin-audio-status">{status}</span>}
      {error && <span className="admin-error">{error}</span>}
    </div>
  );
};

const SETS = ["S", "1", "2", "3", "4", "E", "E2", "E3"];

const SET_NAMES = {
  P: "Pre-Show",
  S: "Soundcheck",
  1: "Set 1",
  2: "Set 2",
  3: "Set 3",
  4: "Set 4",
  E: "Encore",
  E2: "Encore 2",
  E3: "Encore 3",
};

const setName = (set) => SET_NAMES[set] || "Unknown Set";

// Groups consecutive runs by position rather than sorting by set, so a track
// filed under the wrong set stays visible where it actually sits.
const groupBySet = (tracks) =>
  tracks.reduce((groups, track, index) => {
    const last = groups[groups.length - 1];
    if (last && last.set === track.set) {
      last.tracks.push({ track, index });
    } else {
      groups.push({ set: track.set, tracks: [{ track, index }] });
    }
    return groups;
  }, []);

// Pending sets are empty groups the admin just added; they exist only in the
// browser until a track is dropped in, because a set is nothing but the value
// on its tracks. Each is slotted where its set ranks canonically.
const withPendingSets = (groups, pendingSets) => {
  const merged = [...groups];
  for (const set of pendingSets) {
    if (merged.some((group) => group.set === set)) continue;
    const rank = SETS.indexOf(set);
    let at = merged.length;
    for (let i = 0; i < merged.length; i += 1) {
      if (SETS.indexOf(merged[i].set) > rank) {
        at = i;
        break;
      }
    }
    merged.splice(at, 0, { set, tracks: [], pending: true });
  }
  // A drop on an empty group must land where the group sits, not at the end
  // of the show, so each pending group points at the first track below it.
  for (let i = 0; i < merged.length; i += 1) {
    if (!merged[i].pending) continue;
    const next = merged.slice(i + 1).find((group) => group.tracks.length > 0);
    merged[i].dropIndex = next ? next.tracks[0].index : null;
  }
  return merged;
};

const TracksTab = () => {
  const { show, setShow, setError, gapsStale } = useContext(EditorContext);
  const [busy, setBusy] = useState(false);
  const [pendingSets, setPendingSets] = useState([]);
  const [repositioning, setRepositioning] = useState(null);
  const [targetPosition, setTargetPosition] = useState(1);
  const [targetSet, setTargetSet] = useState("1");

  const tracks = show.tracks;

  // The payload does not say which staged file backs an attached track, so the
  // summary reports tracks still awaiting audio rather than claiming which files
  // are unused.
  const missingAudioCount = tracks.filter(
    (t) => t.audio_status === "missing"
  ).length;

  const commitOrder = async (ordered, sets) => {
    setError(null);
    setBusy(true);
    try {
      setShow(
        await adminPut(`/shows/${show.date}/track_order`, {
          track_ids: ordered.map((t) => t.id),
          sets,
        })
      );
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  const openReposition = (track) => {
    setTargetPosition(track.position);
    setTargetSet(track.set);
    setRepositioning(track);
  };

  // A position determines its set except at a boundary, where the slot at the
  // end of one set is the same slot as the start of the next. The choices are
  // the sets of the neighboring tracks (plus any just-added empty set), and
  // the earlier one is the default.
  const slotNeighbors = (track, position) => {
    const ordered = tracks.filter((t) => t.id !== track.id);
    ordered.splice(position - 1, 0, track);
    const at = ordered.indexOf(track);
    return { above: ordered[at - 1], below: ordered[at + 1] };
  };

  const setChoicesFor = (track, position) => {
    const { above, below } = slotNeighbors(track, position);
    const choices = [
      ...new Set([above?.set, below?.set, track.set, ...pendingSets].filter(Boolean)),
    ];
    if (choices.length === 0) return SETS;
    return SETS.filter((set) => choices.includes(set));
  };

  const chooseTargetPosition = (position) => {
    setTargetPosition(position);
    const { above, below } = slotNeighbors(repositioning, position);
    setTargetSet(above?.set || below?.set || repositioning.set);
  };

  const applyReposition = () => {
    const track = repositioning;
    setRepositioning(null);
    setPendingSets((prev) => prev.filter((set) => set !== targetSet));
    const from = tracks.indexOf(track);
    const ordered = [...tracks];
    ordered.splice(from, 1);
    ordered.splice(targetPosition - 1, 0, track);
    const sets = track.set === targetSet ? {} : { [track.id]: targetSet };
    if (from === targetPosition - 1 && Object.keys(sets).length === 0) return;
    commitOrder(ordered, sets);
  };

  // Removing a set does not remove its tracks: they fold into the set above,
  // or the one below when the removed set is first. Order never changes, so
  // this is a pure set reassignment through the same reorder endpoint.
  const removeSet = (group) => {
    const groups = groupBySet(tracks);
    const at = groups.findIndex((g) => g.set === group.set && g.tracks[0]?.index === group.tracks[0]?.index);
    const neighbor = groups[at - 1] || groups[at + 1];
    if (!neighbor) {
      setError("The only set cannot be removed.");
      return;
    }
    if (
      !window.confirm(
        `Remove ${setName(group.set)}? Its ${group.tracks.length} track${group.tracks.length === 1 ? "" : "s"} move to ${setName(neighbor.set)}.`
      )
    )
      return;
    const sets = Object.fromEntries(
      group.tracks.map(({ track }) => [track.id, neighbor.set])
    );
    commitOrder(tracks, sets);
  };

  // The new track takes the set of the track above its slot, since position
  // inside a set is what determines set membership now.
  const insertTrack = async () => {
    const position = window.prompt(
      "Insert at position",
      String(tracks.length + 1)
    );
    if (position === null) return;
    const title = window.prompt("Track title", "");
    if (title === null) return;
    const set = tracks[Number(position) - 2]?.set || tracks[0]?.set || "1";

    setError(null);
    setBusy(true);
    try {
      setShow(
        await adminPost(`/shows/${show.date}/tracks`, {
          position: Number(position),
          title,
          set,
        })
      );
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="admin-tracks-tab">
      {gapsStale && <GapBanner />}
      <div className="admin-tracks-toolbar">
        <button type="button" onClick={insertTrack} disabled={busy}>
          Insert track
        </button>
        <select
          value=""
          aria-label="Add set"
          disabled={busy}
          onChange={(e) => {
            if (e.target.value !== "") {
              setPendingSets((prev) => [...prev, e.target.value]);
            }
          }}
        >
          <option value="">Add set</option>
          {SETS.filter(
            (set) =>
              !tracks.some((t) => t.set === set) && !pendingSets.includes(set)
          ).map((set) => (
            <option key={set} value={set}>{setName(set)}</option>
          ))}
        </select>
        {(show.staged_audio.length > 0 || missingAudioCount > 0) && (
          <span className="admin-staged-summary">
            {show.staged_audio.length > 0 &&
              `${show.staged_audio.length} staged file${
                show.staged_audio.length === 1 ? "" : "s"
              }`}
            {show.staged_audio.length > 0 && missingAudioCount > 0 && ", "}
            {missingAudioCount > 0 &&
              `${missingAudioCount} track${
                missingAudioCount === 1 ? "" : "s"
              } awaiting audio`}
          </span>
        )}
      </div>

      {tracks.length === 0 ? (
        <p>This show has no tracks yet.</p>
      ) : (
        <table className="admin-tracks-table">
          {withPendingSets(groupBySet(tracks), pendingSets).map((group) => {
            const firstIndex =
              group.tracks[0]?.index ?? group.dropIndex ?? tracks.length;
            const headerKey = `set-${firstIndex}`;
            return (
              <tbody key={headerKey} className="admin-set-group">
                <tr className="admin-set-header">
                  <th colSpan={7}>
                    {setName(group.set)}
                    <button
                      type="button"
                      className="admin-trash-button admin-set-dismiss"
                      aria-label={`Remove ${setName(group.set)}`}
                      title={
                        group.pending
                          ? "Remove this empty set"
                          : "Remove this set and fold its tracks into the neighboring set"
                      }
                      onClick={() =>
                        group.pending
                          ? setPendingSets((prev) =>
                              prev.filter((set) => set !== group.set)
                            )
                          : removeSet(group)
                      }
                    >
                      <FontAwesomeIcon icon={faTrashCan} />
                    </button>
                  </th>
                </tr>
                {group.tracks.map(({ track, index }) => (
                  <TrackRow
                    key={track.id}
                    track={track}
                    next={tracks[index + 1] || null}
                    stagedOptions={show.staged_audio}
                    onReposition={() => openReposition(track)}
                  />
                ))}
              </tbody>
            );
          })}
        </table>
      )}

      {repositioning && (
        <div className="admin-modal-overlay" onClick={() => setRepositioning(null)}>
          <div className="admin-modal" onClick={(e) => e.stopPropagation()}>
            <h3>Reposition &quot;{repositioning.title}&quot;</h3>
            <label className="admin-modal-field">
              <span>Position</span>
              <select
                value={targetPosition}
                onChange={(e) => chooseTargetPosition(Number(e.target.value))}
              >
                {tracks.map((t, i) => (
                  <option key={t.id} value={i + 1}>
                    {i + 1}
                    {t.id === repositioning.id ? ". (current)" : `. ${t.title}`}
                  </option>
                ))}
              </select>
            </label>
            <label className="admin-modal-field">
              <span>Set</span>
              <select value={targetSet} onChange={(e) => setTargetSet(e.target.value)}>
                {setChoicesFor(repositioning, targetPosition).map((set) => (
                  <option key={set} value={set}>{setName(set)}</option>
                ))}
              </select>
            </label>
            <div className="admin-modal-actions">
              <button type="button" disabled={busy} onClick={applyReposition}>
                <FontAwesomeIcon icon={faCheck} /> Move
              </button>
              <button type="button" onClick={() => setRepositioning(null)}>
                <FontAwesomeIcon icon={faXmark} /> Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default TracksTab;
