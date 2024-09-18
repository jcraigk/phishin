import React from "react";
import Modal from "react-modal";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCircleXmark } from "@fortawesome/free-solid-svg-icons";
import { formatDate } from "./utils";

const TaperNotesModal = ({ isOpen, onRequestClose, show }) => {
  if (!show) return null;

  return (
    <Modal
      isOpen={isOpen}
      onRequestClose={onRequestClose}
      contentLabel="Taper Notes"
      className="modal-content"
      overlayClassName="modal-overlay"
    >
      <FontAwesomeIcon
        icon={faCircleXmark}
        onClick={onRequestClose}
        className="is-pulled-right close-btn is-size-3"
        style={{ cursor: "pointer" }}
      />
      <h2 className="title mb-5">Taper Notes for {formatDate(show.date)}</h2>
      <p dangerouslySetInnerHTML={{ __html: (show.taper_notes || "").replace(/\n/g, "<br />") }}></p>
    </Modal>
  );
};

export default TaperNotesModal;
