export const missingContentLoader = async () => {
  try {
    const response = await fetch("/api/v2/reports/missing_content");
    if (!response.ok) throw response;
    const data = await response.json();
    const combinedData = [
      ...data.missing_show_dates.map((date) => ({ date, type: "Missing" })),
      ...data.incomplete_show_dates.map((date) => ({ date, type: "Incomplete" }))
    ];
    combinedData.sort((a, b) => new Date(b.date) - new Date(a.date));
    return combinedData;
  } catch (error) {
    console.error("Error fetching data", error);
    throw new Response("Error fetching missing content data", { status: 500 });
  }
};

import React from "react";
import { Link, useLoaderData } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import { Helmet } from "react-helmet-async";

const MissingContentReport = () => {
  const missingContent = useLoaderData();

  const incompleteCount = missingContent.filter(item => item.type === "Incomplete").length;
  const missingCount = missingContent.filter(item => item.type === "Missing").length;
  const totalIssues = incompleteCount + missingCount;

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="title">Missing and Incomplete Content</h1>
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
        <div className="section-title">
          <div className="title-left">Missing and Incomplete Content</div>
        </div>
        <ul>
          {missingContent.map(({ date, type }) => (
            <li className="list-item" key={date}>
              <span className="leftside-primary">{date}</span>
              <span className="leftside-secondary">
                {type === "Incomplete" ? (
                  <Link to={`/${date}`}>{type}</Link>
                ) : (
                  type
                )}
              </span>
            </li>
          ))}
        </ul>
      </LayoutWrapper>
    </>
  );
};

export default MissingContentReport;
