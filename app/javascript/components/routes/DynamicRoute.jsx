import React from "react";
import { useParams, useNavigate } from "react-router-dom";
import EraShows from "../EraShows";
import Show from "../Show";
import ErrorPage from "../pages/ErrorPage";
import { eraShowsLoader } from "../EraShows";
import { showLoader } from "../Show";

const normalizeDate = (dateStr) => {
  const [year, month, day] = dateStr.split("-");
  const paddedMonth = month.padStart(2, "0");
  const paddedDay = day.padStart(2, "0");
  return `${year}-${paddedMonth}-${paddedDay}`;
};

export const dynamicLoader = async ({ params, request }) => {
  const { "*": fullPath } = params;
  const [firstSegment] = fullPath.split("/");

  // Handle year or year range route
  if (/^\d{4}$/.test(firstSegment) || /^\d{4}-\d{4}$/.test(firstSegment)) {
    return eraShowsLoader({ params: { year: firstSegment }, request });
  }

  // Handle potentially unnormalized date route
  if (/^\d{4}-\d{1,2}-\d{1,2}$/.test(firstSegment)) {
    const normalizedDate = normalizeDate(firstSegment);

    if (firstSegment !== normalizedDate) {
      throw new Response("", {
        status: 302,
        headers: {
          Location: `/${normalizedDate}`,
        },
      });
    }

    return showLoader({ params: { date: normalizedDate }, request });
  }

  throw new Response("Page not found", { status: 404 });
};

const DynamicRoute = () => {
  const { "*": fullPath } = useParams();
  const navigate = useNavigate();
  const [firstSegment, secondSegment] = fullPath.split("/");

  // Handle year or year range route
  if (/^\d{4}$/.test(firstSegment) || /^\d{4}-\d{4}$/.test(firstSegment)) {
    return <EraShows />;
  }

  // Handle normalized date route
  if (/^\d{4}-\d{2}-\d{2}$/.test(firstSegment)) {
    return <Show trackSlug={secondSegment} />;
  }

  // Fallback to error page
  return <ErrorPage />;
};

export default DynamicRoute;
