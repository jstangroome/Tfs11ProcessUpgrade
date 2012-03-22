# Based on steps published at:
# http://blogs.msdn.com/b/buckh/archive/2012/03/05/updating-a-team-project-to-use-new-features-after-upgrading-to-tfs-11-beta.aspx

function Get-WitAdmin {
    $RegPath = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\11.0\'
    if ([IntPtr]::Size -ne 8) { $RegPath = $RegPath -replace 'Wow6432Node', '' }
    $VSInstallDir = (Get-ItemProperty -Path $RegPath).InstallDir

    $WitadminExe = Join-Path -Path $VSInstallDir -ChildPath witadmin.exe
    if (-not (Test-Path -Path $WitadminExe -PathType Leaf)) {
        throw "Witadmin.exe not found at '$WitadminExe'"
    }

    if (([Version](Get-Item -Path $WitAdminExe).VersionInfo.ProductVersion).Major -lt 11) {
        throw "Witadmin.exe version 11 or newer required."
    }

    return $WitAdminExe
}

function Export-WorkItemTypeDefinition {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidatePattern('^https?://')]
        [string]
        $CollectionUri,

        [Parameter(Mandatory=$true)]
        [string]
        $ProjectName,

        [Parameter(Mandatory=$true)]
        [string]
        $WitName
    )

    Write-Verbose "Exporting work item type '$WitName' from project '$ProjectName' in collection '$CollectionUri'"
    $WitAdminExe = Get-WitAdmin
    $WorkingFile = [System.IO.Path]::GetTempFileName()
    try {
        & $WitadminExe exportwitd /collection:$CollectionUri /p:$ProjectName /n:$WitName /f:$WorkingFile | Out-Null
        if (-not $?) {
            throw "Failed to export work item type '$WitName' from project '$ProjectName' in collection '$CollectionUri'"
        }
        return [xml](Get-Content -Path $WorkingFile -Delimiter ([char]0))
    } finally {
        Remove-Item -Path $WorkingFile
    }
}

function Import-WorkItemTypeDefinition {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidatePattern('^https?://')]
        [string]
        $CollectionUri,

        [Parameter(Mandatory=$true)]
        [string]
        $ProjectName,

        [Parameter(Mandatory=$true)]
        [xml]
        $Definition
    )

    $WitName = $Definition.WITD.WORKITEMTYPE.name
    Write-Verbose "Importing work item type '$WitName' from project '$ProjectName' in collection '$CollectionUri'"
    $WitAdminExe = Get-WitAdmin
    $WorkingFile = [System.IO.Path]::GetTempFileName()
    try {
        $Definition.Save($WorkingFile)
        $Result = & $WitadminExe importwitd /collection:$CollectionUri /p:$ProjectName /f:$WorkingFile | Out-Null
        if (-not $?) {
            throw "Failed to import work item type '$WitName' to project '$ProjectName' in collection '$CollectionUri'`n$Result"
        }
    } finally {
        Remove-Item -Path $WorkingFile
    }
}

function Get-Tfs11TeamProject {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidatePattern('^https?://')]
        [string[]]
        $CollectionUri
    )

    begin {
        Add-Type -AssemblyName 'Microsoft.TeamFoundation.Client, Version=11.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a' -ErrorAction Stop
        Add-Type -AssemblyName 'Microsoft.TeamFoundation.WorkItemTracking.Client, Version=11.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a' -ErrorAction Stop

        $Tfs11Types = [AppDomain]::CurrentDomain.GetAssemblies() | 
            Where-Object { $_.FullName -like 'Microsoft.TeamFoundation.*, Version=11.*' } |
            ForEach-Object { $_.GetTypes() }

        $CollectionType = $Tfs11Types | Where-Object { $_.FullName -eq 'Microsoft.TeamFoundation.Client.TfsTeamProjectCollection' } 
        $StructureType = $Tfs11Types | Where-Object { $_.FullName -eq 'Microsoft.TeamFoundation.Server.ICommonStructureService4' } 
        $WorkItemStoreType = $Tfs11Types | Where-Object { $_.FullName -eq 'Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore' } 
    }

    process {
        foreach ($Uri in $CollectionUri) {
            $Collection = New-Object -TypeName $CollectionType.AssemblyQualifiedName -ArgumentList $Uri
            $Collection.EnsureAuthenticated()
            $Structure = $Collection.GetService($StructureType)
            $WorkItemStore = $Collection.GetService($WorkItemStoreType)
            foreach ($Project in $Structure.ListProjects()) {
                <#
                $Properties = $null
                $Structure.GetProjectProperties($Project.Uri, [ref]$null, [ref]$null, [ref]$null, [ref]$Properties)
                Write-Debug ($Properties | Format-List | Out-String)
                $TemplateName = $Properties | Where-Object { $_.Name -eq 'Process Template' } | Select-Object -First 1 -ExpandProperty Value
                #>
                $TemplateName = $Structure.GetProjectProperty($Project.Uri, 'Process Template').Value
                if (-not $TemplateName) {
                    # guess
                    $WITs = $WorkItemStore.Projects[$Project.Name].WorkItemTypes
                    if ($WITs.Contains('Sprint Backlog Task')) {
                        $TemplateName = 'Scrum for Team System v3.0.4190.00'
                    } elseif ($WITs.Contains('Product Backlog Item')) {
                        $TemplateName = 'Microsoft Visual Studio Scrum 1.0'
                    } elseif ($WITs.Contains('User Story')) {
                        $TemplateName = 'MSF for Agile Software Development v5.0'
                    } elseif ($WITs.Contains('Change Request')) {
                        $TemplateName = 'MSF for CMMI Process Improvement v5.0'
                    }
                }

                New-Object -TypeName PSObject -Property @{
                    CollectionUri = $Uri
                    ProjectName = $Project.Name
                    ProcessTemplateName = $TemplateName
                }
            }
        }
    }
    
}
 
. $PSScriptRoot\Add-Tfs11NewState.ps1
. $PSScriptRoot\Update-Tfs11CommonProcessConfig.ps1
. $PSScriptRoot\Add-Tfs11RemovedState.ps1
. $PSScriptRoot\Add-Tfs11StartStopWorkAction.ps1
. $PSScriptRoot\Add-Tfs11StoryboardTab.ps1

Export-ModuleMember -Function *-Tfs11*