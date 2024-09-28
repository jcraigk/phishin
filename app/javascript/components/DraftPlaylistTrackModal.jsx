import React, { useState, useEffect } from "react";
import Modal from "react-modal";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCircleCheck, faCircleXmark } from "@fortawesome/free-solid-svg-icons";

const DraftPlaylistTrackModal = ({
  isOpen,
  onRequestClose,
  track,
  indexInPlaylist,
  draftPlaylist,
  setDraftPlaylist
}) => {
  const [start, setStart] = useState(track.starts_at_second ?? null);
  const [end, setEnd] = useState(track.ends_at_second ?? null);
  const [position, setPosition] = useState(indexInPlaylist + 1);

  useEffect(() => {
    setStart(track.starts_at_second ?? null);
    setEnd(track.ends_at_second ?? null);
    setPosition(indexInPlaylist + 1);
  }, [track, indexInPlaylist]);

  const timeOptions = Array.from({ length: Math.floor(track.duration / 1000) }, (_, i) => {
    const seconds = i + 1; // Start from 1 second
    const minutes = Math.floor(seconds / 60);
    const remainderSeconds = seconds % 60;
    const formattedTime = `${minutes}:${remainderSeconds < 10 ? `0${remainderSeconds}` : remainderSeconds}`;

    return (
      <option key={seconds} value={seconds}>
        {formattedTime}
      </option>
    );
  });

  const startOptions = [
    <option key="start-default" value="null">
      Beginning of Track
    </option>,
    ...timeOptions
  ];

  const endOptions = [
    <option key="end-default" value="null">
      End of Track
    </option>,
    ...timeOptions
  ];

  const positionOptions = draftPlaylist.map((t, idx) => (
    <option key={t.id} value={idx + 1}>
      {idx + 1}. {t.title}
    </option>
  ));

  const handleStartChange = (e) => {
    const value = e.target.value === "null" ? null : parseInt(e.target.value);
    setStart(value);
  };

  const handleEndChange = (e) => {
    const value = e.target.value === "null" ? null : parseInt(e.target.value);
    setEnd(value);
  };

  const handlePositionChange = (e) => setPosition(parseInt(e.target.value));

  const saveChanges = () => {
    const updatedPlaylist = [...draftPlaylist];
    const trackToUpdate = updatedPlaylist.splice(indexInPlaylist, 1)[0];

    trackToUpdate.starts_at_second = start;
    trackToUpdate.ends_at_second = end;

    updatedPlaylist.splice(position - 1, 0, trackToUpdate);
    setDraftPlaylist(updatedPlaylist);

    onRequestClose();
  };

  return (
    <Modal
      isOpen={isOpen}
      onRequestClose={onRequestClose}
      className="modal-content"
      overlayClassName="modal-overlay"
      onClick={(e) => e.stopPropagation()}
    >
      <FontAwesomeIcon
        icon={faCircleXmark}
        onClick={onRequestClose}
        className="is-pulled-right close-btn is-size-3"
      />
      <h2 className="title">Edit Playlist Entry</h2>
      <h3 className="subtitle">{track.title}</h3>

      <div className="field">
        <label className="label">Position</label>
        <div className="control">
          <select className="select" value={position} onChange={handlePositionChange}>
            {positionOptions}
          </select>
        </div>
      </div>

      <div className="field">
        <label className="label">Start Time</label>
        <div className="control">
          <select className="select" value={start ?? "null"} onChange={handleStartChange}>
            {startOptions}
          </select>
        </div>
      </div>

      <div className="field">
        <label className="label">End Time</label>
        <div className="control">
          <select className="select" value={end ?? "null"} onChange={handleEndChange}>
            {endOptions}
          </select>
        </div>
      </div>

      <button className="button" onClick={saveChanges}>
        <span className="icon mr-1">
          <FontAwesomeIcon icon={faCircleCheck} />
        </span>
        Done Editing
      </button>
    </Modal>
  );
};

export default DraftPlaylistTrackModal;
