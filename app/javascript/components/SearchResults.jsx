import React, { useState } from "react";
import Tracks from "./Tracks";
import Tags from "./Tags";
import Shows from "./Shows";
import Songs from "./Songs";
import Venues from "./Venues";
import Playlists from "./Playlists";

const SearchResults = ({ results, term }) => {
  const {
    songs,
    tracks,
    tags,
    venues,
    playlists,
    exact_show: initialExactShow,
    other_shows: initialOtherShows,
  } = results;
  const [otherShows, setOtherShows] = useState(initialOtherShows || []);
  const [exactShows, setExactShows] = useState(initialExactShow ? [initialExactShow] : []);

  return (
    <>
      {exactShows?.length > 0 && (
        <>
          <h2 className="title">Show on Date</h2>
          <Shows shows={exactShows} setShows={setExactShows} />
        </>
      )}

      {otherShows?.length > 0 && (
        <>
          <h2 className="title">Shows on Day of Year</h2>
          <Shows shows={otherShows} setShows={setOtherShows} />
        </>
      )}

      {songs?.length > 0 && (
        <>
          <h2 className="title">Songs</h2>
          <Songs songs={songs} highlight={term} />
        </>
      )}

      {tracks?.length > 0 && (
        <>
          <h2 className="title">Tracks</h2>
          <Tracks tracks={tracks} setTracks={() => {}} highlight={term} />
        </>
      )}

      {tags?.length > 0 && (
        <>
          <h2 className="title">Tags</h2>
          <Tags tags={tags} highlight={term} />
        </>
      )}

      {venues?.length > 0 && (
        <>
          <h2 className="title">Venues</h2>
          <Venues venues={venues} highlight={term} />
        </>
      )}

      {playlists?.length > 0 && (
        <>
          <h2 className="title">Playlists</h2>
          <Playlists playlists={playlists} highlight={term} />
        </>
      )}

      {!exactShows?.length && !otherShows?.length && !songs?.length && !tracks?.length && !tags?.length && !venues?.length && !playlists?.length && (
        <h2 className="title">Sorry, no results found.</h2>
      )}
    </>
  );
};

export default SearchResults;
