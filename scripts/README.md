# Scripts Directory

This directory contains utility scripts for the Import-OutlookContact project.

## Scripts

### `Import-CSVWithDuplicateHandling.ps1`

**Main CSV Import Utility**

- Generic CSV import script with intelligent duplicate detection and merging
- Creates folders based on CSV filename (e.g., "ECS.csv" → "ECS" folder)
- Interactive merge options for duplicates
- Comprehensive contact discovery across all folders

**Usage:**

```powershell
pwsh ./scripts/Import-CSVWithDuplicateHandling.ps1 "./csv-files/your-file.csv"
```

### `Setup-Environment.ps1`

**Environment Setup Script**

- Configures the PowerShell environment for the project
- Installs required modules and dependencies
- Sets up authentication prerequisites

**Usage:**

```powershell
pwsh ./scripts/Setup-Environment.ps1
```

### `Test-Authentication.ps1`

**Authentication Testing Script**

- Tests Microsoft Graph authentication
- Validates permissions and connectivity
- Useful for troubleshooting auth issues

**Usage:**

```powershell
pwsh ./scripts/Test-Authentication.ps1
```

### `Test-Prerequisites.ps1`

**Prerequisites Testing Script**

- Validates all system requirements
- Checks PowerShell version, modules, and configuration
- Provides environment readiness report

**Usage:**

```powershell
pwsh ./scripts/Test-Prerequisites.ps1
```

## Usage Examples

### Import a CSV file with interactive duplicate handling:

```powershell
# This will create an "AMI" folder and handle duplicates interactively
pwsh ./scripts/Import-CSVWithDuplicateHandling.ps1 "./csv-files/AMI.csv"
```

### Set up the environment on a new system:

```powershell
# Run this first on any new installation
pwsh ./scripts/Setup-Environment.ps1
pwsh ./scripts/Test-Prerequisites.ps1
pwsh ./scripts/Test-Authentication.ps1
```
