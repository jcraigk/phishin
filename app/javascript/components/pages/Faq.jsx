import React from "react";
import PageWrapper from "./PageWrapper";

const Faq = ({ contact_email }) => {
  return (
    <PageWrapper>
      <h3>What does this site do?</h3>
      <p>
        Phish.in provides a web UI and RESTful API for discovering, streaming, and sharing live audience recordings of the band Phish. The site has been running since 2013, delivering a reliable and comprehensive resource for fans.
      </p>

      <h3>Is this site legal?</h3>
      <p>
        Yes, this site is 100% legal and complies with Phish's official taping policy as described at
        <a href="https://phish.com/#/faq/taping-guidelines" target="_blank">
          https://phish.com/#/faq/taping-guidelines
        </a>.
        If you know any of the material on this site to be in violation of Phish's policy, please send an email to
        <a href={`mailto:${contact_email}`} target="_blank">
          {contact_email}
        </a>.
      </p>

      <h3>How is the project funded?</h3>
      <p>This site is funded 100% privately by the maintainer.</p>

      <h3>How are audio sources chosen?</h3>
      <p>
        The general goal of the site is to provide the most complete audio experience for every show in circulation, even if that means mixing different sources in rare cases. Due to hosting costs, there is currently only one recording per show, so the "best" source (highly subjective) is chosen from what is available online.
      </p>
      <p>
        All content before 2013 was imported from the
        <a href="https://docs.google.com/spreadsheets/d/1yAXu83gJBz08cW5OXoqNuN1IbvDXD2vCrDKj4zn1qmU" target="_blank">
          Phish Spreadsheet
        </a> using a mostly automated process.
      </p>
      <p>
        Starting in 2013, as new content is generated by the band, it's downloaded from
        <a href="https://bt.etree.org" target="_blank">
          https://bt.etree.org
        </a> soon after it is uploaded by tapers. This usually occurs 8 to 12 hours after a show takes place. Often, the first source posted will be chosen to get content up as quickly as possible. However, if the first source contains labeling, splitting, or quality issues, an alternate source will be selected. In general, Phish.net setlists are preferred as far as labeling/splitting goes.
      </p>
      <p>
        Sometimes sources will be replaced later if a better version becomes available, but this is rare. For multi-night runs, the same source is preferred, although not always available.
      </p>
      <p>
        If you are aware of a source that is superior to the one on the site, please send an email to
        <a href={`mailto:${contact_email}`} target="_blank">
          {contact_email}
        </a> and include a link to download the source in question.
      </p>

      <h3>Is there a list of missing audio content?</h3>
      <p>Yes, see the <a href="/missing-content">Missing Content Report</a></p>

      <h3>What format is audio encoded in?</h3>
      <p>MP3 format is currently provided. These may be replaced with lossless format at a later time as storage and bandwidth become available.</p>

      <h3>What technologies power the site?</h3>
      <p>Ruby on Rails, React, and Postgres are the primary technologies used.</p>

      <h3>How can I contribute?</h3>
      <p>
        Join the discussion on{" "}
        <a href="https://discord.gg/KZWFsNN" target="_blank">
          Discord
        </a> or post an issue on{" "}
        <a href="https://github.com/jcraigk/phishin/issues" target="_blank">
          GitHub
        </a>.
      </p>
    </PageWrapper>
  );
};

export default Faq;
