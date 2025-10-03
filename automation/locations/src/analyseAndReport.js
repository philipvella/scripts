// analyseAndReport.js
// Reads recent-locations-with-countries.json and prints a summary table of country visits
const fs = require('fs');
const path = require('path');

async function generateReport() {
    const recentLocationsWithCountriesPath = path.join(__dirname, 'output', 'recent-locations-with-countries.json');
    if (!fs.existsSync(recentLocationsWithCountriesPath)) {
        console.error('recent-locations-with-countries.json file does not exist.');
        return;
    }

    const recentLocationsRaw = JSON.parse(fs.readFileSync(recentLocationsWithCountriesPath, 'utf8'));
    let dateRange, recentLocations;
    if (Array.isArray(recentLocationsRaw)) {
        // Backward compatibility: no dateRange
        dateRange = null;
        recentLocations = recentLocationsRaw;
    } else {
        dateRange = recentLocationsRaw.dateRange;
        recentLocations = recentLocationsRaw.locations;
    }

    // Create a summary report of countries visited with date ranges
    const countrySummary = {};
    function getDateRanges(dates) {
        if (!dates || dates.length === 0) return [];
        // Sort dates
        const sorted = dates.map(d => new Date(d)).sort((a, b) => a - b);
        const ranges = [];
        let rangeStart = sorted[0];
        let rangeEnd = sorted[0];
        for (let i = 1; i < sorted.length; i++) {
            const prev = sorted[i - 1];
            const curr = sorted[i];
            // If current date is the next day after previous, extend the range
            if ((curr - prev) === 24 * 60 * 60 * 1000) {
                rangeEnd = curr;
            } else {
                // Save previous range
                ranges.push({ start: rangeStart, end: rangeEnd });
                rangeStart = curr;
                rangeEnd = curr;
            }
        }
        // Save last range
        ranges.push({ start: rangeStart, end: rangeEnd });
        return ranges;
    }

    for (const location of recentLocations) {
        const country = location.country || 'Unknown';
        if (!countrySummary[country]) {
            countrySummary[country] = {
                firstVisit: null,
                lastVisit: null,
                totalVisits: 0,
                allDates: [],
                dateRanges: []
            };
        }
        if (location.dates && Array.isArray(location.dates)) {
            location.dates.forEach(dateStr => {
                const date = new Date(dateStr);
                countrySummary[country].allDates.push(dateStr);
                if (!countrySummary[country].firstVisit || date < countrySummary[country].firstVisit) {
                    countrySummary[country].firstVisit = date;
                }
                if (!countrySummary[country].lastVisit || date > countrySummary[country].lastVisit) {
                    countrySummary[country].lastVisit = date;
                }
            });
        }
        countrySummary[country].totalVisits += location.visits;
    }

    // Calculate date ranges for each country
    for (const summary of Object.values(countrySummary)) {
        summary.dateRanges = getDateRanges(summary.allDates);
    }

    // Output the summary report to console and to a txt file in output dir
    let reportText = '';
    reportText += 'Country Visit Summary:\n';
    if (dateRange) {
        reportText += `Date Range: ${dateRange.start} to ${dateRange.end}\n`;
    }
    reportText += '------------------------------------------------------------------------------------------\n';
    reportText += '| Country       | First Visit | Last Visit  | Total Visits | Date Ranges                  |\n';
    reportText += '------------------------------------------------------------------------------------------\n';
    for (const [country, summary] of Object.entries(countrySummary)) {
        const firstVisit = summary.firstVisit ? summary.firstVisit.toISOString().slice(0,10) : 'N/A';
        const lastVisit = summary.lastVisit ? summary.lastVisit.toISOString().slice(0,10) : 'N/A';
        const rangesStr = summary.dateRanges.map(r => r.start.toISOString().slice(0,10) === r.end.toISOString().slice(0,10)
            ? r.start.toISOString().slice(0,10)
            : `${r.start.toISOString().slice(0,10)} to ${r.end.toISOString().slice(0,10)}`).join('; ');
        reportText += `| ${country.padEnd(13)} | ${firstVisit} | ${lastVisit} | ${summary.totalVisits.toString().padEnd(12)} | ${rangesStr.padEnd(30)} |\n`;
    }
    reportText += '------------------------------------------------------------------------------------------\n';

    // Write to output/report.txt
    const outputDir = path.join(__dirname, 'output');
    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir);
    }
    const reportPath = path.join(outputDir, 'report.txt');
    fs.writeFileSync(reportPath, reportText, 'utf8');
    console.log(`Report saved to ${reportPath}`);
}

// Run the report
generateReport();
