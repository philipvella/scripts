# Scripts Overview

This repository contains utility scripts that automate video processing and sending notifications via Slack. Below is an overview of each script and instructions on how to use them.

## Scripts

### `convert.sh`

**Purpose:** This script is designed to process a video file using `ffmpeg`. It applies a filter to remove duplicate frames (frame decimation) and adjusts the video's timestamps accordingly to maintain its original playback speed.

**Usage:**

```bash
./convert.sh <input_file> <output_file>
```

- `<input_file>`: The path to the video file you want to process.
- `<output_file>`: The path where the processed video will be saved.

**Dependencies:** This script requires `ffmpeg` to be installed on your system. You can install `ffmpeg` via your system's package manager (e.g., `apt` on Ubuntu, `brew` on macOS).

### `slack_pull_request.sh`

**Purpose:** This script automates the process of sending a notification to a Slack channel using a webhook URL. It is particularly useful for notifying team members about a new pull request or any URL-based content.

**Usage:**

```bash
./slack_pull_request.sh <new-url>
```

- `<new-url>`: The URL you want to send as a notification to Slack.

**Dependencies:** No external dependencies are required for this script as it uses `curl`, which is typically pre-installed on most UNIX-based systems.

## Getting Started

To get started with these scripts, clone this repository or download the desired scripts directly. Make sure to grant execution permissions to the scripts using the following command:

```bash
chmod +x convert.sh slack_pull_request.sh
```

Follow the usage guidelines above to run each script according to your needs.

## Contribution

Feel free to fork this repository and submit pull requests to contribute to the development of these scripts. If you encounter any issues or have suggestions for improvements, please submit an issue on this repository.

