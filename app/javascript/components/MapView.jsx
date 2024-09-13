import React, { useEffect, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Shows from "./Shows";
import { authFetch } from "./utils";

const TodayShows = () => {
  const [shows, setShows] = useState([]);
  const [sortBy, setSortBy] = useState("date:desc");
  const [month, setMonth] = useState(new Date().getMonth() + 1); // Default to current month
  const [day, setDay] = useState(new Date().getDate()); // Default to current day

  const [searchParams, setSearchParams] = useSearchParams();
  const navigate = useNavigate();

  const getQueryParams = () => {
    return {
      month: searchParams.get("month") ? Number(searchParams.get("month")) : new Date().getMonth() + 1,
      day: searchParams.get("day") ? Number(searchParams.get("day")) : new Date().getDate(),
    };
  };

  const updateQueryParams = (newMonth, newDay) => {
    setSearchParams({ month: newMonth, day: newDay });
  };

  const getTodayDate = () => {
    const year = new Date().getFullYear();
    return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
  };

  const getMonthDayDisplay = () => {
    const date = new Date();
    date.setMonth(month - 1);
    date.setDate(day);
    const options = { month: "long", day: "numeric" };
    return date.toLocaleDateString("en-US", options);
  };

  useEffect(() => {
    // Initialize from URL params
    const { month: urlMonth, day: urlDay } = getQueryParams();
    setMonth(urlMonth);
    setDay(urlDay);
  }, [searchParams]);

  useEffect(() => {
    const fetchShows = async () => {
      const todayDate = getTodayDate();
      try {
        const response = await authFetch(`/api/v2/shows/day_of_year/${todayDate}?sort=${sortBy}`);
        const data = await response.json();
        setShows(data.shows || []);
      } catch (error) {
        console.error("Error fetching shows:", error);
      }
    };

    fetchShows();
  }, [sortBy, month, day]);

  const handleSortChange = (e) => {
    setSortBy(e.target.value);
  };

  const handleMonthChange = (e) => {
    const newMonth = Number(e.target.value);
    setMonth(newMonth);
    updateQueryParams(newMonth, day); // Update URL when month changes
  };

  const handleDayChange = (e) => {
    const newDay = Number(e.target.value);
    setDay(newDay);
    updateQueryParams(month, newDay); // Update URL when day changes
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
    <LayoutWrapper sidebarContent={sidebarContent}>
      {shows.length === 0 ? (
        <h1 className="title">No shows found for {getMonthDayDisplay()}.</h1>
      ) : (
        <>
          <Shows shows={shows} setShows={setShows} numbering={false} tourHeaders={true} />
        </>
      )}
    </LayoutWrapper>
  );
};

export default TodayShows;
