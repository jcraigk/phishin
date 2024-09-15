import { authFetch } from "./utils";

export const topShowsLoader = async () => {
  try {
    const response = await authFetch(`/api/v2/shows?per_page=40&sort=likes_count:desc`);
    if (!response.ok) throw response;
    const data = await response.json();
    return { shows: data.shows };
  } catch (error) {
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React from "react";
import { useLoaderData } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Shows from "./Shows";

const TopShows = ({ user }) => {
  const { shows } = useLoaderData();

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="title">Top 40 Shows</h1>
      <p className="sidebar-detail mb-5">
        An aggregated list of the top shows, ranked by user likes from the Phish.in community.
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
    <LayoutWrapper sidebarContent={sidebarContent}>
      <Shows shows={shows} numbering={true} />
    </LayoutWrapper>
  );
};

export default TopShows;

