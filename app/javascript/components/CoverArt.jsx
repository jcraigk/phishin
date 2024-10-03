import React from "react";

const CoverArt = ({ coverArtUrls, albumCoverUrl, openAppModal, size }) => {
  const handleOpenModal = () => {
    if (!openAppModal) return;
    const modalContent = (
      <div className="large-album-art">
        <img src={albumCoverUrl || coverArtUrls?.medium} alt="Cover art" />
      </div>
    );
    openAppModal(modalContent);
  };

  return (
    <span className="cover-art cover-art-modal-trigger" onClick={handleOpenModal}>
      <img
        src={size === "large" ? coverArtUrls?.medium : coverArtUrls?.small}
        alt="Cover art"
        className={size === "large" ? "cover-art-large" : "cover-art-small"}
      />
    </span>
  );
};

export default CoverArt;
