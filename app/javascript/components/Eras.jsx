import React from "react";
import { Link } from "react-router-dom";

const Eras = ({ eras }) => {
  const parsedEras = JSON.parse(eras); // Convert JSON string to JS object

  return (
    <div>
      {Object.keys(parsedEras)
        .sort((a, b) => b.localeCompare(a)) // Sort eras in reverse order
        .map((era) => (
          <div key={era}>
            <h2>{era}</h2>
            <ul>
              {parsedEras[era]
                .slice() // Make a shallow copy to avoid mutating original data
                .reverse() // Reverse the years within each era
                .map((year) => (
                  <li key={year} style={{ listStyleType: "none" }}>
                    <Link
                      className="content-item"
                      to={`/${year}`}
                    >
                      {year}
                    </Link>
                  </li>
                ))}
            </ul>
          </div>
        ))}
    </div>
  );
};

export default Eras;
