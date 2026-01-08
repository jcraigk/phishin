import React from "react";
import { Link } from "react-router-dom";
import PageWrapper from "./PageWrapper";
import DiscordButton from "./DiscordButton";

const TaginProject = () => {
  return (
    <PageWrapper>
      <h1 className="title">Tagin' Project</h1>

      <h3>Overview</h3>
      <p>
        This site provides access to live legal Phish audio recordings. Its goal is to maintain a highly available and comprehensive archive of live performances curated by the community through cooperative effort. Content is discoverable based on available metadata such as performance date, song title, venue name, etc. Additionally, a set of curated tags has been applied; see the{" "}
        <Link to="/tags">Tags page</Link>.
      </p>
      <p>
        These have largely been imported from Phish.net projects such as Jam Charts and Teases. Many of these tags need verification and further expansion.
      </p>

      <h3>Contributing</h3>
      <p>
        To contribute, please join the{" "}
        <DiscordButton />{" "}
        and comment in the #tagging channel.
      </p>

    </PageWrapper>
  );
};

export default TaginProject;
