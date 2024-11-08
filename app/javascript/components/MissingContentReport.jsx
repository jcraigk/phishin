export const missingContentLoader = async () => {
  try {
    const response = await fetch("/api/v2/reports/missing_content");
    if (!response.ok) throw response;
    const data = await response.json();
    const combinedData = [
      ...data.missing_shows.map((show) => ({ ...show, type: "Missing" })),
      ...data.incomplete_shows.map((show) => ({ ...show, type: "Incomplete" }))
    ];
    combinedData.sort((a, b) => new Date(b.date) - new Date(a.date));
    return combinedData;
  } catch (error) {
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React from "react";
import { Link, useLoaderData } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import { formatNumber } from "./helpers/utils";
import LayoutWrapper from "./layout/LayoutWrapper";

const MissingContentReport = () => {
  const missingContent = useLoaderData();

  const incompleteCount = missingContent.filter((item) => item.type === "Incomplete").length;
  const missingCount = missingContent.filter((item) => item.type === "Missing").length;
  const totalIssues = incompleteCount + missingCount;

  let lastYear = null;

  const countShowsForYear = (year) => {
    return missingContent.filter(({ date }) => new Date(date).getFullYear() === year).length;
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">Missing and Incomplete Content</p>
      <p className="sidebar-subtitle">{totalIssues} total issues</p>
      <p className="sidebar-subtitle">{incompleteCount} incomplete shows</p>
      <p className="sidebar-subtitle">{missingCount} missing shows</p>
    </div>
  );

  return (
    <>
      <Helmet>
        <title>Missing Content Report - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        <ul>
          {missingContent.map(({ date, venue_name, location, type }) => {
            const currentYear = new Date(date).getFullYear();
            const isNewYear = currentYear !== lastYear;

            if (isNewYear) {
              lastYear = currentYear;
            }

            return (
              <>
                {isNewYear && (
                  <div className="section-title">
                    <div className="title-left">{lastYear}</div>
                    <span className="detail-right">{formatNumber(countShowsForYear(lastYear), "show")}</span>
                  </div>
                )}
                <li className="list-item">
                  <div className="main-row">
                    <span className="leftside-primary">
                      <span className="text">{date}</span>
                    </span>
                    <span className="leftside-secondary">{venue_name}</span>
                    <span className="leftside-tertiary">{location}</span>
                    <span className="rightside-group">
                      {type === "Incomplete" ? (
                        <Link to={`/${date}`} className="button is-small">
                          {type}
                        </Link>
                      ) : (
                        type
                      )}
                    </span>
                  </div>
                </li>
              </>
            );
          })}
        </ul>
      </LayoutWrapper>
    </>
  );
};

export default MissingContentReport;
