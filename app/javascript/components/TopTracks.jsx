import { authFetch, getAudioStatusFilter } from "./helpers/utils";

export const topTracksLoader = async () => {
  const audioStatusFilter = getAudioStatusFilter();
  const response = await authFetch(`/api/v2/tracks?per_page=46&sort=likes_count:desc&audio_status=${audioStatusFilter}`).catch(error => {
    console.error("Error fetching top tracks data:", error);
    throw new Response("Error fetching data", { status: 500 });
  });
  if (!response.ok) throw response;
  const data = await response.json();
  return { tracks: data.tracks };
};

import React from "react";
import { useLoaderData } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import LayoutWrapper from "./layout/LayoutWrapper";
import Tracks from "./Tracks";
import PhoneTitle from "./PhoneTitle";

const TopTracks = () => {
  const { tracks } = useLoaderData();

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">Top 46 Tracks</p>
      <p className="sidebar-detail mb-5 hidden-mobile">
        An aggregated list of the top tracks, ranked by user likes from the Phish.in community.
      </p>
    </div>
  );

  return (
    <>
      <Helmet>
        <title>Top Tracks - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        <PhoneTitle title="Top 46 Tracks" />
        <Tracks tracks={tracks} numbering={true} omitSecondary={true} />
      </LayoutWrapper>
    </>
  );
};

export default TopTracks;
