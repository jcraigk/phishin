import React from "react";
import { useParams } from "react-router-dom";

const YearRangePage = () => {
  const { yearRange } = useParams();

  const isRange = yearRange.includes("-");
  const content = isRange
    ? `This is a year range: ${yearRange}`
    : `This is a year: ${yearRange}`;

  return (
    <div>
      <h1>{content}</h1>
      <p>Rendering content for the selected year or year range.</p>
    </div>
  );
};

export default YearRangePage;
