import React from "react";
import { useOutletContext } from "react-router-dom";
import { Tooltip } from "react-tooltip";

const TagBadges = ({ tags, parentId }) => {
  const { openAppModal } = useOutletContext();

  const groupedTags = tags
    .sort((a, b) => a.priority - b.priority || (a.starts_at_second || 0) - (b.starts_at_second || 0))
    .reduce((acc, tag) => {
      const group = acc[tag.name] || [];
      group.push(tag);
      acc[tag.name] = group;
      return acc;
    }, {});

  const handleClick = (event) => {
    event.stopPropagation();
    event.preventDefault();

    const modalContent = (
      <>
        <div className="tags-container">
          {Object.entries(groupedTags).map(([tagName, tagGroup], index) => (
            <div key={index} className="tag-group mb-4">
              <div className="tag-badge mb-2">
                {tagName} {tagGroup.length > 1 ? `(${tagGroup.length})` : ""}
              </div>
              <div className="tag-content">
                {tagGroup.map((tag, idx) => (
                  <div key={idx} className="tag-details">
                    {tag.transcript ? (
                      <>
                        <p className="mb-4">{tag.notes || tag.description}</p>
                        <p className="has-text-weight-bold mb-2">TRANSCRIPT:</p>
                        <div
                          className="box"
                          dangerouslySetInnerHTML={{ __html: tag.transcript.replace(/\n/g, "<br />") }}
                        ></div>
                      </>
                    ) : (
                      <ul className="notes-list">
                        <li>{tag.notes || tag.description}</li>
                      </ul>
                    )}
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      </>
    );

    openAppModal(modalContent);
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
    <div className="tag-badges-container" onClick={handleClick}>
      {Object.entries(groupedTags).map(([tagName, tagGroup]) => {
        const count = tagGroup.length;
        const title = `${tagName} ${count > 1 ? `(${count})` : ""}`;
        const tooltipId = `tooltip-${parentId}-${tagName}`;

        return (
          <div
            key={tooltipId}
            className="tag-badge"
            data-tooltip-id={tooltipId}
            data-tooltip-content={tooltipForTagStack(tagGroup)}
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
