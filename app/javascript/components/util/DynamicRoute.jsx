import { eraShowsLoader } from "../EraShows";
import { showLoader } from "../Show";

export const dynamicLoader = async ({ params, request }) => {
  const { "*": fullPath } = params;
  const [firstSegment] = fullPath.split("/");

  if (/^\d{4}$/.test(firstSegment) || /^\d{4}-\d{4}$/.test(firstSegment)) {
    return eraShowsLoader({ params: { year: firstSegment }, request });
  }

  if (/^\d{4}-\d{2}-\d{2}$/.test(firstSegment)) {
    return showLoader({ params: { date: firstSegment }, request });
  }

  throw new Response("Page not found", { status: 404 });
};


import React from "react";
import { useParams } from "react-router-dom";
import EraShows from "../EraShows";
import ErrorPage from "../pages/ErrorPage";
import Show from "../Show";

const DynamicRoute = () => {
  const { "*": fullPath } = useParams();
  const [firstSegment, secondSegment] = fullPath.split("/");

  if (/^\d{4}$/.test(firstSegment) || /^\d{4}-\d{4}$/.test(firstSegment)) {
    return <EraShows />;
  }

  if (/^\d{4}-\d{2}-\d{2}$/.test(firstSegment)) {
    return <Show trackSlug={secondSegment} />;
  }

  return <ErrorPage />;
};

export default DynamicRoute;
