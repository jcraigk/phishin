import React from "react";

const CoverArt = ({ coverArtUrls, albumCoverUrl, openAppModal, size }) => {
  const handleOpenModal = () => {
    if (!openAppModal) return;
    const modalContent = (
      <>
        {albumCoverUrl && (
          <div className="large-album-art">
            <img src={albumCoverUrl} alt="Album cover" />
          </div>
        )}
        {coverArtUrls?.medium && (
          <div className="large-album-art mt-3">
            <img src={coverArtUrls?.medium} alt="Cover art" />
          </div>
        )}
      </>
    );
    openAppModal(modalContent);
  };

  return (
    <div className="cover-art cover-art-modal-trigger" onClick={handleOpenModal}>
      <img
        src={size === "large" ? coverArtUrls?.medium : coverArtUrls?.small}
        alt="Cover art"
        className={size === "large" ? "cover-art-large" : "cover-art-small"}
      />
    </div>
  );
};

export default CoverArt;
