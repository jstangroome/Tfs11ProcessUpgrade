function Add-Tfs11RemovedState {

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

foreach ($WitName in ('User Story', 'Task')) {
    $IsDirty = $false

    $x = Export-WorkItemTypeDefinition @PSBoundParameters -WitName $WitName

    $States = $x.WITD.WORKITEMTYPE.WORKFLOW.STATES
    $RemovedState = $States.STATE | Where-Object { $_.value -eq 'Removed' }
    if (-not $RemovedState) {
        Write-Verbose "Adding 'Removed' state to work item type '$WitName'"
        $RemovedState = $x.CreateElement('STATE')
        $RemovedState.SetAttribute('value', 'Removed')
        $States.AppendChild($RemovedState) | Out-Null

        $IsDirty = $true
    }

    $Transitions = $x.WITD.WORKITEMTYPE.WORKFLOW.TRANSITIONS
    $NewToRemovedTransition =  $Transitions.Transition | Where-Object { $_.from -eq 'New' -and $_.to -eq 'Removed' }
    $RemovedToNewTransition =  $Transitions.Transition | Where-Object { $_.from -eq 'Removed' -and $_.to -eq 'New' }

    if (-not $NewToRemovedTransition) {
        Write-Verbose "Adding 'New' to 'Removed' transition to work item type '$WitName'"
        $T = $x.CreateElement('TRANSITION')
        $T.SetAttribute('from', 'New')
        $T.SetAttribute('to', 'Removed')
        $T.InnerXml = @'
<REASONS>  
    <DEFAULTREASON value="Removed from the backlog" />  
</REASONS>  
'@
        $Transitions.AppendChild($T) | Out-Null
        $IsDirty = $true
    }

    if (-not $RemovedToNewTransition) {
        Write-Verbose "Adding 'Removed' to 'New' transition to work item type '$WitName'"
        $T = $x.CreateElement('TRANSITION')
        $T.SetAttribute('from', 'Removed')
        $T.SetAttribute('to', 'New')
        $T.InnerXml = @'
<REASONS>  
    <DEFAULTREASON value="Reconsidering the User Story" />  
</REASONS> 
'@
        $Transitions.AppendChild($T) | Out-Null
        $IsDirty = $true
    }

    if ($IsDirty) {
        Import-WorkItemTypeDefinition @PSBoundParameters -Definition $x
    } else {
        Write-Verbose "No changes made to work item type '$WitName' from project '$ProjectName' in collection '$CollectionUri'"
    }
}

}