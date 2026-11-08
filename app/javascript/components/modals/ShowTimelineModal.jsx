import React, { useLayoutEffect, useRef, useState } from "react";
import { formatDate, formatDurationTrack } from "../helpers/utils";
import { layoutLabels } from "../helpers/timelineLabels";

const SEGMENT_COLORS = [
  "#8fd6a9",
  "#f4936f",
  "#f5d76e",
  "#8bbede",
  "#b8a3dc",
  "#f2a2c5",
  "#d9b98c"
];

const LONGEST_SET_HEIGHT = 440;
const ESTIMATED_LABEL_HEIGHT = 22;

const sameHeights = (a, b) => a.length === b.length && a.every((height, i) => height === b[i]);

const TimelineSet = ({ setName, setTracks, setDuration, pixelsPerSecond }) => {
  const labelsRef = useRef(null);
  const labelRefs = useRef([]);
  const [labelHeights, setLabelHeights] = useState(() =>
    setTracks.map(() => ESTIMATED_LABEL_HEIGHT)
  );

  useLayoutEffect(() => {
    const measure = () => {
      const measured = setTracks.map((_, index) => labelRefs.current[index].offsetHeight);
      setLabelHeights((current) => (sameHeights(current, measured) ? current : measured));
    };
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(labelsRef.current);
    return () => observer.disconnect();
  }, [setTracks]);

  let elapsed = 0;
  const segments = setTracks.map((track, index) => {
    const top = elapsed * pixelsPerSecond;
    const height = track.duration * pixelsPerSecond;
    elapsed += track.duration;
    return { track, top, height, color: SEGMENT_COLORS[index % SEGMENT_COLORS.length] };
  });

  const segmentCenters = segments.map(({ top, height }) => top + height / 2);
  const labelTops = layoutLabels(segmentCenters, labelHeights);
  const barHeight = setDuration * pixelsPerSecond;
  const lastIndex = labelTops.length - 1;
  const bodyHeight = Math.max(barHeight, labelTops[lastIndex] + labelHeights[lastIndex]);

  return (
    <div className="timeline-set">
      <div className="timeline-set-header">
        <span className="timeline-set-name">{setName}</span>
        <span className="timeline-set-duration">{formatDurationTrack(setDuration)}</span>
      </div>
      <div className="timeline-set-body" style={{ height: `${bodyHeight}px` }}>
        <div className="timeline-set-bar" style={{ height: `${barHeight}px` }}>
          {segments.map(({ track, height, color }) => (
            <div
              key={track.id}
              className="timeline-segment"
              style={{ height: `${height}px`, backgroundColor: color }}
              title={`${track.title} (${formatDurationTrack(track.duration)})`}
            />
          ))}
        </div>
        <div className="timeline-labels" ref={labelsRef}>
          {segments.map(({ track, color }, index) => (
            <div
              key={track.id}
              ref={(el) => (labelRefs.current[index] = el)}
              className="timeline-label"
              style={{ top: `${labelTops[index]}px` }}
            >
              <span className="timeline-label-title">{track.title}</span>
              <span className="timeline-label-duration" style={{ color }}>
                {formatDurationTrack(track.duration)}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

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
  const pixelsPerSecond = LONGEST_SET_HEIGHT / maxSetDuration;

  return (
    <div className="wide-modal show-timeline">
      <h2 className="title">Timeline</h2>
      <h3 className="subtitle">{formatDate(show.date)} • {show.venue_name}</h3>

      <div className="timeline-sets">
        {sets.map((set) => (
          <TimelineSet key={set.setName} {...set} pixelsPerSecond={pixelsPerSecond} />
        ))}
      </div>
    </div>
  );
};

export default ShowTimelineModal;
