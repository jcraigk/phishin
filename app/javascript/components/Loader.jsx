import React from "react";
import MoonLoader from "react-spinners/MoonLoader";

const Loader = () => {
  return (
    <div className="loader-container">
      <MoonLoader color="#c7c8ca" size={120} />
    </div>
  );
};

export default Loader;
