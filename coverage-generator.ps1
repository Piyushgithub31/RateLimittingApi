#Requires -Version 5.1

# Parameters
param(
    [switch]$OpenReport = $true,
    [string]$SearchPath = (Get-Location),
    [string]$OutputDir = "Reports"
)

# Function to check if dotnet CLI is available
function Test-DotnetInstalled {
    try {
        $dotnetVersion = dotnet --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "? .NET SDK found: $dotnetVersion"
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
    try {
        $rgVersion = reportgenerator --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "? ReportGenerator found: $rgVersion"
            return $true
        }
    }
    catch {
        return $false
    }
    return $false
}

# Function to install reportgenerator globally
function Install-ReportGenerator {
    Write-Host "Installing ReportGenerator globally..."
    try {
        dotnet tool install -g dotnet-reportgenerator-globaltool
        if ($LASTEXITCODE -eq 0) {
            Write-Host "? ReportGenerator installed successfully"
            return $true
        }
    }
    catch {
        Write-Error "Failed to install ReportGenerator: $_"
        return $false
    }
    return $false
}

# Check and install prerequisites
Write-Host "Checking prerequisites..."
Write-Host ""

if (-not (Test-DotnetInstalled)) {
    Write-Error "? .NET SDK is not installed. Please install .NET 8 SDK from https://dotnet.microsoft.com/download"
    exit 1
}

if (-not (Test-ReportGeneratorInstalled)) {
    Write-Host "? ReportGenerator is not installed."
    
    # Attempt to install ReportGenerator
    if (-not (Install-ReportGenerator)) {
        Write-Error "Could not install ReportGenerator. Please install it manually using: dotnet tool install -g dotnet-reportgenerator-globaltool"
        exit 1
    }
}

Write-Host "? All prerequisites are available"
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
    Write-Host "? Tools restored"
}
catch {
    Write-Warning "Warning: Could not restore tools: $_"
}

try {
    Write-Host "Adding coverlet.collector package..."
    dotnet add $testProject package coverlet.collector 2>&1 | Out-Null
    Write-Host "? coverlet.collector package added"
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
    Write-Error "? Could not find coverage.cobertura.xml file paths in dotnet test output."
    Write-Host "Test output:"
    Write-Host $testOutput
    exit 1
}

Write-Host "? Coverage data collected"

Write-Host "Generating HTML report in $OutputDir..."
try {
    reportgenerator "-reports:$coverageReports" "-targetdir:$OutputDir" "-reporttypes:Html" 2>&1 | Out-Null
    Write-Host "? HTML report generated successfully"
}
catch {
    Write-Error "? Failed to generate report: $_"
    exit 1
}

Write-Host ""
Write-Host "? Code coverage report generated successfully!"
Write-Host ""

# Open the report in the default browser
if ($OpenReport) {
    $reportIndex = Join-Path -Path (Get-Location) -ChildPath "$OutputDir/index.htm"
    Write-Host "Opening report: $reportIndex"
    try {
        start $reportIndex
        Write-Host "? Report opened in default browser"
    }
    catch {
        Write-Warning "? Could not automatically open report. Please open manually: $reportIndex"
    }
}
