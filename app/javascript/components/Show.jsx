import React, { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { formatDate, formatDurationTrack } from "./utils";
import ErrorPage from "./pages/ErrorPage"; // Import the ErrorPage component

const Show = () => {
  const { route_path } = useParams();
  const [show, setShow] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchShow = async () => {
      try {
        const response = await fetch(`/api/v2/shows/on_date/${route_path}`);
        if (response.status === 404) {
          setError(`No data was found for the date ${route_path}`);
          return;
        }
        const data = await response.json();
        setShow(data);
      } catch (error) {
        console.error("Error fetching show:", error);
        setError("An unexpected error has occurred.");
      }
    };

    fetchShow();
  }, [route_path]);

  if (error) {
    return <ErrorPage message={error} />;
  }

  if (!show) {
    return <div>Loading...</div>;
  }

  let lastSetName = null;

  return (
    <div className="list-container">
      <ul>
        {show.tracks.map((track, index) => {
          const isNewSet = track.set_name !== lastSetName;
          lastSetName = track.set_name;

          return (
            <React.Fragment key={track.id}>
              {isNewSet && (
                <div className="section-title">
                  <div className="title-left">{track.set_name}</div>
                </div>
              )}
              <li className="list-item">
                <span className="leftside-primary">{track.title}</span>
                <span className="leftside-secondary">
                  {track.tags.map(tag => tag.name).join(", ")}
                </span>
                <span className="rightside-primary">{formatDurationTrack(track.duration)}</span>
              </li>
            </React.Fragment>
          );
        })}
      </ul>
    </div>
  );
};

export default Show;
