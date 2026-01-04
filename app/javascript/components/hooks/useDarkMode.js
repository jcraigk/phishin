import { useEffect } from "react";
import { enable, disable, auto } from "darkreader";

const DARK_READER_CONFIG = {
  brightness: 100,
  contrast: 90,
  sepia: 10,
};

const useDarkMode = () => {
  useEffect(() => {
    auto(DARK_READER_CONFIG);

    return () => {
      auto(false);
      disable();
    };
  }, []);
};

export default useDarkMode;

