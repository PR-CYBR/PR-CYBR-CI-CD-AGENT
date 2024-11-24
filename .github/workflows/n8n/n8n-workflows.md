# N8N Workflow Overview

**Workflow 1**:

```markdown
Complete Workflow Overview

1.	Trigger on Push to Main Branch:
	•	Configure the workflow to trigger on push events to the main branch.
2.	Use Ubuntu-latest Environment:
	•	Specify ubuntu-latest for the GitHub Actions runner environment.
3.	Pull and Run n8n Docker Container:
	•	Use Docker commands to pull the n8n Docker image and start a container.
4.	Checkout the Repository:
	•	Use the actions/checkout action to clone the repository.
5.	Load Authentication Credentials:
	•	Mount the credentials directory (.github/workflows/n8n/credentials/) into the Docker container.
6.	Load n8n Workflows:
	•	Mount the workflows directory (.github/workflows/n8n/workflows/) into the Docker container.
7.	Open a New Pull Request:
	•	Trigger another GitHub Actions workflow to create a pull request.
8.	Execute the n8n Workflows:
	•	Ensure n8n processes the workflows for notifications to Slack and Discord.
```