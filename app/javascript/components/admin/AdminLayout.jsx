import React, { useEffect } from "react";
import { Link, Outlet, useNavigate } from "react-router";

const AdminLayout = () => {
  const navigate = useNavigate();
  const isAdmin = typeof window !== "undefined" && localStorage.getItem("admin") === "true";

  useEffect(() => {
    if (!isAdmin) navigate("/login");
  }, [isAdmin, navigate]);

  if (!isAdmin) return null;

  return (
    <div className="admin-layout">
      <nav className="admin-nav">
        <h2>Admin</h2>
        <Link to="/admin">Dashboard</Link>
        <Link to="/admin/import">Import Show</Link>
      </nav>
      <main className="admin-content">
        <Outlet />
      </main>
    </div>
  );
};

export default AdminLayout;
