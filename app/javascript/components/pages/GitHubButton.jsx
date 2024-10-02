import React from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCodeBranch } from "@fortawesome/free-solid-svg-icons";

const GitHubButton = ({ className }) => (
  <a
    href="https://github.com/jcraigk/phishin/issues"
    className={`button ${className}`}
    target="_blank"
  >
    <FontAwesomeIcon icon={faCodeBranch} className="mr-1" />
    GitHub
  </a>
);

export default GitHubButton;
