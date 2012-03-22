function Update-Tfs11CommonProcessConfiguration {

[CmdletBinding()]
param (
    [Parameter(Position = 0, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
    [ValidatePattern('^https?://')]
    [string]
    $CollectionUri,

    [Parameter(Position = 1, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
    [string]
    $ProjectName
)

process {

Set-StrictMode -Version Latest

$WitadminExe = Get-WitAdmin
$WorkingFile = [System.IO.Path]::GetTempFileName()

Write-Verbose "Exporting common process configuration from project '$ProjectName' in collection '$CollectionUri'"
& $WitadminExe exportcommonprocessconfig /collection:$CollectionUri /p:$ProjectName /f:$WorkingFile | Out-Null
if (-not $?) {
    throw "Failed to export common process configuration from project '$ProjectName' in collection '$CollectionUri'"
}
$x = [xml](Get-Content -Path $WorkingFile)
Remove-Item -Path $WorkingFile

$IsDirty = $false

$ReqWIs = $x.CommonProjectConfiguration.RequirementWorkItems #| Where-Object { $_.category -eq 'Microsoft.RequirementCategory' -and $_.plural -eq 'Stories' }
if ($ReqWIs) {
    $Proposed = $ReqWIs.States.State | Where-Object { $_.type -eq 'Proposed' }
    $InProgress = $ReqWIs.States.State | Where-Object { $_.type -eq 'InProgress' }
    if ($Proposed.GetAttribute('value') -ne 'New') {
        Write-Verbose "Setting RequirementWorkItems 'Proposed' state value to 'New'"
        $Proposed.SetAttribute('value', 'New')
        $IsDirty = $true
    }

    if (-not $InProgress) {
        Write-Verbose "Inserting RequirementWorkItems 'InProgress' state"
        $InProgress = $x.CreateElement('State')
        $InProgress.SetAttribute('type', 'InProgress')
        $ReqWIs.States.InsertAfter($InProgress, $Proposed) | Out-Null
    }

    if ($InProgress.GetAttribute('value') -ne 'Active') {
        Write-Verbose "Setting RequirementWorkItems 'InProgress' state value to 'Active'"
        $InProgress.SetAttribute('value', 'Active')
        $IsDirty = $true
    }
}

$TaskStates = $x.CommonProjectConfiguration.TaskWorkItems.States
$Proposed = $TaskStates.State | Where-Object { $_.type -eq 'Proposed' }
if (-not $Proposed) {
    Write-Verbose "Prepending TaskWorkItems 'Proposed' state"
    $Proposed = $x.CreateElement('State')
    $Proposed.SetAttribute('type', 'Proposed')
    $TaskStates.PrependChild($Proposed) | Out-Null
}

if ($Proposed.GetAttribute('value') -ne 'New') {
    Write-Verbose "Setting TaskWorkItems 'Proposed' state value to 'New'"
    $Proposed.SetAttribute('value', 'New')
    $IsDirty = $true
}

if ($IsDirty) {
    Write-Verbose "Importing common process configuration to project '$ProjectName' in collection '$CollectionUri'"
    $x.Save($WorkingFile)
    $ImportResult = & $WitadminExe importcommonprocessconfig /collection:$CollectionUri /p:$ProjectName /f:$WorkingFile 
    if (-not $?) {
        throw "Failed to import common process configuration to project '$ProjectName' in collection '$CollectionUri'`n$ImportResult"
    }
    Remove-Item -Path $WorkingFile
} else {
    Write-Verbose "No changes made to the common process configuration from project '$ProjectName' in collection '$CollectionUri'"
}


}
}