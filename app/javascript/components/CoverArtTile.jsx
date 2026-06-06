import React, { useState } from "react";
import { Link } from "react-router";

const CoverArtTile = ({ to, onClick, imageUrl, children }) => {
  const [isLoaded, setIsLoaded] = useState(false);

  const tile = (
    <li className={`grid-item ${isLoaded ? "" : "loading-shimmer"}`} onClick={onClick}>
      <img
        src={imageUrl}
        alt=""
        className="grid-item-image"
        onLoad={() => setIsLoaded(true)}
        loading="lazy"
      />
      <div className="overlay">{children}</div>
    </li>
  );

  if (to) {
    return (
      <Link to={to} className="list-item-link">
        {tile}
      </Link>
    );
  }

  return tile;
};

export default CoverArtTile;
