import React from "react";
import { Outlet } from "react-router-dom";
import Navbar from "./Navbar";

const Layout = ({ appName }) => {
  return (
    <>
      <Navbar appName={appName} />
      <main>
        <Outlet />
      </main>
    </>
  );
};

export default Layout;
