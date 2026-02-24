export const tagIndexLoader = async () => {
  const response = await fetch("/api/v2/tags").catch(error => {
    console.error("Error fetching tags data:", error);
    throw new Response("Error fetching data", { status: 500 });
  });
  if (!response.ok) throw response;
  const tags = await response.json();
  return { tags };
};

import React from "react";
import { useLoaderData, Link } from "react-router";
import { Helmet } from "react-helmet-async";
import LayoutWrapper from "./layout/LayoutWrapper";
import Tags from "./Tags";

const TagIndex = () => {
  const { tags } = useLoaderData();

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">Content Tags</p>
      <p className="sidebar-detail hidden-mobile">
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
