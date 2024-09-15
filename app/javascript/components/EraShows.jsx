import { authFetch } from "./utils";

export const eraShowsLoader = async ({ params }) => {
  const { year } = params;
  let url = `/api/v2/shows?per_page=1000`;

  if (year.includes("-")) {
    url += `&year_range=${year}`;
  } else {
    url += `&year=${year}`;
  }

  try {
    const response = await authFetch(url);
    if (!response.ok) throw response;
    const data = await response.json();
    return { shows: data.shows, year };
  } catch (error) {
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React from "react";
import { useLoaderData } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Shows from "./Shows";
import { Helmet } from 'react-helmet-async';

const EraShows = () => {
  const { shows, year } = useLoaderData();

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="title">{year}</h1>
      <p className="sidebar-subtitle">{shows.length} shows total</p>
    </div>
  );

  return (
    <>
      <Helmet>
        <title>{year} - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        <Shows shows={shows} tourHeaders={true} />
      </LayoutWrapper>
    </>
  );
};

export default EraShows;
