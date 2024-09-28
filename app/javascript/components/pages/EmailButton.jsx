import React from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faEnvelope } from "@fortawesome/free-solid-svg-icons";

const EmailButton = () => (
  <a
    href="mailto:phish.in.music@gmail.com"
    className="button"
    target="_blank"
  >
    <FontAwesomeIcon icon={faEnvelope} className="mr-1" />
    Contact via Email
  </a>
);

export default EmailButton;
