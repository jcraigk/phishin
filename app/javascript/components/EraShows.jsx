import { authFetch } from "./utils";

export const eraShowsLoader = async ({ params }) => {
  const { routePath } = params;
  let url = `/api/v2/shows?per_page=1000`;

  if (routePath.includes("-")) {
    url += `&year_range=${routePath}`;
  } else {
    url += `&year=${routePath}`;
  }

  try {
    const response = await authFetch(url);
    if (!response.ok) throw response;
    const data = await response.json();
    return { shows: data.shows, routePath };
  } catch (error) {
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React from "react";
import { useLoaderData } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Shows from "./Shows";

const EraShows = () => {
  const { shows, routePath } = useLoaderData();

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="title">{routePath}</h1>
      <p className="sidebar-subtitle">{shows.length} shows total</p>
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      <Shows shows={shows} tourHeaders={true} />
    </LayoutWrapper>
  );
};

export default EraShows;
