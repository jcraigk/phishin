import React from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faGamepad } from "@fortawesome/free-solid-svg-icons";

const DiscordButton = ({ className }) => (
  <a
    href="https://discord.gg/KZWFsNN"
    className={`button ${className}`}
    target="_blank"
  >
    <FontAwesomeIcon icon={faGamepad} className="mr-1" />
    Discord
  </a>
);

export default DiscordButton;
