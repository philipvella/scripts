const fs = require('fs');
const path = require('path');
const axios = require('axios');

const cacheDir = path.join(__dirname, 'output');
const cacheFile = path.join(cacheDir, 'country-cache.json');
let countryCache = {};
if (fs.existsSync(cacheFile)) {
    try {
        countryCache = JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
    } catch (e) {
        countryCache = {};
    }
}

const locationHistoryPath = path.join(__dirname, '../private/location-history.json');
const locationHistory = JSON.parse(fs.readFileSync(locationHistoryPath, 'utf8'));

// Function to get country name from latitude and longitude using OpenCage Geocoding API with cache
async function getCountryName(lat, lon) {
    const key = `${lat},${lon}`;
    if (countryCache[key]) {
        console.log(`CACHE: Using cached country for coordinates: ${lat}, ${lon}`);
        return countryCache[key];
    }
    console.log(`FETCH: Fetching country for coordinates: ${lat}, ${lon}`);
    const apiKey = process.env.OPENCAGE_API_KEY; // Get API key from environment variable
    if (!apiKey) {
        console.error('OpenCage API key not found in environment. Please set OPENCAGE_API_KEY in your .zshrc and reload your shell.');
        return 'Unknown';
    }
    const url = `https://api.opencagedata.com/geocode/v1/json?q=${lat}+${lon}&key=${apiKey}`;
    try {
        const response = await axios.get(url);
        const results = response.data.results;
        if (results.length > 0) {
            const components = results[0].components;
            const country = components.country || 'Unknown';
            countryCache[key] = country;
            // Ensure cache directory exists
            if (!fs.existsSync(cacheDir)) fs.mkdirSync(cacheDir);
            fs.writeFileSync(cacheFile, JSON.stringify(countryCache, null, 2));
            return country;
        }
        return 'Unknown';
    } catch (error) {
        console.error('Error fetching country name:', error);
        return 'Unknown';
    }
}

async function addCountryNames() {
    const recentLocationsPath = path.join(__dirname, 'output', 'recent-locations.json');
    if (!fs.existsSync(recentLocationsPath)) {
        console.error('recent-locations.json file does not exist.');
        return;
    }

    const recentLocationsRaw = JSON.parse(fs.readFileSync(recentLocationsPath, 'utf8'));
    let dateRange, recentLocations;
    if (Array.isArray(recentLocationsRaw)) {
        // Backward compatibility: no dateRange
        dateRange = null;
        recentLocations = recentLocationsRaw;
    } else {
        dateRange = recentLocationsRaw.dateRange;
        recentLocations = recentLocationsRaw.locations;
    }

    // For each location, add country and keep the dates visited
    const countryLocations = {};
    for (const location of recentLocations) {
        let country = 'Unknown';
        if (location.placeLocation) {
            const [lat, lon] = location.placeLocation.replace('geo:', '').split(',').map(Number);
            country = await getCountryName(lat, lon);
        }
        // Use country and placeLocation for uniqueness
        const key = `${country}|${location.placeLocation}`;
        if (!countryLocations[key]) {
            countryLocations[key] = {
                placeLocation: location.placeLocation,
                semanticType: location.semanticType,
                country,
                visits: 0,
                dates: []
            };
        }
        countryLocations[key].visits += 1;
        if (location.dates && Array.isArray(location.dates)) {
            countryLocations[key].dates.push(...location.dates);
        } else if (location.date) {
            countryLocations[key].dates.push(location.date);
        }
    }

    // Save the updated list with country names and visit dates to output/recent-locations-with-countries.json
    const outputWithCountriesPath = path.join(__dirname, 'output', 'recent-locations-with-countries.json');
    const outputData = dateRange ? { dateRange, locations: Object.values(countryLocations) } : Object.values(countryLocations);
    fs.writeFileSync(outputWithCountriesPath, JSON.stringify(outputData, null, 2));
    console.log('Updated locations with country names and visit dates saved to recent-locations-with-countries.json');
}

addCountryNames();