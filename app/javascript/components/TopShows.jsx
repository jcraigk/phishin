import React, { useEffect, useState } from "react";
import LayoutWrapper from "./LayoutWrapper";
import Shows from "./Shows";
import { Link } from "react-router-dom";

const TopShows = ({ user }) => {
  const [shows, setShows] = useState([]);

  useEffect(() => {
    const fetchShows = async () => {
      try {
        const response = await fetch(`/api/v2/shows?per_page=40&sort=likes_count:desc`);
        const data = await response.json();
        setShows(data);
      } catch (error) {
        console.error("Error fetching shows:", error);
      }
    };

    fetchShows();
  }, []);

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="title">Top 40 Shows</h1>
      <p className="sidebar-detail mb-5">
        An aggregated list of the top shows, ranked by user Likes from the Phish.in community.
      </p>
      {!user && (
        <div className="sidebar-callout">
          <Link to="/login" className="button">
            Login to contribute!
          </Link>
        </div>
      )}
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      <Shows shows={shows} numbering={true} />
    </LayoutWrapper>
  );
};

export default TopShows;
