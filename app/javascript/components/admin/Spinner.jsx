import React from "react";
import MoonLoader from "react-spinners/MoonLoader";

const Spinner = ({ size = 14, accent = false }) => (
  <MoonLoader color={accent ? "#8ab4f8" : "#c7c8ca"} size={size} speedMultiplier={accent ? 0.8 : 1} />
);

export default Spinner;
