import React from "react";
import Tracks from "../Tracks";
import Tags from "../Tags";
import Shows from "../Shows";
import Songs from "../Songs";
import Venues from "../Venues";

const SearchResults = ({ results, term }) => {
  const { songs, tracks, tags, venues, exact_show, other_shows } = results;

  return (
    <div className="search-results">
      <h1 className="title mt-6">Search Results for "{term}"</h1>
      {exact_show && (
        <>
          <h2 className="title">Show on Date</h2>
          <Shows shows={[exact_show]} />
        </>
      )}

      {other_shows?.length > 0 && (
        <>
          <h2 className="title">Shows on Day of Year</h2>
          <Shows shows={other_shows} />
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

      {!exact_show && !other_shows?.length && !songs?.length && !tracks?.length && !tags?.length && !venues?.length && (
        <p>Sorry, no results found.</p>
      )}
    </div>
  );
};

export default SearchResults;
