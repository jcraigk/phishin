import React from "react";
import { Tooltip } from "react-tooltip";
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
          data-tooltip-id="tooltip-relisten"
          data-tooltip-content="Relisten (iOS / Android)"
        />
        <Tooltip id="tooltip-relisten" className="custom-tooltip" />
      </a>
      <a
        href="https://apps.apple.com/us/app/live-music-archive/id1453343128"
        target="_blank"
        className="mr-3"
      >
        <img
          src={liveMusicArchiveIcon}
          alt="Live Music Archive"
          data-tooltip-id="tooltip-lma"
          data-tooltip-content="Live Music Archive (iOS)"
        />
        <Tooltip id="tooltip-lma" className="custom-tooltip" />
      </a>
      <a
        href="https://play.google.com/store/apps/details?id=never.ending.splendor"
        target="_blank"
      >
        <img
          src={splendorIcon}
          alt="Android app"
          data-tooltip-id="tooltip-nes"
          data-tooltip-content="Phish Tapes (Android)"
        />
        <Tooltip id="tooltip-nes" className="custom-tooltip" />
      </a>
    </div>
  );
};

export default MobileApps;
