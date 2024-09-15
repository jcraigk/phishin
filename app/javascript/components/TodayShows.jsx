import { authFetch } from "./utils";

export const todayShowsLoader = async ({ request }) => {
  const url = new URL(request.url);
  const month = url.searchParams.get("month") || new Date().getMonth() + 1;
  const day = url.searchParams.get("day") || new Date().getDate();
  const sortBy = url.searchParams.get("sort") || "date:desc";

  const todayDate = `${new Date().getFullYear()}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;

  try {
    const response = await authFetch(`/api/v2/shows/day_of_year/${todayDate}?sort=${sortBy}`);
    if (!response.ok) throw response;
    const data = await response.json();

    return {
      shows: data.shows || [],
      month: Number(month),
      day: Number(day),
      sortBy,
    };
  } catch (error) {
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React from "react";
import { useLoaderData, useNavigate } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Shows from "./Shows";
import { Helmet } from 'react-helmet-async';

const TodayShows = () => {
  const { shows, month, day, sortBy } = useLoaderData();
  const navigate = useNavigate();

  const handleSortChange = (e) => {
    navigate(`?month=${month}&day=${day}&sort=${e.target.value}`);
  };

  const handleMonthChange = (e) => {
    const newMonth = Number(e.target.value);
    navigate(`?month=${newMonth}&day=${day}&sort=${sortBy}`);
  };

  const handleDayChange = (e) => {
    const newDay = Number(e.target.value);
    navigate(`?month=${month}&day=${newDay}&sort=${sortBy}`);
  };

  const getMonthDayDisplay = () => {
    const date = new Date();
    date.setMonth(month - 1);
    date.setDate(day);
    const options = { month: "long", day: "numeric" };
    return date.toLocaleDateString("en-US", options);
  };

  const monthOptions = Array.from({ length: 12 }, (_, i) => i + 1);
  const dayOptions = Array.from({ length: 31 }, (_, i) => i + 1);

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="title">Today in History</h1>
      <div className="field is-grouped">
        <div className="control">
          <div className="select">
            <select value={month} onChange={handleMonthChange}>
              {monthOptions.map((m) => (
                <option key={m} value={m}>
                  {new Date(0, m - 1).toLocaleString("en-US", { month: "long" })}
                </option>
              ))}
            </select>
          </div>
        </div>
        <div className="control">
          <div className="select">
            <select value={day} onChange={handleDayChange}>
              {dayOptions.map((d) => (
                <option key={d} value={d}>
                  {d}
                </option>
              ))}
            </select>
          </div>
        </div>
      </div>

      <div className="field">
        <div className="control">
          <div className="select">
            <select value={sortBy} onChange={handleSortChange}>
              <option value="date:desc">Sort by Date (newest first)</option>
              <option value="date:asc">Sort by Date (oldest first)</option>
              <option value="likes_count:desc">Sort by Most Liked</option>
              <option value="duration:desc">Sort by Longest Duration</option>
            </select>
          </div>
        </div>
      </div>
    </div>
  );

  return (
    <>
      <Helmet>
        <title>{getMonthDayDisplay()} - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        {shows.length === 0 ? (
          <h1 className="title">No shows found for {getMonthDayDisplay()}.</h1>
        ) : (
          <Shows shows={shows} setShows={() => {}} numbering={false} tourHeaders={true} />
        )}
      </LayoutWrapper>
    </>
  );
};

export default TodayShows;

