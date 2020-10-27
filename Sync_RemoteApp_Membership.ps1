workflow Sync_RemoteApp_Membership {
    param ( 
        # Mandatory parameter for the name of the Active Directory Group 
        [parameter(Mandatory=$true)] 
        [string]$AD_Group, 
 
        # Mandatory parameter for the name of the RemoteApp Collection
        [parameter(Mandatory=$true)] 
        [string]$RA_Collection,
        
        # Mandatory parameter for the name of the RemoteApp Collection
        [parameter(Mandatory=$true)] 
        [string]$Mail_Destination
    )
    
    $Cred = Get-AutomationPSCredential -Name 'Azure_Subscription'
    Add-AzureAccount -Credential $Cred
	Add-AzureRmAccount -Credential $Cred
    Select-AzureSubscription -SubscriptionName '<< SUBSCRIPTION NAME >>'
       
    $useradded   = @()
    $userdeleted = @()
      
    
    $id             = Get-AzureRmADGroup -SearchString $AD_Group | Select-Object Id
    $ad_users       = Get-AzureRmADGroupMember -GroupObjectId $id.Id
    
    $remoteapp_users = Get-AzureRemoteAppUser -CollectionName $RA_Collection | Select-Object Name
    

    foreach ($ad_user in $ad_users) {   
        $check = $remoteapp_users.Name -contains $ad_user.UserPrincipalName
    
        if( $check -eq $False) {
            #User needs to be added to the Azure RemoteApp Collection
            Add-AzureRemoteAppUser -CollectionName $RA_Collection -UserUpn $ad_user.UserPrincipalName -Type OrgId
            
            if($? -eq $True) {
                $useradded += $ad_user.UserPrincipalName
            }
        } 
    }
            
    foreach ($remoteapp_user in $remoteapp_users) {
        $check = $ad_users.UserPrincipalName -contains $remoteapp_user.Name
    
        if( $check -eq $False) {
            #User needs to be removed from the Azure RemoteApp Collection
            Remove-AzureRemoteAppUser -CollectionName $RA_Collection -UserUpn $remoteapp_user.Name -Type OrgId
            
            if($? -eq $True) {
                $userdeleted += $remoteapp_user.Name
            }
        }
    }
    
    if ( ($useradded.count -gt 0) -or ($userdeleted.count -gt 0) ) {
        Write-Output "Mail send start"
        
        $MailCred   = "Mail_credentials"  
        $subject    = "Azure RemoteApp Membership" 
        $userid     = '<< EMAIL SENDER ACCOUNT >>'
        $Cred       = Get-AutomationPSCredential -Name $MailCred 
        
        $html = "<table><tr><td colspan='2' style='font-family:Arial; font-weight:bold;font-size:12px;'><b>Users Added:</b><td></tr>"
        foreach ($row in $useradded) { 
            $html += "<tr><td style='font-family:Arial;font-size:11px;'>Username: </td><td style='font-family:Arial;font-size:11px;'>" + $row + "</td></tr>"
        }
        $html += "</table><br />"
        $html += "<table><tr><td colspan='2' style='font-family:Arial; font-weight:bold;font-size:12px;'><b>Users Deleted:</b><td></tr>"
        foreach ($row1 in $userdeleted) { 
            $html += "<tr><td style='font-family:Arial;font-size:11px;'>Username: </td><td style='font-family:Arial;font-size:11px;'>" + $row1 + "</td></tr>"
        }
        $html += "</table><br />"
        $Body       = "<p style='font-family:Arial; font-weight:bold;font-size:11px;'>The following Azure RemoteApp Membership changes are made:</p><br /> " + $html
        
        if ($Cred -eq $null) { 
            Write-Output "Credential entered: $MailCred does not exist in the automation service. Please create one `n"    
        } else { 
            $CredUsername = $Cred.UserName 
            $CredPassword = $Cred.GetNetworkCredential().Password 
         
            Send-MailMessage -To $Mail_Destination -Subject $subject -Body $Body -Port "<< MAILSERVER PORT >>" -SmtpServer '<< MAILSERVER >>' -From $userid -BodyAsHtml -Credential $Cred 
        }
    }   
}