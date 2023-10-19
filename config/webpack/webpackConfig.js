const clientWebpackConfig = require('./clientWebpackConfig');
const serverWebpackConfig = require('./serverWebpackConfig');

const webpackConfig = (envSpecific) => {
  const clientConfig = clientWebpackConfig();
  const serverConfig = serverWebpackConfig();

  if (envSpecific) {
    envSpecific(clientConfig, serverConfig);
  }

  let result;
  if (process.env.WEBPACK_SERVE || process.env.CLIENT_BUNDLE_ONLY) {
    console.log('[React on Rails] Creating only the client bundles.');
    result = clientConfig;
  } else if (process.env.SERVER_BUNDLE_ONLY) {
    console.log('[React on Rails] Creating only the server bundle.');
    result = serverConfig;
  } else {
    console.log('[React on Rails] Creating both client and server bundles.');
    result = [clientConfig, serverConfig];
  }

  return result;
};

module.exports = webpackConfig;
