export const SETS = ["S", "1", "2", "3", "4", "E", "E2", "E3"];

export const SET_NAMES = {
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

export const setName = (set) => SET_NAMES[set] || "Unknown Set";

// Groups consecutive runs by position rather than sorting by set, so a track
// filed under the wrong set stays visible where it actually sits.
export const groupBySet = (tracks) =>
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
export const withPendingSets = (groups, pendingSets) => {
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

export const addableSets = (tracks, pendingSets) =>
  SETS.filter((set) => !tracks.some((t) => t.set === set) && !pendingSets.includes(set));
