import { authFetch } from "./helpers/utils";

export const todayShowsLoader = async ({ request }) => {
  const url = new URL(request.url);
  const month = url.searchParams.get("month") || new Date().getMonth() + 1;
  const day = url.searchParams.get("day") || new Date().getDate();
  const sortBy = url.searchParams.get("sort") || "date:desc";

  const todayDate = `${new Date().getFullYear()}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;

  // Check localStorage for audio filter setting
  const showMissingAudio = JSON.parse(localStorage.getItem('showMissingAudio') || 'false');
  const audioStatusFilter = showMissingAudio ? 'any' : 'complete_or_partial';

  try {
    const response = await authFetch(`/api/v2/shows/day_of_year/${todayDate}?sort=${sortBy}&audio_status=${audioStatusFilter}`);
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
import { Helmet } from "react-helmet-async";
import LayoutWrapper from "./layout/LayoutWrapper";
import Shows from "./Shows";
import PhoneTiltSuggestion from "./PhoneTiltSuggestion";

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
      <p className="sidebar-title">Today in History</p>

      <div className="sidebar-filters">
        <div className="select">
          <select value={month} onChange={handleMonthChange}>
            {monthOptions.map((m) => (
              <option key={m} value={m}>
                {new Date(0, m - 1).toLocaleString("en-US", { month: "long" })}
              </option>
            ))}
          </select>
        </div>

        <div className="select">
          <select value={day} onChange={handleDayChange}>
            {dayOptions.map((d) => (
              <option key={d} value={d}>
                {d}
              </option>
            ))}
          </select>
        </div>

        <div className="select">
          <select value={sortBy} onChange={handleSortChange}>
            <option value="date:desc">Sort by Date (Newest First)</option>
            <option value="date:asc">Sort by Date (Oldest First)</option>
            <option value="likes_count:desc">Sort by Likes (High to Low)</option>
            <option value="likes_count:asc">Sort by Likes (Low to High)</option>
            <option value="duration:desc">Sort by Duration (Longest First)</option>
            <option value="duration:asc">Sort by Duration (Shortest First)</option>
          </select>
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
          <Shows shows={shows} tourHeaders={true} />
        )}
        <PhoneTiltSuggestion />
      </LayoutWrapper>
    </>
  );
};

export default TodayShows;

