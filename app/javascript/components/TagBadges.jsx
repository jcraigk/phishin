import React, { useState } from "react";
import PropTypes from "prop-types";
import Modal from "react-modal";
import { Tooltip } from "react-tooltip"; // Import Tooltip correctly

Modal.setAppElement("body");

const TagBadges = ({ tags }) => {
  const [selectedTag, setSelectedTag] = useState(null);

  const groupedTags = tags
    .sort((a, b) => a.priority - b.priority || (a.starts_at_second || 0) - (b.starts_at_second || 0))
    .reduce((acc, tag) => {
      const group = acc[tag.name] || [];
      group.push(tag);
      acc[tag.name] = group;
      return acc;
    }, {});

  const handleClick = (tagGroup, event) => {
    event.stopPropagation(); // Prevent the click event from propagating to the Link
    event.preventDefault();  // Prevent the Link's default behavior (navigation)
    setSelectedTag(tagGroup);
  };

  const closeModal = () => {
    setSelectedTag(null);
  };

  const formatTimeRange = (tag) => {
    if (!tag.starts_at_second && !tag.ends_at_second) return null;
    const start = formatTimestamp(tag.starts_at_second);
    const end = formatTimestamp(tag.ends_at_second);
    return start && end ? `between ${start} and ${end}` : start ? `at ${start}` : null;
  };

  const formatTimestamp = (seconds) => {
    if (!seconds) return null;
    const minutes = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${minutes}:${secs.toString().padStart(2, '0')}`;
  };

  const tooltipForTagStack = (tagGroup) => {
    let tooltip = tagGroup.map((tag) => {
      let tooltipPart = tag.notes ? `${tag.notes} ${formatTimeRange(tag)}` : tag.name;
      return tooltipPart;
    }).join(", ");

    return tooltip || tagGroup[0].description || tagGroup[0].name;
  };

  return (
    <div className="tag-badges-container">
      {Object.entries(groupedTags).map(([tagName, tagGroup]) => {
        const count = tagGroup.length;
        const tag = tagGroup[0];
        const title = `${tagName} ${count > 1 ? `(${count})` : ""}`;
        const tooltipId = `tooltip-${tagName}`;

        return (
          <div
            key={tagName}
            className="tag-badge"
            data-tooltip-id={tooltipId} // Attach tooltip id
            data-tooltip-content={tooltipForTagStack(tagGroup)} // Attach tooltip content
            onClick={(event) => handleClick(tagGroup, event)}
            style={{ backgroundColor: "$header_gray" }}
          >
            {title}
            <Tooltip id={tooltipId} effect="solid" place="top" type="dark" className="custom-tooltip" />
          </div>
        );
      })}
      {selectedTag && (
        <Modal
          isOpen={!!selectedTag}
          onRequestClose={closeModal}
          contentLabel="Tag Details"
          className="Modal"
          overlayClassName="Overlay"
        >
          <h2>{selectedTag[0].name}</h2>
          <div>
            {selectedTag.map((tag, index) => (
              <div key={index}>
                <p><strong>Notes:</strong> {tag.notes}</p>
                {tag.transcript && (
                  <p><strong>Transcript:</strong><br />{tag.transcript.replace(/\n/g, "<br />")}</p>
                )}
              </div>
            ))}
          </div>
          <button onClick={closeModal} className="button is-primary mt-4">Close</button>
        </Modal>
      )}
    </div>
  );
};

TagBadges.propTypes = {
  tags: PropTypes.arrayOf(
    PropTypes.shape({
      name: PropTypes.string.isRequired,
      priority: PropTypes.number.isRequired,
      notes: PropTypes.string,
      transcript: PropTypes.string,
    })
  ).isRequired,
};

export default TagBadges;
