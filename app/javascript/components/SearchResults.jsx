import React, { useState } from "react";
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

  // State to track which sections have their full results displayed
  const [showMoreSongs, setShowMoreSongs] = useState(false);
  const [showMoreTracks, setShowMoreTracks] = useState(false);
  const [showMoreTags, setShowMoreTags] = useState(false);
  const [showMoreVenues, setShowMoreVenues] = useState(false);
  const [showMorePlaylists, setShowMorePlaylists] = useState(false);
  const [showMoreOtherShows, setShowMoreOtherShows] = useState(false);

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
          <Shows shows={showMoreOtherShows ? otherShows : otherShows.slice(0, 10)} />
          {otherShows.length > 10 && (
            <button className="button" onClick={() => setShowMoreOtherShows(!showMoreOtherShows)}>
              {showMoreOtherShows ? "Show fewer..." : "Show more..."}
            </button>
          )}
        </>
      )}

      {songs?.length > 0 && (
        <>
          <h2 className="title">Songs</h2>
          <Songs songs={showMoreSongs ? songs : songs.slice(0, 10)} highlight={term} />
          {songs.length > 10 && (
            <button className="button" onClick={() => setShowMoreSongs(!showMoreSongs)}>
              {showMoreSongs ? "Show fewer..." : "Show more..."}
            </button>
          )}
        </>
      )}

      {tracks?.length > 0 && (
        <>
          <h2 className="title">Tracks</h2>
          <Tracks tracks={showMoreTracks ? tracks : tracks.slice(0, 10)} highlight={term} />
          {tracks.length > 10 && (
            <button className="button" onClick={() => setShowMoreTracks(!showMoreTracks)}>
              {showMoreTracks ? "Show fewer..." : "Show more..."}
            </button>
          )}
        </>
      )}

      {tags?.length > 0 && (
        <>
          <h2 className="title">Tags</h2>
          <Tags tags={showMoreTags ? tags : tags.slice(0, 10)} highlight={term} />
          {tags.length > 10 && (
            <button className="button" onClick={() => setShowMoreTags(!showMoreTags)}>
              {showMoreTags ? "Show fewer..." : "Show more..."}
            </button>
          )}
        </>
      )}

      {venues?.length > 0 && (
        <>
          <h2 className="title">Venues</h2>
          <Venues venues={showMoreVenues ? venues : venues.slice(0, 10)} highlight={term} />
          {venues.length > 10 && (
            <button className="button" onClick={() => setShowMoreVenues(!showMoreVenues)}>
              {showMoreVenues ? "Show fewer..." : "Show more..."}
            </button>
          )}
        </>
      )}

      {playlists?.length > 0 && (
        <>
          <h2 className="title">Playlists</h2>
          <Playlists playlists={showMorePlaylists ? playlists : playlists.slice(0, 10)} highlight={term} />
          {playlists.length > 10 && (
            <button className="button" onClick={() => setShowMorePlaylists(!showMorePlaylists)}>
              {showMorePlaylists ? "Show fewer..." : "Show more..."}
            </button>
          )}
        </>
      )}

      {!exactShow && !otherShows?.length && !songs?.length && !tracks?.length && !tags?.length && !venues?.length && !playlists?.length && (
        <h2 className="title">Sorry, no results found.</h2>
      )}
    </>
  );
};

export default SearchResults;
