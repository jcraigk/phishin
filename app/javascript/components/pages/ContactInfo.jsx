import React from "react";
import PageWrapper from "./PageWrapper";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faX } from "@fortawesome/free-solid-svg-icons";

const ContactInfo = ({ contactEmail }) => {
  return (
    <PageWrapper>
      <h1 className="title">Contact Info</h1>

      <p>
        If you notice a bug, please file an issue or pull request on GitHub:{" "}
        <a
          href="https://github.com/jcraigk/phishin/issues"
          className="underline text-blue-500 hover:text-blue-700"
          target="_blank"
          rel="noopener noreferrer"
        >
          https://github.com/jcraigk/phishin/issues
        </a>
      </p>

      <p>
        Join the community discussion on Discord:{" "}
        <a
          href="https://discord.gg/KZWFsNN"
          className="underline text-blue-500 hover:text-blue-700"
          target="_blank"
          rel="noopener noreferrer"
        >
          https://discord.gg/KZWFsNN
        </a>
      </p>

      <h3 className="mt-6">Contact the site maintainer</h3>
      <p>
        <a
          href={`mailto:${contactEmail}`}
          className="underline text-blue-500 hover:text-blue-700"
          target="_blank"
        >
          {contactEmail}
        </a>
      </p>

      <a
        href="https://x.com/phish_in"
        className="button"
        target="_blank"
      >
        <div className="icon mr-1">
          <FontAwesomeIcon icon={faX} />
        </div>
        Follow on X
      </a>
    </PageWrapper>
  );
};

export default ContactInfo;
