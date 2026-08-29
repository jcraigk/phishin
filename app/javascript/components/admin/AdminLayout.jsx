import React, { useEffect } from "react";
import { NavLink, Outlet, useNavigate } from "react-router";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import {
  faCompactDisc,
  faExternalLinkAlt,
  faGauge,
} from "@fortawesome/free-solid-svg-icons";

const AdminLayout = () => {
  const navigate = useNavigate();
  const isAdmin = typeof window !== "undefined" && localStorage.getItem("admin") === "true";

  useEffect(() => {
    if (!isAdmin) navigate("/login");
  }, [isAdmin, navigate]);

  if (!isAdmin) return null;

  const linkClass = ({ isActive }) => (isActive ? "active" : "");

  return (
    <div className="admin-layout">
      <nav className="admin-nav">
        <div className="admin-nav-brand">
          <span className="admin-nav-title">Admin</span>
        </div>
        <NavLink to="/admin" end className={linkClass}>
          <FontAwesomeIcon icon={faGauge} fixedWidth /> Dashboard
        </NavLink>
        <NavLink to="/admin/shows" className={linkClass}>
          <FontAwesomeIcon icon={faCompactDisc} fixedWidth /> Shows
        </NavLink>
        <div className="admin-nav-footer">
          <a href="/" target="_blank" rel="noreferrer">
            <FontAwesomeIcon icon={faExternalLinkAlt} fixedWidth /> View site
          </a>
        </div>
      </nav>
      <main className="admin-content">
        <Outlet />
      </main>
    </div>
  );
};

export default AdminLayout;
