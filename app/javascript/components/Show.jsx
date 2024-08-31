import React from "react";
import { useParams } from "react-router-dom";

const Show = () => {
  const { date } = useParams();

  return (
    <div>
      <h1>Show on {date}</h1>
      <p>Rendering content for the specific show on {date}.</p>
    </div>
  );
};

export default Show;
