import React, { useState } from "react";
import PropTypes from "prop-types";
import Modal from "react-modal";
import { Tooltip } from "react-tooltip";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faTimes } from "@fortawesome/free-solid-svg-icons";

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
    if (!tagGroup[0].notes && !tagGroup[0].transcript) {
      return; // Do nothing if there are no notes or transcript
    }
    event.stopPropagation();
    event.preventDefault();
    setSelectedTag(tagGroup);
  };

  const closeModal = () => {
    setSelectedTag(null);
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
        const tag = tagGroup[0];
        const title = `${tagName} ${count > 1 ? `(${count})` : ""}`;
        const tooltipId = `tooltip-${tagName}`;

        // Determine if the tag is clickable
        const isClickable = tag.notes || tag.transcript;

        return (
          <div
            key={tagName}
            className="tag-badge"
            data-tooltip-id={tooltipId}
            data-tooltip-content={tooltipForTagStack(tagGroup)}
            onClick={isClickable ? (event) => handleClick(tagGroup, event) : null}
            style={{
              backgroundColor: "$header_gray",
              cursor: isClickable ? "pointer" : "default", // Change cursor based on clickability
            }}
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
          className="tag-modal"
          overlayClassName="modal-overlay"
        >
          <button onClick={closeModal} className="button is-pulled-right">
            <FontAwesomeIcon icon={faTimes} />
          </button>
          <h2 className="title mb-2">{selectedTag[0].name}</h2>

          <div>
            {selectedTag.map((tag, index) => (
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
      description: PropTypes.string,
      starts_at_second: PropTypes.number,
      ends_at_second: PropTypes.number,
    })
  ).isRequired,
};

export default TagBadges;
