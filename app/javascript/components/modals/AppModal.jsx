import React from "react";
import Modal from "react-modal";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCircleXmark } from "@fortawesome/free-solid-svg-icons";

Modal.setAppElement("#root");

const AppModal = ({ isOpen, onRequestClose, modalContent }) => {
  if (!modalContent) return null;

  const customStyles = {
    content: {
      top: "50%",
      left: "50%",
      right: "auto",
      bottom: "auto",
      marginRight: "-50%",
      transform: "translate(-50%, -50%)",
      maxHeight: "80vh",
      maxWidth: "90vw",
      overflow: "auto",
      padding: "1.5rem",
      borderRadius: "6px",
      zIndex: 106
    },
    overlay: {
      backgroundColor: "rgba(0, 0, 0, 0.75)",
      zIndex: 103
    }
  };

  return (
    <Modal
      id="app-modal"
      isOpen={isOpen}
      onRequestClose={onRequestClose}
      style={customStyles}
      onClick={(e) => e.stopPropagation()}
    >
      <FontAwesomeIcon
        icon={faCircleXmark}
        onClick={onRequestClose}
        className="is-pulled-right close-btn is-size-3"
      />
      {modalContent}
    </Modal>
  );
};

export default AppModal;
