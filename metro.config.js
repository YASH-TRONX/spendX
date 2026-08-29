const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');

/**
 * Metro configuration
 * https://reactnative.dev/docs/metro
 *
 * @type {import('@react-native/metro-config').MetroConfig}
 */
const defaultConfig = getDefaultConfig(__dirname);
const {
  resolver: { sourceExts, assetExts },
} = defaultConfig;

const config = {
  transformer: {
    // 1. Point the transformer to the svg-transformer library
    babelTransformerPath: require.resolve('react-native-svg-transformer'),
  },
  resolver: {
    // 2. Remove 'svg' from assetExts so Metro doesn't treat it as a binary file
    assetExts: assetExts.filter((ext) => ext !== 'svg'),
    // 3. Add 'svg' to sourceExts so it's treated as source code
    sourceExts: [...sourceExts, 'svg'],
  },
};

module.exports = mergeConfig(defaultConfig, config);