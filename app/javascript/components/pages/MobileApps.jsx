import React from "react";
import relistenIcon from "../../images/icon-relisten.png";
import splendorIcon from "../../images/icon-splendor.png";
import liveMusicArchiveIcon from "../../images/icon-live-music-archive.png";

const MobileApps = ({ className }) => {
  return (
    <div className={`mobile-apps ${className}`}>
      <a
        href="https://relisten.net/app"
        target="_blank"
        className="mr-3"
      >
        <img
          src={relistenIcon}
          alt="Relisten"
          data-tip="Relisten (iOS / Android)"
        />
      </a>
      <a
        href="https://apps.apple.com/us/app/live-music-archive/id1453343128"
        target="_blank"
        className="mr-3"
      >
        <img
          src={liveMusicArchiveIcon}
          alt="Live Music Archive"
          data-tip="Live Music Archive (iOS)"
        />
      </a>
      <a
        href="https://play.google.com/store/apps/details?id=never.ending.splendor"
        target="_blank"
      >
        <img
          src={splendorIcon}
          alt="Android app"
          data-tip="Phish Tapes (Android)"
        />
      </a>
    </div>
  );
};

export default MobileApps;
