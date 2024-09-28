import { authFetch } from "./util/utils";

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
import { Helmet } from "react-helmet-async";
import LayoutWrapper from "./layout/LayoutWrapper";
import Tracks from "./Tracks";

const TopTracks = ({ user }) => {
  const { tracks } = useLoaderData();

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">Top 46 Tracks</p>
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
        <Tracks tracks={tracks} numbering={true} omitSecondary={true} />
      </LayoutWrapper>
    </>
  );
};

export default TopTracks;
