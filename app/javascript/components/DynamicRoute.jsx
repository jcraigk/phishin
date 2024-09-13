import React from "react";
import { useParams } from "react-router-dom";
import EraShows from "./EraShows";
import ErrorPage from "./pages/ErrorPage";
import Show from "./Show";

const DynamicRoute = () => {
  const { routePath } = useParams();

  if (/^\d{4}$/.test(routePath) || /^\d{4}-\d{4}$/.test(routePath)) {
    return <EraShows />;
  }

  if (/^\d{4}-\d{2}-\d{2}$/.test(routePath)) {
    return <Show />;
  }

  return <ErrorPage />;
};

export default DynamicRoute;
