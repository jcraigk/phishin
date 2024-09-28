import { authFetch } from "./helpers/utils";

export const topShowsLoader = async () => {
  try {
    const response = await authFetch(`/api/v2/shows?per_page=46&sort=likes_count:desc`);
    if (!response.ok) throw response;
    const data = await response.json();
    return { shows: data.shows };
  } catch (error) {
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React from "react";
import { useLoaderData, Link } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import LayoutWrapper from "./layout/LayoutWrapper";
import Shows from "./Shows";

const TopShows = ({ user }) => {
  const { shows } = useLoaderData();

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">Top 46 Shows</p>
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
    <>
      <Helmet>
        <title>Top Shows - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        <Shows shows={shows} numbering={true} />
      </LayoutWrapper>
    </>
  );
};

export default TopShows;

