import React from "react";

const CoverArt = ({ imageUrls, openAppModal }) => {
  const handleOpenModal = () => {
    const modalContent = (
      <div className="large-album-art">
        <img src={imageUrls?.original} alt="Cover art" />
      </div>
    );
    openAppModal(modalContent);
  };

  return (
    <span className="cover-art cover-art-modal-trigger" onClick={handleOpenModal}>
      <img
        src={imageUrls?.small}
        alt="Cover art"
        className="cover-art-small"
      />
    </span>
  );
};

export default CoverArt;
