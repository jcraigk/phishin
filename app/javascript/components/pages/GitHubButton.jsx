import React from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCodeBranch } from "@fortawesome/free-solid-svg-icons";

const GitHubButton = ({ className }) => (
  <a
    href="https://github.com/jcraigk/phishin/issues"
    className={`button ${className}`}
    target="_blank"
  >
    <div className="icon mr-1">
      <FontAwesomeIcon icon={faCodeBranch} />
    </div>
    GitHub
  </a>
);

export default GitHubButton;
