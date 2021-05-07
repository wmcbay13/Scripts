#Set Variables

## EMEA
#$srv = "plzfiler01.hpfod.net"          #File Share Server
#$dir = "z:\zeus"                           #Directory of Tenant Files
#$sqlsvr = "zeusemeadbcl01"                 #SQL Server
#$db = "ZeusEMEA"                            #SQL Database with TenantMaster Table


## AMS
$srv = "pszcluster1.hpfod.net"          #File Share Server
$dir = "z:\zeus"                           #Directory of Tenant Files
$sqlsvr = "foddbcluster01"                 #SQL Server
$db = "Zeus"                            #SQL Database with TenantMaster Table


$CSVPath = "C:\Windows\Temp\PurgedFolders.csv"  #Save location of deleted folders list
$TenantExpired = (get-date).AddHours(-1)  #Maximum Age of Purged Tenant
$ProjectExpired = (get-date).AddHours(-1) #Maximum Age of Purged Project
$SpecificTenant = ""                       #Specify a particular Tenant

$counter = 0  #counts old projects
$counter2 = 0 #counts total projects
$counter3 = 0 #counts old tenants
$counter4 = 0 #counts tenants
$TenantList = @()


#Create PS Session to efficiently access filer
$session = new-pssession $srv

#Query Filer for list of all tenant folders
if($SpecificTenant -ne ""){
$str1 = "gci $dir -Directory | ?{$_ -like $SpecificTenant} "
}
else
{
$str1 = "gci $dir -Directory | ?{!(`$_.Attributes -band [IO.FileAttributes]::ReparsePoint)}"
}

[scriptblock]$sb1 = [scriptblock]::Create($str1)
$tenants = Invoke-Command -Session $session -ScriptBlock $sb1

#For each Tenant check SQL if purged. 
$tenants | ?{$_.Name -gt 0 -and $_.Name -lt 9999999} | %{
    $counter4 += 1
    $tenant = $_.Name    
    $qry1 = "SELECT [PurgedDate],[CreatedDate] FROM [$db].[dbo].[TenantMaster] WHERE [TenantID] = $tenant"
    $TenantPurge =  invoke-sqlcmd -query $qry1 -ServerInstance $sqlsvr 
    write-host "Query tenant $tenant purged status .."
    

#If Tenant PurgedDate is not null, remove Tenant Folders, if older than 1 hr
    if($TenantPurge.PurgedDate -ne [System.DBNull]::Value ){
        $counter3 += 1
        $Properties = @{    
            'TenantID'=$tenant;
            'CreatedDate'=$TenantPurge.CreatedDate;
            'PurgedDate'=$TenantPurge.PurgedDate;
            'Project'=$null;
            'Folder'=$($_.Fullname);
            }
        $TenantObject = New-Object PSObject -Prop $Properties
        if($TenantPurge.PurgedDate -lt $TenantExpired ){
            $str4 = "Remove-Item $($_.Fullname) -Force -Recurse"
            [scriptblock]$sb4 = [scriptblock]::Create($str4)
      #      $remove = Invoke-Command -Session $session -ScriptBlock $sb4  
            write-host "projects/expired <$counter2/$counter> tenants/expired <$counter4/$counter3> Tenant<$tenant> Created:Purged<$($TenantPurge.CreatedDate):$($TenantPurge.PurgedDate )> : $str4"
        $TenantList += $TenantObject
        }
    }

#If Tenant is still valid, check Projects
    else {
        $projects = ""
        $str2 = "gci $($_.Fullname) -Directory "
        [scriptblock]$sb2 = [scriptblock]::Create($str2)
        $projects = Invoke-Command -Session $session -ScriptBlock $sb2


    #For each Project, Check if it's been purged from DB, skip any non-numerical folders
        $projects | %{if ($_.Name -lt 9999999 -and $_.Name -gt 0 ){
            $counter2 += 1
            $project = $_.Name  
                $qry = "SELECT [PurgedDate] FROM [$db].[dbo].[ProjectVersion] WHERE [ProjectVersionID] = $project"
                $purge =  invoke-sqlcmd -query $qry -ServerInstance $sqlsvr 
                write-host "Qeury tenant $tenant, project $project purge status .."

    #If PurgedDate is not Null, remove the folders , if older than 1 hour
                if($purge.PurgedDate -ne [System.DBNull]::Value){
                    if($purge.PurgedDate -lt $ProjectExpired ){
                        $counter += 1
                        $Properties = @{    
                            'TenantID'=$tenant;
                            'CreatedDate'=$TenantPurge.CreatedDate;
                            'PurgedDate'=$purge.PurgedDate;
                            'Project'=$project;
                            'Folder'=$($_.Fullname);
                            }
                        $TenantObject = New-Object PSObject -Prop $Properties

                
                        $str3 = "Remove-Item $($_.Fullname) -Force -Recurse"
                        [scriptblock]$sb3 = [scriptblock]::Create($str3)
               #         $remove = Invoke-Command -Session $session -ScriptBlock $sb3
                        $TenantList += $TenantObject
                        write-host "projects/expired <$counter2/$counter> tenants/expired <$counter4/$counter3> Tenant<$tenant> Project <$project> Purged<$($purge.PurgedDate)> : $str3"
                    }
                    else
                    {
                        write-host "projects/expired <$counter2/$counter> tenants/expired <$counter4/$counter3> Tenant<$tenant> Project <$project> Purged<NOT EXPIRED> : $str3"
                    }
                }
            $project = ""
            $purge = ""
            $empty = ""
            $qry = ""
            }
        }
    }
}
write-host "projects/expired <$counter2/$counter> tenants/expired <$counter4/$counter3> Tenant<$tenant>"
Remove-PSSession -Session $session
$TenantList | Select TenantID,CreatedDate,PurgedDate,Project,Folder | Export-Csv -Path $CSVPath -NoTypeInformation
exit
      