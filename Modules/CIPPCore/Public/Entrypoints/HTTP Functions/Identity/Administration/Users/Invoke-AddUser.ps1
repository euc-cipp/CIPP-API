using namespace System.Net

Function Invoke-AddUser {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Identity.User.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = 'AddUser'
    Write-LogMessage -headers $Request.Headers -API $APINAME -message 'Accessed this API' -Sev 'Debug'

    $UserObj = $Request.body

    if ($UserObj.Scheduled.Enabled) {
        $TaskBody = [pscustomobject]@{
            TenantFilter  = $UserObj.tenantfilter
            Name          = "New user creation: $($UserObj.mailNickname)@$($UserObj.PrimDomain.value)"
            Command       = @{
                value = 'New-CIPPUserTask'
                label = 'New-CIPPUserTask'
            }
            Parameters    = [pscustomobject]@{ userobj = $UserObj }
            ScheduledTime = $UserObj.Scheduled.date
            PostExecution = @{
                Webhook = [bool]$Request.Body.PostExecution.Webhook
                Email   = [bool]$Request.Body.PostExecution.Email
                PSA     = [bool]$Request.Body.PostExecution.PSA
            }
        }
        Add-CIPPScheduledTask -Task $TaskBody -hidden $false -DisallowDuplicateName $true
        $body = [pscustomobject] @{
            'Results' = @("Successfully created scheduled task to create user $($UserObj.DisplayName)")
        }
    } else {
        $CreationResults = New-CIPPUserTask -userobj $UserObj -APIName $APINAME -ExecutingUser $request.headers.'x-ms-client-principal'
        $body = [pscustomobject] @{
            'Results'  = $CreationResults.Results
            'Username' = $CreationResults.username
            'Password' = $CreationResults.password
            'CopyFrom' = @{
                'Success' = $CreationResults.CopyFrom.Success
                'Error'   = $CreationResults.CopyFrom.Error
            }
        }

    }
    # Associate values to output bindings by calling 'Push-OutputBinding'.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $Body
        })

}
