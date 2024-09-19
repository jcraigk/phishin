// TagBadges.jsx
import React from "react";
import { Tooltip } from "react-tooltip";
import { useOutletContext } from "react-router-dom";

const TagBadges = ({ tags }) => {
  const { openModal } = useOutletContext();

  const groupedTags = tags
    .sort((a, b) => a.priority - b.priority || (a.starts_at_second || 0) - (b.starts_at_second || 0))
    .reduce((acc, tag) => {
      const group = acc[tag.name] || [];
      group.push(tag);
      acc[tag.name] = group;
      return acc;
    }, {});

  const handleClick = (tagGroup, event) => {
    if (!tagGroup[0].notes && !tagGroup[0].transcript) {
      return;
    }
    event.stopPropagation();
    event.preventDefault();

    const modalContent = (
      <>
        <h2 className="title mb-5">{tagGroup[0].name}</h2>
        <div>
          {tagGroup.map((tag, index) => (
            <div key={index}>
              <h3 className="subtitle">{tag.notes}</h3>
              {tag.transcript && (
                <p>
                  <strong>TRANSCRIPT:</strong>
                  <br />
                  <span
                    dangerouslySetInnerHTML={{ __html: tag.transcript.replace(/\n/g, "<br />") }}
                  />
                </p>
              )}
            </div>
          ))}
        </div>
      </>
    );
    openModal(modalContent);
  };

  const formatTimeRange = (tag) => {
    if (!tag.starts_at_second && !tag.ends_at_second) return "";
    const start = formatTimestamp(tag.starts_at_second);
    const end = formatTimestamp(tag.ends_at_second);
    return start && end ? `between ${start} and ${end}` : start ? `at ${start}` : "";
  };

  const formatTimestamp = (seconds) => {
    if (!seconds) return null;
    const minutes = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${minutes}:${secs.toString().padStart(2, "0")}`;
  };

  const tooltipForTagStack = (tagGroup) => {
    const hasNotesOrTranscript = tagGroup.some(tag => tag.notes || tag.transcript);

    if (!hasNotesOrTranscript) {
      return tagGroup[0].description || "";
    }

    return tagGroup.map((tag) => {
      let timeRange = formatTimeRange(tag);
      let tooltipPart = tag.notes ? `${tag.notes} ${timeRange}`.trim() : "";
      return tooltipPart.trim();
    }).filter(Boolean).join(", ");
  };

  return (
    <div className="tag-badges-container">
      {Object.entries(groupedTags).map(([tagName, tagGroup]) => {
        const count = tagGroup.length;
        const title = `${tagName} ${count > 1 ? `(${count})` : ""}`;
        const tooltipId = `tooltip-${tagName}`;
        const isClickable = tagGroup[0].notes || tagGroup[0].transcript;

        return (
          <div
            key={tagName}
            className="tag-badge"
            data-tooltip-id={tooltipId}
            data-tooltip-content={tooltipForTagStack(tagGroup)}
            onClick={isClickable ? (event) => handleClick(tagGroup, event) : null}
            style={{
              backgroundColor: "$header-gray",
              cursor: isClickable ? "pointer" : "default",
            }}
          >
            {title}
            <Tooltip id={tooltipId} className="custom-tooltip" />
          </div>
        );
      })}
    </div>
  );
};

export default TagBadges;
