import React, { useEffect, useState } from "react";
import LayoutWrapper from "./LayoutWrapper";
import TagBadges from "./TagBadges";
import { Link } from "react-router-dom";

const Tags = () => {
  const [tags, setTags] = useState([]);

  useEffect(() => {
    const fetchTags = async () => {
      try {
        const response = await fetch("/api/v2/tags");
        const data = await response.json();
        setTags(data);
      } catch (error) {
        console.error("Error fetching tags:", error);
      }
    };

    fetchTags();
  }, []);

  const groupedTags = tags.reduce((acc, tag) => {
    if (!acc[tag.group]) {
      acc[tag.group] = [];
    }
    acc[tag.group].push(tag);
    return acc;
  }, {});

  const sortedGroups = Object.keys(groupedTags).sort();
  sortedGroups.forEach(group => {
    groupedTags[group].sort((a, b) => a.name.localeCompare(b.name));
  });

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="title">All Tags</h1>
      <p className="sidebar-detail">
        Tags are used to annotate and highlight content. The tag associations seen here have been pulled from various Phish.net projects as well as crowd-sourcing through the Tag.in Project.
      </p>
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      {sortedGroups.map(group => (
        <React.Fragment key={group}>
          <div className="section-title">
            <div className="title-left">{group}</div>
            <span className="detail-right">{groupedTags[group].length} tags</span>
          </div>
          <ul className="tag-list">
            {groupedTags[group].map(tag => (
              <li key={tag.slug} className="list-item">
                <span className="leftside-primary">
                  <TagBadges tags={[tag]} />
                </span>
                <span className="leftside-secondary">{tag.description}</span>
                <span className="rightside-primary">
                  <Link to={`/show_tags/${tag.slug}`} className="button is-small">
                    {tag.shows_count} shows
                  </Link>
                </span>
                <span className="rightside-secondary">
                  <Link to={`/track_tags/${tag.slug}`} className="button is-small">
                    {tag.tracks_count} tracks
                  </Link>
                </span>
              </li>
            ))}
          </ul>
        </React.Fragment>
      ))}
    </LayoutWrapper>
  );
};

export default Tags;
