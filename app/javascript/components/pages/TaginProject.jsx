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
        These have largely been imported from Phish.net projects such as Jam Charts and Teases. Many of these tags need verification and further expansion. Here is the list of tags relevant to the project:
      </p>
      <ul>
        <li>A Cappella</li>
        <li>Alt Lyric</li>
        <li>Alt Rig</li>
        <li>Alt Version</li>
        <li>Audience</li>
        <li>Banter</li>
        <li>Famous</li>
        <li>Guest</li>
        <li>Narration</li>
        <li>Signal</li>
        <li>Tease</li>
        <li>Unfinished</li>
      </ul>
      <p>
        See the{" "}
        <a href="https://docs.google.com/spreadsheets/d/1WZtJYSHvt0DSYeUtzM5h0U5c90DN9Or7ckkJD-ds-rM">
          Master Tag.in Spreadsheet
        </a>{" "}
        for the current state of the project.
      </p>

      <h3>Contributing</h3>
      <p>
        To contribute, please join the{" "}
        <DiscordButton />{" "}
        and check out the #tagging channel. Write access to the{" "}
        <a href="https://docs.google.com/spreadsheets/d/1WZtJYSHvt0DSYeUtzM5h0U5c90DN9Or7ckkJD-ds-rM" target="_blank">
          Master Tag.in Spreadsheet
        </a>{" "}
        will be provided to those expressing a genuine interest in the project.
      </p>

      <h3>Instructions for Contributors</h3>
      <p><i>Note: If you notice any issues with content during your listening (track labeling, audio quality, etc.), please enter it in the CONTENT ISSUES tab on the spreadsheet.</i></p>
      <ol className="list-decimal list-inside">
        <li>Open the{" "}
          <a href="https://docs.google.com/spreadsheets/d/1WZtJYSHvt0DSYeUtzM5h0U5c90DN9Or7ckkJD-ds-rM" target="_blank">
            Master Tag.in Spreadsheet
          </a>.
        </li>
        <li>Familiarize yourself with each tag by clicking the workbook tabs at the bottom of the screen (also see specific tag Conventions below).</li>
        <li>Listen to audio content on this website.</li>
        <li>When you notice a taggable moment that has not yet been captured or an incorrect tag, pause the playback (spacebar or button in upper-right). Note you can also scrub forward and backward in 5-second increments by pressing Shift-LeftArrow and Shift-RightArrow.</li>
        <li>Roll the mouse cursor over the track in question and click on the context menu (down arrow) that appears.</li>
        <li>Click "Share" in the dropdown menu (URL will be copied to clipboard).</li>
        <li>Return to the spreadsheet and select the appropriate workbook for the tag you want to add.</li>
        <li>Select "Edit > Find and replace..." and search for the existing URL to ensure it has not already been tagged.</li>
        <li>If it has already been tagged, verify the metadata, make any corrections, and add +1 to Verified column.</li>
        <li>If it has not been tagged, paste the URL into the URL column.</li>
        <li>If the tag applies only to a section of the track, add start/stop timestamps. If it starts at the beginning of the track, the start time can be omitted; same for the stop timestamp. Certain tags will lend themselves more to timestamps than others ("Tease", for example, should generally have start timestamps).</li>
        <li>Add text to Notes field, adhering to established conventions within each tag (see below).</li>
        <li>If the tag happens to be Banter or Narration, then spoken words should be transcribed and pasted into the Transcript column, ensuring that line breaks are preserved (Shift-Enter or Option-Enter).</li>
      </ol>

      <h3>Tag Conventions</h3>
      <p>
        Each tag entry in the spreadsheet consists of a URL (pointing to the track the tag is associated with) and optionally has Starts At, Ends At, and Notes fields. If a tag applies to the entire track, then Starts At and Ends At should be omitted. If the tag refers to the first half of the track, omit the Starts At value but enter the Ends At value; same for the second half accordingly. The Notes field should contain details about that tag instance.
      </p>
      <p>
        Narration and Banter tags also include a Transcript field which contains a full transcript of all spoken words.
      </p>
      <p>
        Below we outline conventions for each tag; these are subject to change as the project develops.
      </p>

      <h3>Audience</h3>
      <ul>
        <li>Includes significant collective crowd response such as "woo," "polo," etc.</li>
        <li>Excludes random individuals caught on audience mics and Secret Language Signal responses, which should be tagged as "Signal."</li>
      </ul>

      <h3>Famous</h3>
      <ul>
        <li>Well-known (named) performances of songs like "Prague Ghost," "Tahoe Tweezer," etc.</li>
      </ul>

      <h3>Guest</h3>
      <ul>
        <li>Any time another artist or group joins the band on stage.</li>
        <li>Past guests have been imported from the Phish.net Guest Chart.</li>
      </ul>

      <h3>Narration</h3>
      <ul>
        <li>Any spoken word related to storytelling, such as Gamehendge narration or "Harpua."</li>
        <li>Include a brief summary in the Notes section and a full transcript in the Transcript field.</li>
      </ul>

      <h3>Signal</h3>
      <ul>
        <li>Any time one of the band members invokes a Secret Language signal.</li>
        <li>Past signals have been imported from Phish.net setlist notes but need to be split if they are combined.</li>
        <li>Apply Starts At timestamps to each Signal instance.</li>
      </ul>

      <h3>Tease</h3>
      <ul>
        <li>The band members frequently reference other musical works during improvisation.</li>
        <li>Past teases have been imported from the Phish.net Tease Chart and setlist API, though they require verification and correction.</li>
        <li>Each tease should be input separately with specific timestamps and detailed Notes, especially if the tease is not listed on Phish.net.</li>
      </ul>
    </PageWrapper>
  );
};

export default TaginProject;
