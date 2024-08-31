const { devServer, inliningCss } = require('shakapacker');

const webpackConfig = require('./webpackConfig');

const developmentEnvOnly = (clientWebpackConfig, _serverWebpackConfig) => {
  if (inliningCss) {
    const ReactRefreshWebpackPlugin = require('@pmmmwh/react-refresh-webpack-plugin');
    clientWebpackConfig.plugins.push(
      new ReactRefreshWebpackPlugin({
        overlay: {
          sockPort: devServer.port,
        },
      }),
    );
  }

  // Set allowedHosts to disable browser console warning
  // when using ngrok or other tunneling services.
  clientWebpackConfig.devServer = {
    ...clientWebpackConfig.devServer,
    allowedHosts: 'all',
  };
};

module.exports = webpackConfig(developmentEnvOnly);
