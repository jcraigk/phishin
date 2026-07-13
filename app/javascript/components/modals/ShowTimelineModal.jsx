import React from "react";
import { formatDate, formatDurationTrack } from "../helpers/utils";

const SEGMENT_COLORS = [
  "#8fd6a9",
  "#f4936f",
  "#f5d76e",
  "#8bbede",
  "#b8a3dc",
  "#f2a2c5",
  "#d9b98c"
];

const ShowTimelineModal = ({ show }) => {
  const tracksWithAudio = show.tracks.filter((track) =>
    track.audio_status !== "missing" && track.duration > 0
  );

  const sets = Object.entries(
    tracksWithAudio.reduce((groups, track) => {
      (groups[track.set_name] = groups[track.set_name] || []).push(track);
      return groups;
    }, {})
  ).map(([setName, setTracks]) => ({
    setName,
    setTracks,
    setDuration: setTracks.reduce((total, track) => total + track.duration, 0)
  }));

  const maxSetDuration = Math.max(...sets.map((set) => set.setDuration), 1);

  return (
    <div className="wide-modal show-timeline">
      <h2 className="title">Timeline</h2>
      <h3 className="subtitle">{formatDate(show.date)} • {show.venue_name}</h3>

      {sets.map(({ setName, setTracks, setDuration }) => (
        <div className="timeline-set" key={setName}>
          <div className="timeline-set-header">
            <span className="timeline-set-name">{setName}</span>
            <span className="timeline-set-duration">
              {formatDurationTrack(setDuration)}
            </span>
          </div>
          <div
            className="timeline-set-bar"
            style={{ width: `${(setDuration / maxSetDuration) * 100}%` }}
          >
            <div className="timeline-segments">
              {setTracks.map((track, index) => (
                <div
                  key={track.id}
                  className="timeline-segment"
                  style={{
                    width: `${(track.duration / setDuration) * 100}%`,
                    backgroundColor: SEGMENT_COLORS[index % SEGMENT_COLORS.length]
                  }}
                  title={`${track.title} (${formatDurationTrack(track.duration)})`}
                >
                  <span className="timeline-segment-title">{track.title}</span>
                </div>
              ))}
            </div>
            <div className="timeline-durations">
              {setTracks.map((track, index) => (
                <div
                  key={track.id}
                  className="timeline-segment-duration"
                  style={{
                    width: `${(track.duration / setDuration) * 100}%`,
                    color: SEGMENT_COLORS[index % SEGMENT_COLORS.length]
                  }}
                >
                  {formatDurationTrack(track.duration)}
                </div>
              ))}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
};

export default ShowTimelineModal;
