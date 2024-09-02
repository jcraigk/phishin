import React from "react";

const Eras = ({ eras }) => {
  const parsedEras = JSON.parse(eras); // Convert JSON string to JS object

  return (
    <div>
      {Object.keys(parsedEras).map((era) => (
        <div key={era}>
          <h2>{era}</h2>
          <ul>
            {parsedEras[era].map((year) => (
              <li key={year}>{year}</li>
            ))}
          </ul>
        </div>
      ))}
    </div>
  );
};

export default Eras;
