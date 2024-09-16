import React from "react";
import SyncLoader from "react-spinners/SyncLoader";

const Loader = () => {
  return (
    <div className="loader-container">
      <SyncLoader color="#c7c8ca" size={50} />
    </div>
  );
};

export default Loader;
