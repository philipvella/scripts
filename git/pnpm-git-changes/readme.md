# pnpm-git-changes

# Description

A cli tool which asks you questions to eventually get a list of jira tickets that are related to the changes you have made in your git branch. It checks for all the changes done between the two git commits in the UAT and PROD environments. 

In the DOM there is a meta tag called 'git-commit' which contains the git commit hash of the deployed code, this tool uses that to check for the changes between the two environments.

What it does is compares the two git commits and then checks for the jira tickets that are related to those changes, it then outputs a list of jira tickets that are related to the changes you have made in your git branch. It uses pnpm commands to see which changes actually effect the application and which don't, so it can filter out the irrelevant changes and only show you the relevant ones.

To get the JIRA IDs it uses the commit messages which have a format of 2 to 10 characters followed by a dash and then a number, for example: "PROJ-1234". It then checks against the JIRA API to get the details of the ticket and outputs it in a nice format.

Make sure that the changes are related to the app or to any of the dependencies of the app, otherwise it will not show up in the output.

If no changes are found, it will output "No changes found between the two environments".

When the user provides details we need to save them to the .env file so that the next time the user runs the tool, it can fetch the details from the .env file and use them without asking the user again. The user should also have the option to update the details if they want to. Like this we can avoid asking the user for the same details every time they run the tool.

### Jira API

If you provide Jira credentials, the tool will fetch ticket details (summary + status) from Jira Cloud and include them in the output.

You can provide these either via prompts/flags or environment variables:

- ATLASSIAN_EMAIL 
- ATLASSIAN_API_TOKEN 
- ATLASSIAN_BASE_URL

### OpenAi API

If you provide OpenAI credentials, the tool will use the OpenAI API to generate a summary of the changes based on the commit messages and the JIRA ticket details. This can help you understand the overall impact of the changes without having to read through all the commit messages.

You can provide these either via prompts/flags or environment variables:

- OPENAI_API_KEY

## What is asks for

1. Production url
2. UAT url
3. Repo local path
4. Application local path (inside the repo)
5. Ask for JIRA ()
5. Branch name (defaults to the latest 'origin/master' branch)
6. Jira base url
7. (Optional) Jira email + Jira API token (to fetch ticket details)


## Nice to have

1. Ability to get all the changes, ignore the *lock* files and then check against openai to also add a description of the change, so you can have a better understanding of what the change is about and not just the jira ticket number.
