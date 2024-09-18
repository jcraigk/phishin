import React from "react";
import { Link } from "react-router-dom";
import TagBadges from "./TagBadges";
import { formatNumber } from "./utils";
import HighlightedText from "./HighlightedText";

const Tags = ({ tags, group = false, highlight = "" }) => {
  let groupedTags = {};

  if (group) {
    groupedTags = tags.reduce((acc, tag) => {
      if (!acc[tag.group]) {
        acc[tag.group] = [];
      }
      acc[tag.group].push(tag);
      return acc;
    }, {});
  }

  const renderTagItem = (tag) => (
    <li key={tag.slug} className="list-item">
      <span className="leftside-primary-narrow">
        <TagBadges tags={[tag]} />
      </span>
      <span className="leftside-secondary">
        <HighlightedText text={tag.description} highlight={highlight} />
      </span>
      <span className="rightside-primary-wide">
        <Link to={`/show_tags/${tag.slug}`} className="button is-small mr-1">
          {formatNumber(tag.shows_count, "show")}
        </Link>
        <Link to={`/track_tags/${tag.slug}`} className="button is-small">
          {formatNumber(tag.tracks_count, "track")}
        </Link>
      </span>
    </li>
  );

  // Render grouped tags with headers
  if (group) {
    const sortedGroups = Object.keys(groupedTags).sort();
    sortedGroups.forEach(group => {
      groupedTags[group].sort((a, b) => a.name.localeCompare(b.name));
    });

    return (
      <>
        {sortedGroups.map(group => (
          <React.Fragment key={group}>
            <div className="section-title">
              <div className="title-left">{group}</div>
              <span className="detail-right">{groupedTags[group].length} tags</span>
            </div>
            <ul className="tag-list">
              {groupedTags[group].map(tag => renderTagItem(tag))}
            </ul>
          </React.Fragment>
        ))}
      </>
    );
  }

  // Render tags without grouping
  return (
    <ul className="tag-list">
      {tags.map(tag => renderTagItem(tag))}
    </ul>
  );
};

export default Tags;