import React, { useEffect, useState } from "react";
import LayoutWrapper from "./LayoutWrapper";
import Tags from "./Tags";

const TagIndex = () => {
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
      <Tags tags={tags} group={true} />
    </LayoutWrapper>
  );
};

export default TagIndex;
