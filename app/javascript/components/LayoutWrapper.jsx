import React from "react";

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

export default LayoutWrapper;
