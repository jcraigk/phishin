import React, { useLayoutEffect, useRef, useState } from "react";
import { formatDate, formatDurationTrack } from "../helpers/utils";
import { layoutLabels, pullLabelsLeft } from "../helpers/timelineLabels";

const SEGMENT_COLORS = [
  "#8fd6a9",
  "#f4936f",
  "#f5d76e",
  "#8bbede",
  "#b8a3dc",
  "#f2a2c5",
  "#d9b98c"
];

const LABEL_ANGLE = Math.PI / 4;
const LABEL_SIN = Math.sin(LABEL_ANGLE);
const LABEL_COS = Math.cos(LABEL_ANGLE);
const LABEL_GAP = 10;
const LABEL_SPACING = 1.2;

const sameMetrics = (a, b) => JSON.stringify(a) === JSON.stringify(b);

const layoutSets = (sets, maxSetDuration, metrics) => {
  const { width, labelHeight, labelWidths } = metrics;
  const extentOf = (track) => LABEL_COS * (labelWidths[track.id] + labelHeight / 2);
  const spacing = (labelHeight * LABEL_SPACING) / LABEL_SIN;

  const withCenters = sets.map((set) => {
    let elapsed = 0;
    const centers = set.setTracks.map((track) => {
      const center = (elapsed + track.duration / 2) / maxSetDuration;
      elapsed += track.duration;
      return center;
    });
    return { ...set, centers };
  });

  const longestBarWidth = withCenters.reduce((barWidth, set) =>
    set.setTracks.reduce((fit, track, index) =>
      Math.min(fit, (width - extentOf(track)) / set.centers[index]), barWidth), width);

  return withCenters.map((set) => {
    const ideal = set.centers.map((center) => center * longestBarWidth);
    const starts = layoutLabels(ideal, ideal.map(() => spacing));
    const anchors = pullLabelsLeft(
      starts.map((start) => start + spacing / 2),
      spacing,
      set.setTracks.map((track) => width - extentOf(track))
    );
    const labelsHeight = Math.max(...set.setTracks.map((track) =>
      LABEL_SIN * (labelWidths[track.id] + labelHeight / 2)));
    return {
      ...set,
      barWidth: (set.setDuration / maxSetDuration) * longestBarWidth,
      anchors,
      labelsHeight: LABEL_GAP + labelsHeight + labelHeight
    };
  });
};

const ShowTimelineModal = ({ show }) => {
  const containerRef = useRef(null);
  const labelRefs = useRef({});
  const [metrics, setMetrics] = useState(null);

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

  useLayoutEffect(() => {
    const measure = () => {
      if (!containerRef.current) return;
      const labelWidths = {};
      let labelHeight = 0;
      Object.entries(labelRefs.current).forEach(([id, el]) => {
        if (!el) return;
        labelWidths[id] = el.offsetWidth;
        labelHeight = Math.max(labelHeight, el.offsetHeight);
      });
      const next = { width: containerRef.current.clientWidth, labelHeight, labelWidths };
      setMetrics((current) => (sameMetrics(current, next) ? current : next));
    };
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(containerRef.current);
    document.fonts?.ready.then(measure);
    return () => observer.disconnect();
  }, []);

  const laidOut = metrics ? layoutSets(sets, maxSetDuration, metrics) : sets;

  return (
    <div className="wide-modal show-timeline">
      <h2 className="title">Timeline</h2>
      <h3 className="subtitle">{formatDate(show.date)} • {show.venue_name}</h3>

      <div className={`timeline-sets ${metrics ? "" : "is-measuring"}`} ref={containerRef}>
        {laidOut.map(({ setName, setTracks, setDuration, barWidth, anchors, labelsHeight }) => (
          <div className="timeline-set" key={setName}>
            <div className="timeline-set-header">
              <span className="timeline-set-name">{setName}</span>
              <span className="timeline-set-duration">{formatDurationTrack(setDuration)}</span>
            </div>
            <div className="timeline-set-bar" style={barWidth ? { width: `${barWidth}px` } : {}}>
              {setTracks.map((track, index) => (
                <div
                  key={track.id}
                  className="timeline-segment"
                  style={{
                    width: `${(track.duration / setDuration) * 100}%`,
                    backgroundColor: SEGMENT_COLORS[index % SEGMENT_COLORS.length]
                  }}
                  title={`${track.title} (${formatDurationTrack(track.duration)})`}
                />
              ))}
            </div>
            <div className="timeline-labels" style={labelsHeight ? { height: `${labelsHeight}px` } : {}}>
              {setTracks.map((track, index) => (
                <div
                  key={track.id}
                  ref={(el) => (labelRefs.current[track.id] = el)}
                  className="timeline-label"
                  style={anchors ? {
                    left: `${anchors[index]}px`,
                    top: `${LABEL_GAP - metrics.labelHeight / 2}px`
                  } : {}}
                >
                  <span className="timeline-label-title">{track.title}</span>
                  <span className="timeline-label-duration">{formatDurationTrack(track.duration)}</span>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default ShowTimelineModal;
