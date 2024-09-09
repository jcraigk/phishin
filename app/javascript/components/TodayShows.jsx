import React, { useEffect, useState } from "react";
import LayoutWrapper from "./LayoutWrapper";
import Shows from "./Shows";
import { Link } from "react-router-dom";

const TodayShows = ({ user }) => {
  const [shows, setShows] = useState([]);
  const [sortBy, setSortBy] = useState("date:desc");

  const getTodayDate = () => {
    const today = new Date();
    const year = today.getFullYear();
    const month = String(today.getMonth() + 1).padStart(2, "0");
    const day = String(today.getDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
  };

  const getMonthDayDisplay = () => {
    const today = new Date();
    const options = { month: "long", day: "numeric" };
    return today.toLocaleDateString("en-US", options);
  };

  useEffect(() => {
    const fetchShows = async () => {
      const todayDate = getTodayDate();
      try {
        const response = await fetch(`/api/v2/shows/on_day_of_year/${todayDate}?sort=${sortBy}`);
        const data = await response.json();
        setShows(data.shows || []);
      } catch (error) {
        console.error("Error fetching shows:", error);
      }
    };

    fetchShows();
  }, [sortBy]);

  const handleSortChange = (e) => {
    setSortBy(e.target.value);
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="title">Today in History</h1>
      <h1 className="title">{getMonthDayDisplay()}</h1>
      <div className="field">
        <label className="label">Sort by</label>
        <div className="control">
          <div className="select">
            <select value={sortBy} onChange={handleSortChange}>
              <option value="date:desc">Date (newest first)</option>
              <option value="date:asc">Date (oldest first)</option>
              <option value="likes_count:desc">Most Liked</option>
              <option value="duration:desc">Longest Duration</option>
            </select>
          </div>
        </div>
      </div>
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      {shows.length === 0 ? (
        <h1 className="title">No shows found for today.</h1>
      ) : (
        // Pass setShows along with shows to the Shows component
        <Shows shows={shows} setShows={setShows} numbering={false} set_headers={false} />
      )}
    </LayoutWrapper>
  );
};

export default TodayShows;
