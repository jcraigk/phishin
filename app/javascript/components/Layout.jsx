import React from "react";
import { Outlet } from "react-router-dom";
import Header from "./Header";

const Layout = ({ appName }) => {
  return (
    <>
      <Header appName={appName} />
      <main className="mt-16">
        <Outlet />
      </main>
    </>
  );
};

export default Layout;
