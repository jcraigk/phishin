import React from "react";
import { useParams } from "react-router-dom";

import Shows from "./Shows";
import Show from "./Show";
import ErrorPage from "./pages/ErrorPage";

const DynamicRoute = () => {
  const { route_path } = useParams();

  if (/^\d{4}$/.test(route_path) || /^\d{4}-\d{4}$/.test(route_path)) {
    return <Shows />;
  }

  if (/^\d{4}-\d{2}-\d{2}$/.test(route_path)) {
    return <Show />;
  }

  return <ErrorPage />;
};

export default DynamicRoute;
