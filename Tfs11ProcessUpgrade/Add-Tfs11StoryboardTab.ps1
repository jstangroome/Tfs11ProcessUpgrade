function Add-Tfs11StoryboardTab {

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

$WitName = 'User Story'

$x = Export-WorkItemTypeDefinition @PSBoundParameters -WitName $WitName

$IsDirty = $false

$TabGroup = $x.WITD.WORKITEMTYPE.FORM.Layout.TabGroup
$DetailsTab = $TabGroup.Tab | Where-Object { $_.Label -eq 'Details' }
$StoryboardTab = $TabGroup.Tab | Where-Object { $_.Label -eq 'Storyboard' }
if (-not $StoryboardTab) {
    Write-Verbose "Adding 'Storyboard' tab to form layout"
    $StoryboardTab = $x.CreateElement('Tab')
    $StoryboardTab.SetAttribute('Label', 'Storyboard')
    $StoryboardTab.InnerXml = @'
<Control Type="LinksControl"> 
    <LinksControlOptions> 
        <WorkItemLinkFilters FilterType="excludeAll" /> 
        <ExternalLinkFilters FilterType="include"> 
            <Filter LinkType="Storyboard" /> 
        </ExternalLinkFilters> 
        <LinkColumns> 
            <LinkColumn RefName="System.Title" /> 
            <LinkColumn LinkAttribute="System.Links.Comment" /> 
        </LinkColumns> 
    </LinksControlOptions> 
</Control>
'@
    $TabGroup.InsertAfter($StoryboardTab, $DetailsTab) | Out-Null
    $IsDirty = $true
}

if ($IsDirty) {
    Import-WorkItemTypeDefinition @PSBoundParameters -Definition $x
} else {
    Write-Verbose "No changes made to work item type '$WitName' from project '$ProjectName' in collection '$CollectionUri'"
}

}