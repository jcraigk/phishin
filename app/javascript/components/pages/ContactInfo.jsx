import React from "react";
import PageWrapper from "./PageWrapper";
import GitHubButton from "./GitHubButton";
import DiscordButton from "./DiscordButton";
import EmailButton from "./EmailButton";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faX } from "@fortawesome/free-solid-svg-icons";

const ContactInfo = () => {
  return (
    <PageWrapper>
      <h1 className="title">Contact Info</h1>

      <p>
        If you notice a bug, please file an issue or pull request on GitHub:
      </p>
      <GitHubButton className="mb-5" />

      <p>
        Join the community discussion on Discord:
      </p>
      <DiscordButton className="mb-5" />

      <p>
        Follow on X:
      </p>
      <a
        href="https://x.com/phish_in"
        className="button mb-5"
        target="_blank"
      >
        <FontAwesomeIcon icon={faX} className="mr-1" />
        @phish_in
      </a>
      <br />


      <p>
        Email the site maintainer:
      </p>
      <EmailButton />
      <br />

    </PageWrapper>
  );
};

export default ContactInfo;
