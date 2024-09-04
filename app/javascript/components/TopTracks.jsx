import React, { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Tracks from "./Tracks";

const TopTracks = ({ user }) => {
  const [tracks, setTracks] = useState([]);

  useEffect(() => {
    const fetchTracks = async () => {
      try {
        const response = await fetch(`/api/v2/tracks?per_page=40&sort=likes_count:desc`);
        const data = await response.json();
        setTracks(data);
      } catch (error) {
        console.error("Error fetching tracks:", error);
      }
    };

    fetchTracks();
  }, []);

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="title">Top 40 Tracks</h1>
      <p className="sidebar-detail mb-5">
        An aggregated list of the top tracks, ranked by user Likes from the Phish.in community.
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
      <Tracks tracks={tracks} numbering={true} set_headers={false} />
    </LayoutWrapper>
  );
};

export default TopTracks;