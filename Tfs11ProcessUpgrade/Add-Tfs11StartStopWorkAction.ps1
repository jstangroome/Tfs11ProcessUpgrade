function Add-Tfs11StartStopWorkAction {

[CmdletBinding()]
param (
    [Parameter(Position = 0, Mandatory=$true)]
    [ValidatePattern('^https?://')]
    [string]
    $CollectionUri,

    [Parameter(Position = 1, Mandatory=$true)]
    [string]
    $ProjectName
)

Set-StrictMode -Version Latest

$WitName = 'Task'
$x = Export-WorkItemTypeDefinition @PSBoundParameters -WitName $WitName

$IsDirty = $false

$Transitions = $x.WITD.WORKITEMTYPE.WORKFLOW.TRANSITIONS

$T =  $Transitions.Transition | Where-Object { $_.from -eq 'New' -and $_.to -eq 'Active' }
$Actions = $T.Actions
if (-not $Actions) {
    $Actions = $x.CreateElement('ACTIONS')
    $T.AppendChild($Actions) | Out-Null
}
$WorkAction = $null
if ($Actions.HasChildNodes) {
    $WorkAction = $Actions.ACTION | Where-Object { $_.value -eq 'Microsoft.VSTS.Actions.StartWork' }
}
if (-not $WorkAction) {
    Write-Verbose "Adding action 'StartWork' to work item type '$WitName' from project '$ProjectName' in collection '$CollectionUri'"
    $WorkAction = $x.CreateElement('ACTION')
    $WorkAction.SetAttribute('value', 'Microsoft.VSTS.Actions.StartWork')
    $Actions.AppendChild($WorkAction) | Out-Null
    $IsDirty = $true
}

$T =  $Transitions.Transition | Where-Object { $_.from -eq 'Active' -and $_.to -eq 'New' }
$Actions = $T.Actions
if (-not $Actions) {
    $Actions = $x.CreateElement('ACTIONS')
    $T.AppendChild($Actions) | Out-Null
}
$WorkAction = $null
if ($Actions.HasChildNodes) {
    $WorkAction = $Actions.ACTION | Where-Object { $_.value -eq 'Microsoft.VSTS.Actions.StopWork' }
}
if (-not $WorkAction) {
    Write-Verbose "Adding action 'StopWork' to work item type '$WitName' from project '$ProjectName' in collection '$CollectionUri'"
    $WorkAction = $x.CreateElement('ACTION')
    $WorkAction.SetAttribute('value', 'Microsoft.VSTS.Actions.StopWork')
    $Actions.AppendChild($WorkAction) | Out-Null
    $IsDirty = $true
}

if ($IsDirty) {
    Import-WorkItemTypeDefinition @PSBoundParameters -Definition $x
} else {
    Write-Verbose "No changes made to work item type '$WitName' from project '$ProjectName' in collection '$CollectionUri'"
}

}