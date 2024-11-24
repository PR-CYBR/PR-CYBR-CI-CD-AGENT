<!--
Updates that need to be made:
1. 
-->

# PR-CYBR-CI-CD-AGENT

## Overview

The **PR-CYBR-CI-CD-AGENT** streamlines and automates continuous integration and delivery workflows for the PR-CYBR ecosystem. It enhances the efficiency of the software development lifecycle, ensuring rapid deployment, automated testing, and robust delivery pipelines.

## Key Features

- **Automated Builds**: Ensures consistent and efficient code builds triggered by GitHub events.
- **Testing Pipelines**: Runs unit tests, integration tests, and other validation checks for code quality.
- **Deployment Automation**: Manages automated deployments to designated environments using GitHub Actions.
- **Secure CI/CD Workflows**: Implements security best practices to protect code and secrets in transit.
- **Customizable Pipelines**: Easily extendable to support unique requirements for diverse PR-CYBR agents.

## Getting Started

### Prerequisites

- **Git**: For cloning the repository.
- **Python 3.8+**: Required for running scripts.
- **Docker**: Required for containerization and deployment.
- **Access to GitHub Actions**: For automated workflows.

### Local Setup

To set up the `PR-CYBR-CI-CD-AGENT` locally on your machine:

1. **Clone the Repository**

```bash
git clone https://github.com/PR-CYBR/PR-CYBR-CI-CD-AGENT.git
cd PR-CYBR-CI-CD-AGENT
```

2. **Run Local Setup Script**

```bash
./scripts/local_setup.sh
```
_This script will install necessary dependencies and set up the local environment._

3. **Provision the Agent**

```bash
./scripts/provision_agent.sh
```
_This script configures the agent with default settings for local development._

### Cloud Deployment

To deploy the agent to a cloud environment:

1. **Configure Repository Secrets**

- Navigate to `Settings` > `Secrets and variables` > `Actions` in your GitHub repository.
- Add the required secrets:
     - `CLOUD_API_KEY`
     - `DOCKERHUB_USERNAME`
     - `DOCKERHUB_PASSWORD`
     - Any other cloud-specific credentials.

2. **Deploy Using GitHub Actions**

- The deployment workflow is defined in `.github/workflows/docker-compose.yml`.
- Push changes to the `main` branch to trigger the deployment workflow automatically.

3. **Manual Deployment**

- Use the deployment script for manual deployment:

```bash
./scripts/deploy_agent.sh
```

- Ensure you have Docker and cloud CLI tools installed and configured on your machine.

## Integration

The `PR-CYBR-CI-CD-AGENT` integrates with other PR-CYBR agents to provide seamless continuous integration and delivery processes. It works closely with:

- **PR-CYBR-TESTING-AGENT**: Executes tests during the CI pipeline to ensure code quality.
- **PR-CYBR-SECURITY-AGENT**: Integrates security checks into the CI/CD workflows.
- **PR-CYBR-INFRASTRUCTURE-AGENT**: Automates infrastructure provisioning during deployments.
- **PR-CYBR-MGMT-AGENT**: Coordinates overall workflow management and resource allocation.

## Usage

- **Development**

  - Customize CI/CD pipelines by modifying the configuration files in the `config/` directory.
  - Use the local setup to test CI/CD processes in a controlled environment.

- **Triggering Pipelines**

  - Pipelines can be triggered by events such as code pushes, pull requests, or manual triggers via GitHub Actions.
  - Monitor pipeline executions and logs through the GitHub Actions interface or local logging mechanisms.

## License

This project is licensed under the **MIT License**. See the [`LICENSE`](LICENSE) file for details.

---

For more information, refer to the [GitHub Actions Documentation](https://docs.github.com/en/actions) or contact the PR-CYBR team.
