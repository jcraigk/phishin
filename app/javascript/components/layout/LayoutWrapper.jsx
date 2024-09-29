import React from "react";

const LayoutWrapper = ({ sidebarContent, children }) => {
  return (
    <div className="layout-container">
      <aside id="sidebar">
        {sidebarContent}
      </aside>
      <section id="main-content">
        {children}
      </section>
    </div>
  );
};

export default LayoutWrapper;
