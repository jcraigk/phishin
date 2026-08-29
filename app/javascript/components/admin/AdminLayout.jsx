import React, { useEffect } from "react";
import { NavLink, Outlet, useNavigate } from "react-router";

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
          <span className="admin-nav-site">phish.in</span>
        </div>
        <NavLink to="/admin" end className={linkClass}>Dashboard</NavLink>
        <NavLink to="/admin/import" className={linkClass}>Import Show</NavLink>
        <div className="admin-nav-footer">
          <a href="/" target="_blank" rel="noreferrer">View site</a>
        </div>
      </nav>
      <main className="admin-content">
        <Outlet />
      </main>
    </div>
  );
};

export default AdminLayout;
