const { merge, config } = require('shakapacker');
const commonWebpackConfig = require('./commonWebpackConfig');

const webpack = require('webpack');

const configureServer = () => {
  const serverWebpackConfig = commonWebpackConfig();

  const serverEntry = {
    'server-bundle': serverWebpackConfig.entry['server-bundle'],
  };

  if (!serverEntry['server-bundle']) {
    throw new Error(
      "Create a pack with the file name 'server-bundle.js' containing all the server rendering files",
    );
  }

  serverWebpackConfig.entry = serverEntry;

  serverWebpackConfig.module.rules.forEach((loader) => {
    if (loader.use && loader.use.filter) {
      loader.use = loader.use.filter(
        (item) => !(typeof item === 'string' && item.match(/mini-css-extract-plugin/)),
      );
    }
  });

  serverWebpackConfig.optimization = {
    minimize: false,
  };
  serverWebpackConfig.plugins.unshift(new webpack.optimize.LimitChunkCountPlugin({ maxChunks: 1 }));

  serverWebpackConfig.output = {
    filename: 'server-bundle.js',
    globalObject: 'this',
    path: config.outputPath,
    publicPath: config.publicPath,
  };

  serverWebpackConfig.plugins = serverWebpackConfig.plugins.filter(
    (plugin) =>
      plugin.constructor.name !== 'WebpackAssetsManifest' &&
      plugin.constructor.name !== 'MiniCssExtractPlugin' &&
      plugin.constructor.name !== 'ForkTsCheckerWebpackPlugin',
  );

  const rules = serverWebpackConfig.module.rules;
  rules.forEach((rule) => {
    if (Array.isArray(rule.use)) {
      // remove the mini-css-extract-plugin and style-loader
      rule.use = rule.use.filter((item) => {
        let testValue;
        if (typeof item === 'string') {
          testValue = item;
        } else if (typeof item.loader === 'string') {
          testValue = item.loader;
        }
        return !(testValue.match(/mini-css-extract-plugin/) || testValue === 'style-loader');
      });
      const cssLoader = rule.use.find((item) => {
        let testValue;

        if (typeof item === 'string') {
          testValue = item;
        } else if (typeof item.loader === 'string') {
          testValue = item.loader;
        }

        return testValue.includes('css-loader');
      });
      if (cssLoader && cssLoader.options) {
        cssLoader.options.modules = { exportOnlyLocals: true };
      }

    } else if (rule.use && (rule.use.loader === 'url-loader' || rule.use.loader === 'file-loader')) {
      rule.use.options.emitFile = false;
    }
  });

  serverWebpackConfig.devtool = 'eval';

  return serverWebpackConfig;
};

module.exports = configureServer;
