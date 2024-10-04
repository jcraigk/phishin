import React, { useState } from "react";

const CoverArt = ({ coverArtUrls, albumCoverUrl, openAppModal, size = "small" }) => {
  const [isLoaded, setIsLoaded] = useState(false);

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

  const handleImageLoad = () => {
    setIsLoaded(true);
  };

  return (
    <div
      className={`cover-art cover-art-modal-trigger ${isLoaded ? "" : "loading-shimmer"}`}
      onClick={handleOpenModal}
    >
      <img
        src={["large", "medium"].includes(size) ? coverArtUrls?.medium : coverArtUrls?.small}
        alt="Cover art"
        className={`cover-art-${size}`}
        onLoad={handleImageLoad}
      />
    </div>
  );
};

export default CoverArt;
