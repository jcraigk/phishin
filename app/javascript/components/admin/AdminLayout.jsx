import React, { useEffect } from "react";
import { Outlet, useNavigate } from "react-router";

// Only the admin gate remains here; navigation lives in the site's own menu.
const AdminLayout = () => {
  const navigate = useNavigate();
  const isAdmin = typeof window !== "undefined" && localStorage.getItem("admin") === "true";

  useEffect(() => {
    if (!isAdmin) navigate("/login");
  }, [isAdmin, navigate]);

  if (!isAdmin) return null;

  return (
    <div className="admin-layout">
      <main className="admin-content">
        <Outlet />
      </main>
    </div>
  );
};

export default AdminLayout;
