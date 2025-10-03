console.log('Locations service started.');
// read location-history.json and create a list of locations visited in the last 7 days
const fs = require('fs');
const path = require('path');

// Load location history from JSON file
const locationHistoryPath = path.join(__dirname, '../private/location-history.json');
const locationHistory = JSON.parse(fs.readFileSync(locationHistoryPath, 'utf8'));

// UK tax year hardcoded: 2024-2025
// UK tax year runs from 6 April 2024 to 5 April 2025
const startDate = new Date('2024-04-06');
const endDate = new Date('2025-04-05');

// Filter locations visited in the UK tax year
const recentLocations = locationHistory.filter(location => {
    const visitDate = new Date(location.endTime);
    return visitDate >= startDate && visitDate <= endDate;
});

// Create a list of unique locations visited in the last 7 days
const uniqueLocations = {};
recentLocations.forEach(location => {
    // Use placeLocation and semanticType from topCandidate for uniqueness
    const key = `${location?.visit?.topCandidate?.placeLocation}`;
    if (!uniqueLocations[key]) {
        uniqueLocations[key] = {
            placeLocation: location?.visit?.topCandidate?.placeLocation,
            semanticType: location?.visit?.topCandidate?.semanticType,
            visits: 0,
            dates: []
        };
    }
    uniqueLocations[key].visits += 1;
    // Add the visit date to the dates array
    const visitDate = location.endTime ? new Date(location.endTime).toISOString().slice(0,10) : null;
    if (visitDate) {
        uniqueLocations[key].dates.push(visitDate);
    }
});

// Convert the unique locations object to an array
const locationsList = Object.values(uniqueLocations);

// Output the list of locations visited in the UK tax year
console.log(`Locations visited from ${startDate.toISOString().slice(0,10)} to ${endDate.toISOString().slice(0,10)}:`);
locationsList.forEach(location => {
    console.log(`- ${location.semanticType} (${location.placeLocation}) - Visits: ${location.visits}`);
});

// Save the list to output/recent-locations.json, including the date range
const outputDir = path.join(__dirname, 'output');
if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir);
}
const recentLocationsPath = path.join(outputDir, 'recent-locations.json');
const outputData = {
    dateRange: {
        start: startDate.toISOString().slice(0,10),
        end: endDate.toISOString().slice(0,10)
    },
    locations: locationsList
};
fs.writeFileSync(recentLocationsPath, JSON.stringify(outputData, null, 2), 'utf8');
console.log(`Saved recent locations to ${recentLocationsPath}`);
