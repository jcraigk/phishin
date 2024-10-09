// The source code including full typescript support is available at:
// https://github.com/shakacode/react_on_rails_demo_ssr_hmr/blob/master/config/webpack/production.js

const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer');
const webpackConfig = require('./webpackConfig');

const productionEnvOnly = (_clientWebpackConfig, _serverWebpackConfig) => {
  // place any code here that is for production only

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
