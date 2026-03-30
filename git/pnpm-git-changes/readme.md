# pnpm-git-changes

# Description

A cli tool which asks you questions to eventually get a list of jira tickets that are related to the changes you have made in your git branch. It checks for all the changes done between the two git commits in the UAT and PROD environments. 

In the DOM there is a meta tag called 'git-commit' which contains the git commit hash of the deployed code, this tool uses that to check for the changes between the two environments.

What it does is compares the two git commits and then checks for the jira tickets that are related to those changes, it then outputs a list of jira tickets that are related to the changes you have made in your git branch. It uses pnpm commands to see which changes actually effect the application and which don't, so it can filter out the irrelevant changes and only show you the relevant ones.



## What is asks for

1. Production url
2. UAT url
3. Repo local path
4. Application local path (inside the repo)
5. Branch name (defaults to the latest 'origin/master' branch)
6. Jira base url


## Nice to have

1. Ability to get all the changes, ignore the *lock* files and then check against openai to also add a description of the change, so you can have a better understanding of what the change is about and not just the jira ticket number.
