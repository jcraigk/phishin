const webpackConfig = require('./webpackConfig');
// const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer');

const productionEnvOnly = (_clientWebpackConfig, _serverWebpackConfig) => {
  // BundleAnalyzerPlugin
  // CLIENT_BUNDLE_ONLY=true NODE_ENV=production bin/shakapacker
  // _clientWebpackConfig.plugins.push(
  //   new BundleAnalyzerPlugin({
  //     analyzerMode: 'static',
  //     openAnalyzer: true,
  //     reportFilename: 'bundle-report.html',
  //   }),
  // );
};

module.exports = webpackConfig(productionEnvOnly);
