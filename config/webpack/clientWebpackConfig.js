// The source code including full typescript support is available at:
// https://github.com/shakacode/react_on_rails_demo_ssr_hmr/blob/master/config/webpack/clientWebpackConfig.js

const path = require('path');
const commonWebpackConfig = require('./commonWebpackConfig');

const configureClient = () => {
  const clientConfig = commonWebpackConfig();

  // server-bundle is special and should ONLY be built by the serverConfig
  // In case this entry is not deleted, a very strange "window" not found
  // error shows referring to window["webpackJsonp"]. That is because the
  // client config is going to try to load chunks.
  delete clientConfig.entry['server-bundle'];

  // Use the client-only build of react-on-rails which excludes ~14KB of
  // server-rendering code that browsers don't need.
  // See: https://forum.shakacode.com/t/how-to-use-different-versions-of-a-file-for-client-and-server-rendering/1352
  clientConfig.resolve = clientConfig.resolve || {};
  clientConfig.resolve.alias = clientConfig.resolve.alias || {};
  clientConfig.resolve.alias['react-on-rails'] = path.resolve(
    __dirname, '../../node_modules/react-on-rails/lib/ReactOnRails.client.js'
  );

  return clientConfig;
};

module.exports = configureClient;
