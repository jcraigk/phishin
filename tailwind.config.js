module.exports = {
  content: [
    "./app/javascript/**/*.js",
    "./app/javascript/**/*.jsx",
    "./app/views/**/*.html.erb",
    "./app/helpers/**/*.rb",
  ],
  theme: {
    extend: {
      fontFamily: {
        "marck-script": ["Marck Script", "cursive"],
        "open-sans": ["Open Sans Condensed", "sans-serif"],
      },
    },
  },
  plugins: [],
};
