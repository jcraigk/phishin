import React from "react";
import PropTypes from "prop-types";

const LayoutWrapper = ({ sidebarContent, children }) => {
  return (
    <div className="layout-container">
      <aside className="sidebar">
        {sidebarContent}
      </aside>
      <section className="main-content">
        {children}
      </section>
    </div>
  );
};

LayoutWrapper.propTypes = {
  sidebarContent: PropTypes.node.isRequired,
  children: PropTypes.node.isRequired,
};

export default LayoutWrapper;
