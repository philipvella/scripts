/**
 * Configuration file for Environment Comparison Tool
 * You can modify these settings to customize the behavior
 */

const config = {
  // Default viewport size (set for mobile view)
  viewport: {
    width: 375,
    height: 812
  },

  // Timeout settings (in milliseconds)
  timeouts: {
    pageTimeout: 30000,
    screenshotDelay: 2
  },

  // Browser settings
  browser: {
    headlessMode: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage'
    ]
  },

  // Output settings
  output: {
    fullPageScreenshots: false,
    generateThumbnails: false,
    thumbnailWidth: 400
  },

  // Comparison settings
  comparison: {
    similarityThreshold: 90, // Minimum similarity percentage to consider images as matching
    pixelThreshold: 0.1      // Pixel difference sensitivity (0.0 - 1.0)
  },

  // Report settings
  report: {
    title: 'SSB UAT & PROD Comparison Report',
    includeSummaryStats: true,
    includeTimestamp: true
  },

  // Logging settings
  logging: {
    level: 'INFO', // DEBUG, INFO, WARN, ERROR
    logToFile: false
  }
};

module.exports = config;
