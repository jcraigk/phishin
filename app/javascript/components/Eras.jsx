export const erasLoader = async () => {
  try {
    const response = await fetch("/api/v2/years");
    if (!response.ok) throw response;
    const data = await response.json();

    const erasData = data.reduce((acc, { era, period, shows_count, shows_duration, venues_count }) => {
      if (!acc[era]) {
        acc[era] = { periods: [], total_shows: 0, total_duration: 0 };
      }
      acc[era].periods.push({ period, shows_count, venues_count });
      acc[era].total_shows += shows_count;
      acc[era].total_duration += shows_duration; // Accumulating total duration in milliseconds
      return acc;
    }, {});

    Object.keys(erasData).forEach((era) => {
      erasData[era].periods.sort((a, b) => b.period.localeCompare(a.period));
    });

    return erasData;
  } catch (error) {
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React from "react";
import { Link, useLoaderData } from "react-router-dom";
import { formatNumber } from "./utils";
import LayoutWrapper from "./LayoutWrapper";
import MobileApps from "./pages/MobileApps";
import GitHubButton from "./pages/GitHubButton";
import DiscordButton from "./pages/DiscordButton";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faRss } from "@fortawesome/free-solid-svg-icons";

const Eras = () => {
  const eras = useLoaderData();

  const totalShows = Object.keys(eras).reduce((sum, era) => sum + eras[era].total_shows, 0);
  const totalDurationMs = Object.keys(eras).reduce((sum, era) => sum + eras[era].total_duration, 0);
  const totalHours = Math.round(totalDurationMs / (1000 * 60 * 60));

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="has-text-weight-bold">LIVE PHISH AUDIO STREAMS</p>
      <div className="hidden-mobile">
        <p>{formatNumber(totalShows)} shows</p>
        <p>{formatNumber(totalHours)} hours of music</p>
      </div>
      <div className="visible-mobile">
        <p>
          {formatNumber(totalShows)} shows
          •{" "}
          {formatNumber(totalHours)} hours of music
        </p>
      </div>

      <MobileApps className="mt-5" />

      <div className="external-links">
        <p className="has-text-weight-bold mb-1 mt-5 project-open-source">This project is open source</p>
        <div>
          <GitHubButton className="mb-2" />
          <DiscordButton className="mb-2" />
          <a href="/feeds/rss" className="button" target="_blank">
            <span className="icon mr-1">
              <FontAwesomeIcon icon={faRss} />
            </span>
            RSS
          </a>
        </div>
      </div>
    </div>
  );

  return (
    <>
      <LayoutWrapper sidebarContent={sidebarContent}>
        {Object.keys(eras)
          .sort((a, b) => b.localeCompare(a))
          .map((era) => (
            <React.Fragment key={era}>
              <div className="section-title">
                <div className="title-left">{era} Era</div>
                <span className="detail-right">{formatNumber(eras[era].total_shows, 'show')}</span>
              </div>
              <ul>
                {eras[era].periods.map(({ period, shows_count, venues_count }) => (
                  <Link to={`/${period}`} key={period} className="list-item-link">
                    <li className="list-item">
                      <span className="leftside-primary-narrow">{period}</span>
                      <span className="leftside-secondary">
                        {venues_count} venue{venues_count !== 1 ? "s" : ""}
                      </span>
                      <span className="rightside-primary">
                        {formatNumber(shows_count, 'show')}
                      </span>
                    </li>
                  </Link>
                ))}
              </ul>
            </React.Fragment>
          ))}
      </LayoutWrapper>
    </>
  );
};

export default Eras;
