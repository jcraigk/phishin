export const erasLoader = async () => {
  try {
    const response = await fetch("/api/v2/years");
    if (!response.ok) throw new Error("Error fetching data");
    const data = await response.json();

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

    return erasData;
  } catch (error) {
    console.error("Error fetching data", error);
    throw new Response("Error fetching eras data", { status: 500 });
  }
};

import React from "react";
import { Link, useLoaderData } from "react-router-dom";
import { formatNumber } from "./utils";
import LayoutWrapper from "./LayoutWrapper";
import relistenIcon from "../images/icon-relisten.png";
import splendorIcon from "../images/icon-splendor.png";

const Eras = () => {
  const eras = useLoaderData();

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="has-text-weight-bold mb-5">LIVE PHISH AUDIO STREAMS</p>

      <p className="has-text-weight-bold mb-2 mt-5">Mobile Apps</p>
      <a href="https://itunes.apple.com/us/app/relisten-all-live-music/id715886886" target="_blank">
        <img src={relistenIcon} alt="iOS app" />
        <p className="mb-1">Relisten</p>
      </a>

      <a href="https://play.google.com/store/apps/details?id=never.ending.splendor" target="_blank">
        <img src={splendorIcon} alt="Android app" />
        <p>Never Ending Splendor</p>
      </a>

      <p className="has-text-weight-bold mb-1 mt-5">This project is open source</p>
      <p>
        <a href="https://github.com/jcraigk/phishin">Develop on GitHub</a>
        <br />
        <a href="https://discord.gg/KZWFsNN">Discuss on Discord</a>
        <br />
        <a href="/feeds/rss">RSS Feed</a>
      </p>
    </div>
  );

  return (
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
  );
};

export default Eras;

