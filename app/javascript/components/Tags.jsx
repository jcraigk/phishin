import React from "react";
import { Link } from "react-router-dom";
import { formatNumber } from "./helpers/utils";
import TagBadges from "./controls/TagBadges";
import HighlightedText from "./controls/HighlightedText";

const Tags = ({ tags, group = false, highlight }) => {
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
      <div className="main-row">
        <span className="leftside-primary">
          <TagBadges tags={[tag]} parentId={tag.slug} />
        </span>
        <span className="leftside-secondary">
          <HighlightedText text={tag.description} highlight={highlight} />
        </span>
        <div className="rightside-group">
          <span className="rightside-primary-wide">
            <Link to={`/show-tags/${tag.slug}`} className="button is-small mr-1">
              {formatNumber(tag.shows_count, "show")}
            </Link>
            <Link to={`/track-tags/${tag.slug}`} className="button is-small">
              {formatNumber(tag.tracks_count, "track")}
            </Link>
          </span>
        </div>
      </div>
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
            <ul>
              {groupedTags[group].map(tag => renderTagItem(tag))}
            </ul>
          </React.Fragment>
        ))}
      </>
    );
  }

  // Render tags without grouping
  return (
    <ul>
      {tags.map(tag => renderTagItem(tag))}
    </ul>
  );
};

export default Tags;
