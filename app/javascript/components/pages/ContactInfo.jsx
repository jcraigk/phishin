import React from "react";
import PageWrapper from "./PageWrapper";
import GitHubButton from "./GitHubButton";
import DiscordButton from "./DiscordButton";
import EmailButton from "./EmailButton";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faX, faEnvelope } from "@fortawesome/free-solid-svg-icons";

const ContactInfo = () => {
  return (
    <PageWrapper>
      <h1 className="title">Contact Info</h1>

      <p>
        If you notice a bug, please file an issue or pull request on GitHub:
        <br />
        <GitHubButton />
      </p>

      <p>
        Join the community discussion on Discord:
        <br />
        <DiscordButton />
      </p>

      <p>
        Follow on X:
        <br />
        <a
          href="https://x.com/phish_in"
          className="button"
          target="_blank"
        >
          <div className="icon mr-1">
            <FontAwesomeIcon icon={faX} />
          </div>
          @phish_in
        </a>
      </p>

      <p>
        Email the site maintainer:
        <br />
        <EmailButton />
      </p>
    </PageWrapper>
  );
};

export default ContactInfo;
