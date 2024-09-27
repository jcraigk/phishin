import React from "react";
import Playlists from "./Playlists";
import Shows from "./Shows";
import Songs from "./Songs";
import Tags from "./Tags";
import Tracks from "./Tracks";
import Venues from "./Venues";

const SearchResults = ({ results, term }) => {
  const {
    songs,
    tracks,
    tags,
    venues,
    playlists,
    exact_show: exactShow,
    other_shows: otherShows,
  } = results;

  return (
    <>
      {exactShow && (
        <>
          <h2 className="title">Show on Date</h2>
          <Shows shows={[exactShow]} />
        </>
      )}

      {otherShows?.length > 0 && (
        <>
          <h2 className="title">Shows on Day of Year</h2>
          <Shows shows={otherShows} />
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
          <Tracks tracks={tracks} highlight={term} />
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

      {!exactShow && !otherShows?.length && !songs?.length && !tracks?.length && !tags?.length && !venues?.length && !playlists?.length && (
        <h2 className="title">Sorry, no results found.</h2>
      )}
    </>
  );
};

export default SearchResults;
