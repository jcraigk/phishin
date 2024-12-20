import React from "react";
import PageWrapper from "./PageWrapper";
import { Link } from "react-router-dom";
import MobileApps from "./MobileApps";
import DiscordButton from "./DiscordButton";
import GitHubButton from "./GitHubButton";
import EmailButton from "./EmailButton";

const Faq = () => {
  return (
    <PageWrapper>
      <h1 className="title">Frequently Asked Questions</h1>

      <h3>What is Phish.in?</h3>
      <p>
        Phish.in is a website and API for discovering, streaming, and sharing live audience recordings of the band Phish. The site has been running since 2013, delivering a reliable and comprehensive resource for fans.
      </p>

      <h3>Are there native mobile apps?</h3>
      <p>Yes, there are native apps for iOS and Android. Follow the links below.</p>
      <MobileApps />

      <h3>Is this site legal?</h3>
      <p>
        Yes, this site is 100% legal and complies with Phish's official taping policy as described at{" "}
        <a href="https://phish.com/#/faq/taping-guidelines" target="_blank">
          https://phish.com/#/faq/taping-guidelines
        </a>.
        If you know any of the material on this site to be in violation of Phish's policy, please send an email:{" "}
        <EmailButton />
      </p>

      <h3>Are there any keyboard shortcuts?</h3>
      <p>Yes. To control audio playback, use Spacebar to toggle play/pause, left/right arrow keys to skip tracks, and hold shift and press left/right arrow keys to seek by 10 seconds.</p>

      <h3>Is there a dark mode?</h3>
      <p>No, there's no native dark mode, but the site works well with <a href="https://chromewebstore.google.com/detail/dark-reader/eimadpbcbfnmbkopoojfekhnkhdbieeh?hl=en-US&pli=1" target="_blank">Dark Reader</a>.</p>

      <h3>Can I share excerpts of tracks?</h3>
      <p>Yes, there are two ways to share excerpts of tracks.</p>

      <p>You can add "t" and "e" params to an individual URL. For example https://phish.in/1993-04-01/llama?t=1:00&e=1:05 would start playing Llama at 1 minute and stop playing five seconds later.</p>

      <p>You can also create a playlist and set the start and end seconds on each track and then share the playlist.</p>

      <h3>How is the project funded?</h3>
      <p>This site is funded privately.</p>

      <h3>How are audio sources chosen?</h3>
      <p>
        The general goal of the site is to provide the most complete audio experience for every show in circulation, even if that means mixing different sources in rare cases. Due to hosting costs, there is currently only one recording per show, so the "best" source (highly subjective) is chosen from what is available online.
      </p>
      <p>
        All content before 2013 was imported from the{" "}
        <a href="https://docs.google.com/spreadsheets/d/1yAXu83gJBz08cW5OXoqNuN1IbvDXD2vCrDKj4zn1qmU" target="_blank">
          Phish Spreadsheet
        </a> using a mostly automated process.
      </p>
      <p>
        Starting in 2013, as new content is generated by the band, it's downloaded from{" "}
        <a href="https://bt.etree.org" target="_blank">
          https://bt.etree.org
        </a> soon after it is uploaded by tapers. This usually occurs 8 to 12 hours after a show takes place. Often, the first source posted will be chosen to get content up as quickly as possible. However, if the first source contains labeling, splitting, or quality issues, an alternate source will be selected. In general, Phish.net setlists are preferred as far as labeling/splitting goes.
      </p>
      <p>
        Sometimes sources will be replaced later if a better version becomes available, but this is rare. For multi-night runs, the same source is preferred, although not always available.
      </p>
      <p>
        If you are aware of a source that is superior to the one on the site, please send an email:{" "}
        <EmailButton />
      </p>

      <h3>Is there a list of missing audio content?</h3>
      <p>Yes, see the <Link to="/missing-content">Missing Content Report</Link>.</p>

      <h3>What format is audio encoded in?</h3>
      <p>MP3 format is currently provided. These may be replaced with lossless format at a later time as storage and bandwidth become available.</p>

      <h3>What technologies power the site?</h3>
      <p>Ruby on Rails, React, and Postgres are the primary technologies used.</p>

      <h3>How is album cover art created?</h3>
      <p>Album covers are generated with a combination of automation scripts and the assistance of ChatGPT and Dall-E.</p>
      <Link to="/cover-art" className="button mt-2">Browse All Art</Link>

      <h3>How can I contribute?</h3>
      <p>
        Join the discussion on{" "}
        <DiscordButton />{" "}
        or post an issue on{" "}
        <GitHubButton />
      </p>
    </PageWrapper>
  );
};

export default Faq;
