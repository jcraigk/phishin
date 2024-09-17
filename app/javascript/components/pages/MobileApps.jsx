import React from "react";
import { Tooltip } from "react-tooltip";
import relistenIcon from "../../images/icon-relisten.png";
import splendorIcon from "../../images/icon-splendor.png";

const MobileApps = ({ className }) => {
  return (
    <div className={`mobile-apps ${className}`}>
      <a
        href="https://itunes.apple.com/us/app/relisten-all-live-music/id715886886"
        target="_blank"
        className="mr-3"
      >
        <img
          src={relistenIcon}
          alt="iOS app"
          data-tooltip-id="tooltip-relisten"
          data-tooltip-content="Relisten (iOS app)"
        />
        <Tooltip id="tooltip-relisten" className="custom-tooltip" />
      </a>
      <a
        href="https://play.google.com/store/apps/details?id=never.ending.splendor"
        target="_blank"
      >
        <img
          src={splendorIcon}
          alt="Android app"
          data-tooltip-id="tooltip-nes"
          data-tooltip-content="Never Ending Splendor (Android app)"
        />
        <Tooltip id="tooltip-nes" className="custom-tooltip" />
      </a>
    </div>
  );
};

export default MobileApps;
