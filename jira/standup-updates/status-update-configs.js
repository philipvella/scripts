// Example configurations for different projects/teams
// Copy and customize for your workflow

// Example 1: Payments Help-Centre Migration
const PaymentsHelpCentre = {
  name: 'Help-Centre Migration',
  projectKey: 'PAY',
  issueKeys: ['PAY-8330', 'PAY-8331', 'PAY-8411', 'PAY-8325', 'PAY-8329', 'PAY-7559'],
  dateRange: 'May 26-28, 2026',
  description: 'Help-centre CI migration from cloudflare-pages to unified-v2 worker pipelines',
};

// Example 2: Multiple Payments Stories
const PaymentsWeekly = {
  name: 'Weekly Payments Update',
  projectKey: 'PAY',
  issueKeys: ['PAY-8325', 'PAY-8330', 'PAY-8331', 'PAY-8411', 'PAY-8329'],
  dateRange: 'May 21-28, 2026',
};

// Example 3: Cross-project Sprint
const SprintStatuts = {
  name: 'Sprint Completion Status',
  projectKey: 'MULTI',
  issueKeys: [
    'PAY-8330', 'PAY-8331',  // Payments
    'PLAT-123', 'PLAT-124',  // Platform
    'FE-456', 'FE-457',      // Frontend
  ],
  dateRange: 'May 22-28, 2026',
};

/**
 * Usage in generate-status-update-with-env.js:
 *
 * Instead of:
 *   const issueKeys = ['PAY-8330', ...];
 *
 * Use:
 *   const config = PaymentsHelpCentre;  // or any other config
 *   const issueKeys = config.issueKeys;
 */

module.exports = {
  PaymentsHelpCentre,
  PaymentsWeekly,
  SprintStatuts,
};

