#Requires -Version 5.1

# Parameters
param(
    [switch]$OpenReport = $true,
    [string]$SearchPath = (Get-Location),
    [string]$OutputDir = "Reports"
)

# Determine script location (repository root) and normalize paths
$ScriptRoot = $PSScriptRoot

# If caller didn't pass SearchPath, default it to the script directory (repository root)
if (-not $PSBoundParameters.ContainsKey('SearchPath')) {
    $SearchPath = $ScriptRoot
}

# If OutputDir was not provided, default to <scriptroot>\Reports. If it is a relative path, make it relative to the script root.
if (-not $PSBoundParameters.ContainsKey('OutputDir')) {
    $OutputDir = Join-Path -Path $ScriptRoot -ChildPath 'Reports'
}
elseif (-not [System.IO.Path]::IsPathRooted($OutputDir)) {
    $OutputDir = Join-Path -Path $ScriptRoot -ChildPath $OutputDir
}

# Function to check if dotnet CLI is available
function Test-DotnetInstalled {
    try {
        $dotnetVersion = dotnet --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "OK: .NET SDK found: $dotnetVersion"
            return $true
        }
    }
    catch {
        return $false
    }
    return $false
}

# Function to check if reportgenerator is installed
function Test-ReportGeneratorInstalled {
    # First try the command directly
    try {
        $rgVersion = & reportgenerator --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "OK: ReportGenerator found: $rgVersion"
            return $true
        }
    }
    catch {
        # Fall through to check explicit path
    }
    
    # Check if it exists in dotnet tools directory
    $dotnetToolsPath = Join-Path -Path $env:USERPROFILE -ChildPath ".dotnet\tools\reportgenerator.exe"
    if (Test-Path -Path $dotnetToolsPath) {
        Write-Host "OK: ReportGenerator found at: $dotnetToolsPath"
        return $true
    }
    
    return $false
}

# Function to ensure dotnet tools directory is in PATH
function Add-DotnetToolsToPath {
    $dotnetToolsPath = Join-Path -Path $env:USERPROFILE -ChildPath ".dotnet\tools"
    
    if (-not ($env:Path -like "*$dotnetToolsPath*")) {
        Write-Host "Adding .dotnet tools directory to PATH..."
        $env:Path = "$dotnetToolsPath;$env:Path"
    }
}

# Function to install reportgenerator globally
function Install-ReportGenerator {
    Write-Host "Installing ReportGenerator globally..."
    try {
        # Try to install, allowing skip if already installed
        $output = dotnet tool install -g dotnet-reportgenerator-globaltool 2>&1
        
        # Check if installation succeeded or if it's already installed
        if ($LASTEXITCODE -eq 0 -or $output -like "*already installed*") {
            Write-Host "OK: ReportGenerator installed successfully"
            
            # Add dotnet tools directory to PATH
            Add-DotnetToolsToPath
            
            return $true
        }
        else {
            Write-Error "Installation output: $output"
            return $false
        }
    }
    catch {
        Write-Error "Failed to install ReportGenerator: $_"
        return $false
    }
}

# Check and install prerequisites
Write-Host "Checking prerequisites..."
Write-Host ""

# Ensure dotnet tools are in PATH
Add-DotnetToolsToPath

if (-not (Test-DotnetInstalled)) {
    Write-Error "ERROR: .NET SDK is not installed. Please install .NET 8 SDK from https://dotnet.microsoft.com/download"
    exit 1
}

if (-not (Test-ReportGeneratorInstalled)) {
    Write-Host "WARNING: ReportGenerator is not installed."
    
    # Attempt to install ReportGenerator
    if (Install-ReportGenerator) {
        # Verify installation after install and PATH refresh
        if (-not (Test-ReportGeneratorInstalled)) {
            Write-Warning "ReportGenerator was installed but verification failed. Attempting to continue..."
            # Don't exit, let the script try to use the explicit path
        }
    }
    else {
        Write-Error "ERROR: Could not install ReportGenerator. Please install it manually using: dotnet tool install -g dotnet-reportgenerator-globaltool"
        exit 1
    }
}

Write-Host "OK: All prerequisites are available"
Write-Host ""

# Find the test project automatically
Write-Host "Searching for test project in $SearchPath..."
$testProjectPath = Get-ChildItem -Path $SearchPath -Filter "*Tests.csproj" -Recurse | Select-Object -First 1

if (-not $testProjectPath) {
    Write-Error "Could not find a test project (*Tests.csproj) in $SearchPath"
    exit 1
}

$testProject = $testProjectPath.FullName
Write-Host "Found test project: $testProject"

# Create output directory if it doesn't exist
if (-not (Test-Path -Path $OutputDir)) {
    Write-Host "Creating output directory: $OutputDir"
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

Write-Host "Restoring tools and packages..."
try {
    dotnet tool restore 2>&1 | Out-Null
    Write-Host "OK: Tools restored"
}
catch {
    Write-Warning "Warning: Could not restore tools: $_"
}

try {
    Write-Host "Adding coverlet.collector package..."
    dotnet add $testProject package coverlet.collector 2>&1 | Out-Null
    Write-Host "OK: coverlet.collector package added"
}
catch {
    Write-Warning "Warning: coverlet.collector may already be installed or could not be added: $_"
}

Write-Host ""
Write-Host "Running tests and collecting coverage data..."
# Run tests and capture output to find the coverage file path
$testOutput = dotnet test $testProject --collect:"XPlat Code Coverage" --no-build 2>&1

# Extract the path(s) to the generated cobertura.xml file(s)
$coverageReports = @($testOutput | Select-String coverage.cobertura.xml | ForEach-Object { $_.Line.Trim() }) -join ';'

    if (-not $coverageReports) {
    Write-Error "ERROR: Could not find coverage.cobertura.xml file paths in dotnet test output."
    Write-Host "Test output:"
    Write-Host $testOutput
    exit 1
}

Write-Host "OK: Coverage data collected"

Write-Host "Generating HTML report in $OutputDir..."
try {
    # Try to use reportgenerator from PATH first, fall back to explicit path
    $reportGeneratorCmd = "reportgenerator"
    if (-not (Get-Command reportgenerator -ErrorAction SilentlyContinue)) {
        $reportGeneratorCmd = Join-Path -Path $env:USERPROFILE -ChildPath ".dotnet\tools\reportgenerator.exe"
        if (-not (Test-Path -Path $reportGeneratorCmd)) {
            Write-Error "Could not find reportgenerator executable"
            exit 1
        }
    }
    
    & $reportGeneratorCmd "-reports:$coverageReports" "-targetdir:$OutputDir" "-reporttypes:Html" 2>&1 | Out-Null
    Write-Host "OK: HTML report generated successfully"
}
catch {
    Write-Error "Failed to generate report: $_"
    exit 1
}

Write-Host ""
Write-Host "OK: Code coverage report generated successfully!"
Write-Host ""

# Open the report in the default browser
if ($OpenReport) {
    $reportIndex = Join-Path -Path (Get-Location) -ChildPath "$OutputDir/index.htm"
    Write-Host "Opening report: $reportIndex"
    try {
        start $reportIndex
        Write-Host "OK: Report opened in default browser"
    }
    catch {
        Write-Warning "WARNING: Could not automatically open report. Please open manually: $reportIndex"
    }
}
