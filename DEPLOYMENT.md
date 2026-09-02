# Microsoft 365 Agents Toolkit - Deployment Guide

This guide provides comprehensive instructions for deploying Microsoft 365 agents and applications built with the Microsoft 365 Agents Toolkit.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Deployment Methods](#deployment-methods)
  - [CLI Deployment](#cli-deployment)
  - [VS Code Deployment](#vs-code-deployment)
  - [Visual Studio Deployment](#visual-studio-deployment)
- [Automated Deployment](#automated-deployment)
- [CI/CD Integration](#cicd-integration)
- [Azure Deployment](#azure-deployment)
- [Troubleshooting](#troubleshooting)

## Overview

Microsoft 365 Agents Toolkit supports deployment to various platforms including:
- **Azure App Service** - For web-based applications and bots
- **Azure Functions** - For serverless backend APIs
- **Azure Static Web Apps** - For frontend applications
- **Microsoft Teams** - For Teams apps and agents
- **Microsoft 365** - For Copilot agents and extensions

## Prerequisites

Before deploying, ensure you have:

1. **Node.js** (>= 22.x) or **.NET SDK** (for C# projects)
2. **Microsoft 365 Agents Toolkit CLI** installed:
   ```bash
   npm install -g @microsoft/m365agentstoolkit-cli
   ```
3. **Azure Subscription** (for Azure deployments)
4. **Microsoft 365 Developer Account** (for M365/Teams deployments)
5. **Appropriate permissions** to deploy to target platforms

## Deployment Methods

### CLI Deployment

The Microsoft 365 Agents Toolkit CLI (`atk`) provides commands for the complete deployment lifecycle.

#### Basic Deployment Flow

```bash
# 1. Provision cloud resources
atk provision --env dev

# 2. Deploy application code
atk deploy --env dev

# 3. Publish to Teams/M365 (optional)
atk publish --env dev
```

#### Step-by-Step CLI Deployment

```bash
# Navigate to your project directory
cd your-m365-project

# Install dependencies
npm install  # or pnpm install

# Build the project
npm run build

# Provision Azure resources (first time only)
atk provision --env dev --subscription <your-subscription-id>

# Deploy the application
atk deploy --env dev

# Validate deployment
atk validate --env dev
```

### VS Code Deployment

Using the Microsoft 365 Agents Toolkit extension in VS Code:

1. **Open your project** in VS Code
2. **Open the Teams Toolkit panel** (click the Teams icon in the sidebar)
3. **Sign in** to your Microsoft 365 and Azure accounts
4. **Provision resources**:
   - Click "Provision" in the lifecycle panel
   - Select your Azure subscription and resource group
5. **Deploy**:
   - Click "Deploy" in the lifecycle panel
   - Confirm deployment settings
6. **Publish** (optional):
   - Click "Publish" to make your app available in Teams/M365

### Visual Studio Deployment

For C# projects using Visual Studio:

1. **Open your project** in Visual Studio
2. **Open Teams Toolkit** from the menu
3. **Configure deployment settings**:
   - Right-click project → Teams Toolkit → Prepare Teams App Dependencies
4. **Publish**:
   - Right-click project → Publish
   - Select Azure target (App Service, Functions, etc.)
   - Follow the publish wizard

## Automated Deployment

For automated deployments, you can use the following script:

### Bash Deployment Script

Save this as `deploy.sh`:

```bash
#!/bin/bash
set -e

echo "🚀 Starting Microsoft 365 Agents Toolkit Deployment..."

# Configuration
ENVIRONMENT=${1:-dev}
PROJECT_PATH=${2:-.}

cd "$PROJECT_PATH"

# Step 1: Install dependencies
echo "📦 Installing dependencies..."
if [ -f "package.json" ]; then
    npm install
elif [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
elif [ -f "*.csproj" ]; then
    dotnet restore
fi

# Step 2: Build project
echo "🔨 Building project..."
if [ -f "package.json" ]; then
    npm run build
elif [ -f "*.csproj" ]; then
    dotnet build --configuration Release
fi

# Step 3: Run tests (optional)
echo "🧪 Running tests..."
if [ -f "package.json" ] && grep -q "\"test\"" package.json; then
    npm test || echo "Tests failed, continuing..."
fi

# Step 4: Provision resources (if needed)
echo "☁️  Provisioning cloud resources..."
atk provision --env "$ENVIRONMENT" || echo "Provision skipped or already done"

# Step 5: Deploy application
echo "🚀 Deploying application..."
atk deploy --env "$ENVIRONMENT"

# Step 6: Validate deployment
echo "✅ Validating deployment..."
atk validate --env "$ENVIRONMENT"

echo "✨ Deployment completed successfully!"
echo "Environment: $ENVIRONMENT"
```

Make it executable and run:

```bash
chmod +x deploy.sh
./deploy.sh dev
```

### PowerShell Deployment Script

Save this as `deploy.ps1`:

```powershell
param(
    [string]$Environment = "dev",
    [string]$ProjectPath = "."
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting Microsoft 365 Agents Toolkit Deployment..." -ForegroundColor Green

Set-Location $ProjectPath

# Step 1: Install dependencies
Write-Host "📦 Installing dependencies..." -ForegroundColor Yellow
if (Test-Path "package.json") {
    npm install
} elseif (Test-Path "requirements.txt") {
    pip install -r requirements.txt
} elseif (Test-Path "*.csproj") {
    dotnet restore
}

# Step 2: Build project
Write-Host "🔨 Building project..." -ForegroundColor Yellow
if (Test-Path "package.json") {
    npm run build
} elseif (Test-Path "*.csproj") {
    dotnet build --configuration Release
}

# Step 3: Provision resources
Write-Host "☁️  Provisioning cloud resources..." -ForegroundColor Yellow
try {
    atk provision --env $Environment
} catch {
    Write-Host "Provision skipped or already done" -ForegroundColor Gray
}

# Step 4: Deploy application
Write-Host "🚀 Deploying application..." -ForegroundColor Yellow
atk deploy --env $Environment

# Step 5: Validate deployment
Write-Host "✅ Validating deployment..." -ForegroundColor Yellow
atk validate --env $Environment

Write-Host "✨ Deployment completed successfully!" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Cyan
```

Run with:

```powershell
.\deploy.ps1 -Environment dev
```

## CI/CD Integration

### GitHub Actions

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Azure

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - staging
          - production

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || 'dev' }}
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Build project
        run: npm run build
      
      - name: Install Teams Toolkit CLI
        run: npm install -g @microsoft/m365agentstoolkit-cli
      
      - name: Login to Azure
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Login to Microsoft 365
        run: |
          atk account login azure --service-principal \
            --username ${{ secrets.M365_CLIENT_ID }} \
            --password ${{ secrets.M365_CLIENT_SECRET }} \
            --tenant ${{ secrets.M365_TENANT_ID }}
      
      - name: Provision resources
        run: atk provision --env ${{ github.event.inputs.environment || 'dev' }}
        env:
          AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Deploy application
        run: atk deploy --env ${{ github.event.inputs.environment || 'dev' }}
      
      - name: Validate deployment
        run: atk validate --env ${{ github.event.inputs.environment || 'dev' }}
```

### Azure DevOps

Create `azure-pipelines.yml`:

```yaml
trigger:
  branches:
    include:
      - main
      - develop

variables:
  - name: nodeVersion
    value: '22.x'

stages:
  - stage: Build
    jobs:
      - job: BuildJob
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - task: NodeTool@0
            inputs:
              versionSpec: $(nodeVersion)
            displayName: 'Install Node.js'
          
          - script: npm ci
            displayName: 'Install dependencies'
          
          - script: npm run build
            displayName: 'Build project'
          
          - script: npm test
            displayName: 'Run tests'
            continueOnError: true
          
          - publish: $(System.DefaultWorkingDirectory)
            artifact: drop
            displayName: 'Publish artifact'

  - stage: Deploy
    dependsOn: Build
    condition: succeeded()
    jobs:
      - deployment: DeployJob
        environment: 'production'
        pool:
          vmImage: 'ubuntu-latest'
        strategy:
          runOnce:
            deploy:
              steps:
                - download: current
                  artifact: drop
                
                - task: AzureCLI@2
                  inputs:
                    azureSubscription: 'Azure-Subscription-Connection'
                    scriptType: 'bash'
                    scriptLocation: 'inlineScript'
                    inlineScript: |
                      npm install -g @microsoft/m365agentstoolkit-cli
                      cd $(Pipeline.Workspace)/drop
                      atk provision --env production
                      atk deploy --env production
                  displayName: 'Deploy to Azure'
```

## Azure Deployment

### Deploy to Azure App Service

For bot applications and web apps:

```bash
# Configure Azure App Service deployment
atk config set azureAppService.resourceId /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Web/sites/<app-name>

# Deploy
atk deploy --env production
```

### Deploy to Azure Functions

For serverless APIs:

```bash
# Configure Azure Functions deployment
atk config set azureFunctions.resourceId /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Web/sites/<function-name>

# Deploy
atk deploy --env production
```

### Deploy to Azure Static Web Apps

For frontend applications:

```bash
# Configure Static Web Apps deployment
atk config set staticWebApp.deploymentToken <swa-deployment-token>

# Deploy
atk deploy --env production
```

## Manual Deployment Configuration

### m365agents.yml Configuration

The deployment behavior is controlled by `m365agents.yml` in your project root:

```yaml
version: v1.9

deploy:
  # Install dependencies
  - uses: cli/runNpmCommand
    name: install dependencies
    with:
      args: install
  
  # Build application
  - uses: cli/runNpmCommand
    name: build app
    with:
      args: run build --if-present
  
  # Deploy to Azure App Service
  - uses: azureAppService/zipDeploy
    with:
      artifactFolder: .
      ignoreFile: .webappignore
      resourceId: ${{BOT_AZURE_APP_SERVICE_RESOURCE_ID}}
```

## Environment Variables

Set up environment-specific variables in `env/.env.{environment}`:

```env
# Azure
AZURE_SUBSCRIPTION_ID=your-subscription-id
AZURE_RESOURCE_GROUP_NAME=your-resource-group
BOT_AZURE_APP_SERVICE_RESOURCE_ID=/subscriptions/.../sites/your-app

# Teams App
TEAMS_APP_ID=your-teams-app-id
M365_APP_ID=your-m365-app-id

# Bot
BOT_ID=your-bot-id
BOT_PASSWORD=your-bot-password

# API Keys (use Azure Key Vault in production)
OPENAI_API_KEY=your-openai-key
```

## Deployment Checklist

Before deploying to production:

- [ ] Update environment variables for production
- [ ] Review and test all API endpoints
- [ ] Configure proper authentication and authorization
- [ ] Set up monitoring and logging (Application Insights)
- [ ] Configure scaling policies
- [ ] Test error handling and fallback scenarios
- [ ] Review security settings (firewall, CORS, etc.)
- [ ] Set up backup and disaster recovery
- [ ] Document deployment procedures
- [ ] Configure CI/CD pipelines
- [ ] Test rollback procedures

## Troubleshooting

### Common Issues

**Issue: "Deployment failed - Authentication error"**
```bash
# Solution: Re-authenticate
atk account login azure
atk account login m365
```

**Issue: "Resource provisioning failed"**
```bash
# Solution: Check Azure subscription and permissions
atk validate --env dev
az account show
```

**Issue: "Build failed during deployment"**
```bash
# Solution: Clean and rebuild locally first
rm -rf node_modules dist build
npm install
npm run build
atk deploy --env dev
```

**Issue: "App package validation failed"**
```bash
# Solution: Validate manifest
atk validate manifest --manifest-path ./appPackage/manifest.json
```

### Enable Debug Logging

```bash
# Set environment variable for detailed logs
export TEAMSFX_DEBUG=true
atk deploy --env dev --verbose
```

### View Deployment Logs

```bash
# Azure App Service logs
az webapp log tail --name <app-name> --resource-group <rg-name>

# Azure Functions logs
az functionapp log tail --name <function-name> --resource-group <rg-name>
```

## Best Practices

1. **Use environment-specific configurations** - Keep dev, staging, and production settings separate
2. **Automate deployments** - Use CI/CD pipelines for consistency
3. **Test before deploying** - Run unit and integration tests
4. **Use deployment slots** - For zero-downtime deployments in Azure
5. **Monitor deployments** - Set up Application Insights and alerts
6. **Version control** - Tag releases and maintain changelog
7. **Secure secrets** - Use Azure Key Vault, never commit secrets
8. **Document changes** - Keep deployment documentation updated

## Additional Resources

- [Official Documentation](https://aka.ms/teamsfx-docs)
- [CLI Reference](https://aka.ms/teamsfx-toolkit-cli)
- [Azure Deployment Guide](https://learn.microsoft.com/azure/app-service/)
- [Teams App Deployment](https://learn.microsoft.com/microsoftteams/platform/toolkit/deploy)
- [GitHub Repository](https://github.com/OfficeDev/TeamsFx)

## Support

For issues or questions:
- [Stack Overflow](https://stackoverflow.com/questions/tagged/teams-toolkit)
- [GitHub Issues](https://github.com/OfficeDev/TeamsFx/issues)
- Email: ttkfeedback@microsoft.com
