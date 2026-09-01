import React, { useContext, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import TrackRow from "./TrackRow";
import { adminPost, adminPut } from "./adminApi";

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
  const { show, setShow, setError } = useContext(EditorContext);
  const [dragIndex, setDragIndex] = useState(null);
  const [overIndex, setOverIndex] = useState(null);
  const [busy, setBusy] = useState(false);
  const [pendingSets, setPendingSets] = useState([]);

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

  // Dropping on a row takes that row's slot; dropping on a set header puts
  // the track first in that set. Either way the track adopts the target set.
  const handleDrop = (targetIndex, targetSet, { before = false } = {}) => {
    setOverIndex(null);
    if (dragIndex === null) return;
    setPendingSets((prev) => prev.filter((set) => set !== targetSet));
    const moved = tracks[dragIndex];
    const sets = moved.set === targetSet ? {} : { [moved.id]: targetSet };
    const insertAt =
      before && dragIndex < targetIndex ? targetIndex - 1 : targetIndex;
    if (dragIndex === insertAt && Object.keys(sets).length === 0) {
      setDragIndex(null);
      return;
    }
    const ordered = [...tracks];
    ordered.splice(dragIndex, 1);
    ordered.splice(insertAt, 0, moved);
    setDragIndex(null);
    commitOrder(ordered, sets);
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
        <span className="admin-staged-summary">
          {show.staged_audio.length} staged file
          {show.staged_audio.length === 1 ? "" : "s"}
          {missingAudioCount > 0 &&
            `, ${missingAudioCount} track${
              missingAudioCount === 1 ? "" : "s"
            } awaiting audio`}
        </span>
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
                <tr
                  className={`admin-set-header${
                    overIndex === headerKey ? " is-drag-over" : ""
                  }`}
                  onDragOver={(e) => {
                    e.preventDefault();
                    e.dataTransfer.dropEffect = "move";
                    setOverIndex(headerKey);
                  }}
                  onDrop={(e) => {
                    e.preventDefault();
                    handleDrop(firstIndex, group.set, { before: true });
                  }}
                >
                  <th colSpan={8}>
                    {setName(group.set)}
                    {group.pending && (
                      <button
                        type="button"
                        className="admin-set-dismiss"
                        aria-label={`Remove empty ${setName(group.set)}`}
                        onClick={() =>
                          setPendingSets((prev) =>
                            prev.filter((set) => set !== group.set)
                          )
                        }
                      >
                        &times;
                      </button>
                    )}
                  </th>
                </tr>
                {group.tracks.map(({ track, index }) => (
                  <TrackRow
                    key={track.id}
                    track={track}
                    stagedOptions={show.staged_audio}
                    dragging={overIndex === index}
                    onDragStart={(e) => {
                      setDragIndex(index);
                      e.dataTransfer.effectAllowed = "move";
                      e.dataTransfer.setData("text/plain", String(index));
                    }}
                    onDragOver={(e) => {
                      e.preventDefault();
                      e.dataTransfer.dropEffect = "move";
                      setOverIndex(index);
                    }}
                    onDrop={(e) => {
                      e.preventDefault();
                      handleDrop(index, group.set);
                    }}
                    onDragEnd={() => {
                      setDragIndex(null);
                      setOverIndex(null);
                    }}
                  />
                ))}
              </tbody>
            );
          })}
        </table>
      )}
    </div>
  );
};

export default TracksTab;
