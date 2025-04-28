import React from "react";
import { formatDate } from "./utils";

export const createTaperNotesModalContent = (show) => {
  return (
    <>
      <h2 className="title">Taper Notes</h2>
      <h3 className="subtitle">{formatDate(show.date)} • {show.venue_name}</h3>
      <p dangerouslySetInnerHTML={{ __html: (show.taper_notes || "").replace(/\n/g, "<br />") }}></p>
    </>
  );
};
