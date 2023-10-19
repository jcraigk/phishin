const webpackConfig = require('./webpackConfig');

const productionEnvOnly = (_clientWebpackConfig, _serverWebpackConfig) => {
  // place any code here that is for production only
};

module.exports = webpackConfig(productionEnvOnly);
