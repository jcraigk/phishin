export const tagIndexLoader = async () => {
  try {
    const response = await fetch("/api/v2/tags");
    if (!response.ok) throw response;
    const tags = await response.json();
    return { tags };
  } catch (error) {
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React from "react";
import { useLoaderData, Link } from "react-router-dom";
import LayoutWrapper from "./layout/LayoutWrapper";
import Tags from "./Tags";
import { Helmet } from "react-helmet-async";

const TagIndex = () => {
  const { tags } = useLoaderData();

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">Content Tags</p>
      <p className="sidebar-detail">
        Tags are used to annotate and highlight content. The tag associations seen here have been pulled from various Phish.net projects as well as crowd-sourcing through the{" "}
        <Link to="/tagin-project">Tagin' Project</Link>.
      </p>
    </div>
  );

  return (
    <>
      <Helmet>
        <title>Tags - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        <Tags tags={tags} group={true} />
      </LayoutWrapper>
    </>
  );
};

export default TagIndex;
