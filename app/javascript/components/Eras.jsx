import React, { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { formatNumber } from "./utils";

const Eras = () => {
  const [eras, setEras] = useState({});

  useEffect(() => {
    fetch("/api/v2/years")
      .then(response => response.json().then(data => {
        if (response.ok) {
          const erasData = data.reduce((acc, { era, period, shows_count, venues_count }) => {
            if (!acc[era]) {
              acc[era] = { periods: [], total_shows: 0 };
            }
            acc[era].periods.push({ period, shows_count, venues_count });
            acc[era].total_shows += shows_count;
            return acc;
          }, {});

          Object.keys(erasData).forEach((era) => {
            erasData[era].periods.sort((a, b) => b.period.localeCompare(a.period));
          });

          setEras(erasData);
        } else {
          console.error("Error fetching data");
        }
      }));
  }, []);

  return (
    <div className="list-container">
      {Object.keys(eras)
        .sort((a, b) => b.localeCompare(a)) // Sort eras in reverse order
        .map((era) => (
          <React.Fragment key={era}>
            <div className="section-title">
              <h2>{era} Era</h2>
              <span className="detail-right">{formatNumber(eras[era].total_shows)} shows</span>
            </div>
            <ul>
              {eras[era].periods.map(({ period, shows_count, venues_count }) => (
                <Link to={`/${period}`} key={period} className="list-item-link">
                  <li className="list-item">
                    <span className="primary-data">{period}</span>
                    <span className="secondary-data">
                      {venues_count} venue{venues_count !== 1 ? "s" : ""}
                    </span>
                    <span className="tertiary-data">
                      {formatNumber(shows_count)} show{shows_count !== 1 ? "s" : ""}
                    </span>
                  </li>
                </Link>
              ))}
            </ul>
          </React.Fragment>
        ))}
    </div>
  );
};

export default Eras;
