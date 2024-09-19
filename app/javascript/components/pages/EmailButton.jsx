import React from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faEnvelope } from "@fortawesome/free-solid-svg-icons";

const EmailButton = () => (
  <a
    href="mailto:phish.in.music@gmail.com"
    className="button"
    target="_blank"
  >
    <div className="icon mr-1">
      <FontAwesomeIcon icon={faEnvelope} />
    </div>
    Contact via Email
  </a>
);

export default EmailButton;
