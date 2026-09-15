import React from "react";
import { plural } from "./format";

const IssueList = ({ issues, noun = "item", label = "still blocking" }) => (
  <>
    <p className="admin-publish-note">
      {plural(issues.length, noun)} {label}:
    </p>
    <ul className="admin-publish-issues">
      {issues.map((issue) => (
        <li key={issue}>{issue}</li>
      ))}
    </ul>
  </>
);

export default IssueList;
