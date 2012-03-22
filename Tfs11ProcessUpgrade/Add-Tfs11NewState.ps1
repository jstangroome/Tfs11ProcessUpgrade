function Add-Tfs11NewState {

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

foreach ($WitName in ('User Story', 'Task')) {
    $IsDirty = $false

    $x = Export-WorkItemTypeDefinition @PSBoundParameters -WitName $WitName

    $States = $x.WITD.WORKITEMTYPE.WORKFLOW.STATES
    $NewState = $States.STATE | Where-Object { $_.value -eq 'New' }
    if (-not $NewState) {
        Write-Verbose "Adding 'New' state to work item type '$WitName'"
        $NewState = $x.CreateElement('STATE')
        $NewState.SetAttribute('value', 'New')
        $NewState.InnerXml = @'
<FIELDS> 
    <FIELD refname="Microsoft.VSTS.Common.ResolvedDate"> 
        <EMPTY /> 
    </FIELD> 
    <FIELD refname="Microsoft.VSTS.Common.ResolvedBy"> 
        <EMPTY /> 
    </FIELD> 
    <FIELD refname="Microsoft.VSTS.Common.ClosedDate"> 
        <EMPTY /> 
    </FIELD> 
    <FIELD refname="Microsoft.VSTS.Common.ClosedBy"> 
        <EMPTY /> 
    </FIELD> 
    <FIELD refname="Microsoft.VSTS.Common.ActivatedDate"> 
        <EMPTY /> 
    </FIELD> 
    <FIELD refname="Microsoft.VSTS.Common.ActivatedBy"> 
        <EMPTY /> 
    </FIELD> 
</FIELDS> 
'@
        if ($WitName -eq 'Task') {
            $NewState.FIELDS.FIELD |
                Where-Object { $_.refname -like '*.Resolved*' } |
                ForEach-Object {
                    $NewState.FIELDS.RemoveChild($_) | Out-Null
                }
        }
        $States.PrependChild($NewState) | Out-Null

        $IsDirty = $true
    }

    $Transitions = $x.WITD.WORKITEMTYPE.WORKFLOW.TRANSITIONS
    $ToActiveTransition = $Transitions.Transition | Where-Object { $_.from -eq '' -and $_.to -eq 'Active' }
    $ActiveToNewTransition =  $Transitions.Transition | Where-Object { $_.from -eq 'Active' -and $_.to -eq 'New' }
    $NewToActiveTransition =  $Transitions.Transition | Where-Object { $_.from -eq 'New' -and $_.to -eq 'Active' }
    $ToNewTransition =  $Transitions.Transition | Where-Object { $_.from -eq '' -and $_.to -eq 'New' }

    if ($ToActiveTransition) {
        Write-Verbose "Removing '' to 'Active' transition from work item type '$WitName'"
        $Transitions.RemoveChild($ToActiveTransition) | Out-Null
        $IsDirty = $true
    }

    if (-not $ActiveToNewTransition) {
        Write-Verbose "Adding 'Active' to 'New' transition to work item type '$WitName'"
        $T = $x.CreateElement('TRANSITION')
        $T.SetAttribute('from', 'Active')
        $T.SetAttribute('to', 'New')
        $T.InnerXml = @'
<REASONS>  
    <DEFAULTREASON value="Implementation halted" />  
</REASONS> 
'@
        $Transitions.PrependChild($T) | Out-Null
        $IsDirty = $true
    }

    if (-not $NewToActiveTransition) {
        Write-Verbose "Adding 'New' to 'Active' transition to work item type '$WitName'"
        $T = $x.CreateElement('TRANSITION')
        $T.SetAttribute('from', 'New')
        $T.SetAttribute('to', 'Active')
        $T.InnerXml = @'
<REASONS>  
    <DEFAULTREASON value="Implementation started" />  
</REASONS>  
<FIELDS>  
    <FIELD refname="Microsoft.VSTS.Common.ActivatedBy">  
        <COPY from="currentuser" />  
        <VALIDUSER />  
        <REQUIRED />  
    </FIELD>  
    <FIELD refname="Microsoft.VSTS.Common.ActivatedDate">  
        <SERVERDEFAULT from="clock" />  
    </FIELD>  
    <FIELD refname="System.AssignedTo">  
        <DEFAULT from="currentuser" />  
    </FIELD>  
</FIELDS> 
'@
        $Transitions.PrependChild($T) | Out-Null
        $IsDirty = $true
    }

    if (-not $ToNewTransition) {
        Write-Verbose "Adding '' to 'New' transition to work item type '$WitName'"
        $T = $x.CreateElement('TRANSITION')
        $T.SetAttribute('from', '')
        $T.SetAttribute('to', 'New')
        $T.InnerXml = @'
<REASONS>  
    <DEFAULTREASON value="New" />  
</REASONS>  
<FIELDS>  
    <FIELD refname="System.Description">  
        <DEFAULT from="value" value="As a &amp;lt;type of user&amp;gt; I want &amp;lt;some goal&amp;gt; so that &amp;lt;some reason&amp;gt;" />  
    </FIELD>  
</FIELDS>
'@
        $Transitions.PrependChild($T) | Out-Null
        $IsDirty = $true
    }

    if ($IsDirty) {
        Import-WorkItemTypeDefinition @PSBoundParameters -Definition $x
    } else {
        Write-Verbose "No changes made to work item type '$WitName' from project '$ProjectName' in collection '$CollectionUri'"
    }
}

}}