const commonWebpackConfig = require('./commonWebpackConfig');

const configureClient = () => {
  const clientConfig = commonWebpackConfig();
  delete clientConfig.entry['server-bundle'];
  return clientConfig;
};

module.exports = configureClient;
