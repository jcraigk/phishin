import { authFetch } from "./utils";

export const topTracksLoader = async () => {
  try {
    const response = await authFetch(`/api/v2/tracks?per_page=46&sort=likes_count:desc`);
    if (!response.ok) throw response;
    const data = await response.json();
    return { tracks: data.tracks };
  } catch (error) {
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React from "react";
import { useLoaderData, Link } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Tracks from "./Tracks";
import { Helmet } from 'react-helmet-async';

const TopTracks = ({ user }) => {
  const { tracks } = useLoaderData();

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="title">Top 46 Tracks</h1>
      <p className="sidebar-detail mb-5">
        An aggregated list of the top tracks, ranked by user likes from the Phish.in community.
      </p>
      {!user && (
        <div className="sidebar-callout">
          <Link to="/login" className="button">
            Login to contribute!
          </Link>
        </div>
      )}
    </div>
  );

  return (
    <>
      <Helmet>
        <title>Top Tracks - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        <Tracks tracks={tracks} setTracks={() => {}} numbering={true} />
      </LayoutWrapper>
    </>
  );
};

export default TopTracks;
