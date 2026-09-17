import React, { useState } from "react";
import { useOutletContext } from "react-router";
import { useFeedback } from "./contexts/FeedbackContext";
import DraftPlaylistTrackModal from "./modals/DraftPlaylistTrackModal";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faScissors, faTrashAlt } from "@fortawesome/free-solid-svg-icons";

const DraftTrackControls = ({ track, index }) => {
  const { draftPlaylist, setDraftPlaylist, setIsDraftPlaylistSaved } = useOutletContext();
  const { setNotice } = useFeedback();
  const [isTrimOpen, setIsTrimOpen] = useState(false);

  const handleReposition = (e) => {
    const newPosition = parseInt(e.target.value) - 1;
    if (newPosition === index) return;
    const updated = [...draftPlaylist];
    const [moved] = updated.splice(index, 1);
    updated.splice(newPosition, 0, moved);
    setDraftPlaylist(updated);
    setIsDraftPlaylistSaved(false);
  };

  const handleRemove = () => {
    const updated = [...draftPlaylist];
    updated.splice(index, 1);
    setDraftPlaylist(updated);
    setIsDraftPlaylistSaved(false);
    setNotice("Track removed from playlist editor");
  };

  return (
    <>
      <div className="select is-small draft-reposition">
        <select name="reposition" value={index + 1} onChange={handleReposition} title="Move to position">
          {draftPlaylist.map((t, idx) => (
            <option key={`${t.id}-${idx}`} value={idx + 1}>
              {idx + 1}. {t.title}
            </option>
          ))}
        </select>
      </div>
      <button className="button is-small draft-trim" onClick={() => setIsTrimOpen(true)} title="Trim start and end">
        <FontAwesomeIcon icon={faScissors} />
      </button>
      <button className="button is-small draft-remove" onClick={handleRemove} title="Remove from draft">
        <FontAwesomeIcon icon={faTrashAlt} />
      </button>
      <DraftPlaylistTrackModal
        isOpen={isTrimOpen}
        onRequestClose={() => setIsTrimOpen(false)}
        track={track}
        indexInPlaylist={index}
        draftPlaylist={draftPlaylist}
        setDraftPlaylist={(updated) => {
          setDraftPlaylist(updated);
          setIsDraftPlaylistSaved(false);
        }}
      />
    </>
  );
};

export default DraftTrackControls;
