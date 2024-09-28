import React from "react";
import Modal from "react-modal";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCircleXmark } from "@fortawesome/free-solid-svg-icons";

Modal.setAppElement("#root");

const AppModal = ({ isOpen, onRequestClose, modalContent }) => {
  if (!modalContent) return null;

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
        style={{ cursor: "pointer" }}
      />
      {modalContent}
    </Modal>
  );
};

export default AppModal;
