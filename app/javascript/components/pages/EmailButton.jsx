import React from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faEnvelope } from "@fortawesome/free-solid-svg-icons";

const EmailButton = ({ contactEmail }) => (
  <a
    href={`mailto:${contactEmail}`}
    className="button"
    target="_blank"
  >
    <div className="icon mr-1">
      <FontAwesomeIcon icon={faEnvelope} />
    </div>
    {contactEmail}
  </a>
);

export default EmailButton;
