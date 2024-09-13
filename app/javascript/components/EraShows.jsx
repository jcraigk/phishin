import React, { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Shows from "./Shows";
import { authFetch } from "./utils";

const EraShows = () => {
  const { routePath } = useParams();
  const [shows, setShows] = useState([]);

  useEffect(() => {
    const fetchShows = async () => {
      try {
        let url = `/api/v2/shows?per_page=1000`;

        if (routePath.includes("-")) {
          url += `&year_range=${routePath}`;
        } else {
          url += `&year=${routePath}`;
        }

        const response = await authFetch(url);
        const data = await response.json();
        setShows(data.shows);
      } catch (error) {
        console.error("Error fetching shows:", error);
      }
    };

    fetchShows();
  }, [routePath]);

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="title">{routePath}</h1>
      <p className="sidebar-subtitle">{shows.length} shows total</p>
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      <Shows shows={shows} setShows={setShows} tourHeaders={true} />
    </LayoutWrapper>
  );
};

export default EraShows;
