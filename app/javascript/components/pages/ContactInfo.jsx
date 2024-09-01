import React from "react";
import PageWrapper from "./PageWrapper";

const ContactInfo = ({ contact_email }) => {
  return (
    <PageWrapper>
      <h3>Bug</h3>
      <p>This project is open source.</p>
      <p>
        If you notice a bug, please file an issue on GitHub:{" "}
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
        If you are a developer, please feel free to submit a pull request.
      </p>

      <h3>Talk</h3>
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

      <h3>Contact the site maintainers</h3>
      <p>
        <a
          href={`mailto:${contact_email}`}
          className="underline text-blue-500 hover:text-blue-700"
          target="_blank"
        >
          {contact_email}
        </a>
      </p>

      <a
        href="https://x.com/phish_in"
        className="x-follow-button"
        data-show-count="false"
        data-size="large"
        target="_blank"
        rel="noopener noreferrer"
      >
        Follow
      </a>
      <script async src="https://platform.x.com/widgets.js" charset="utf-8"></script>
    </PageWrapper>
  );
};

export default ContactInfo;
