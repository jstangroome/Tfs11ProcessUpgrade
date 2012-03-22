[CmdletBinding()]
param (
    [Parameter(Position = 0, Mandatory=$true)]
    [ValidatePattern('^https?://')]
    [string]
    $CollectionUri
)

Set-StrictMode -Version Latest

$PSScriptRoot = $MyInvocation.MyCommand.Path | Split-path

Import-Module -Name $PSScriptRoot\Tfs11ProcessUpgrade

Get-Tfs11TeamProjects -CollectionUri @PSBoundParameters
    Where-Object { $_.ProcessTemplateName -like 'MSF for Agile*' } |
    ForEach-Object {
        Add-Tfs11NewState -CollectionUri $_.CollectionUri -ProjectName $_.ProjectName
        Update-Tfs11CommonProcessConfiguration -CollectionUri $_.CollectionUri -ProjectName $_.ProjectName
        Add-Tfs11RemovedState -CollectionUri $_.CollectionUri -ProjectName $_.ProjectName
        Add-Tfs11StartStopWorkAction  -CollectionUri $_.CollectionUri -ProjectName $_.ProjectName
    }