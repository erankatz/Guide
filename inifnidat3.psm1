
function SetIboxVolNameById {
    param(
        $iBoxCred,
        $filer,
		$volId,
		$newName
    )
	SetIboxObjById -iBoxCred $iBoxCred -filer $filer -objId $volId -newName $newName -objType "volumes"
}


function SetIboxCgNameById {
    param(
        $iBoxCred,
        $filer,
		$volId,
		$newName
    )
	SetIboxObjById -iBoxCred $iBoxCred -filer $filer -objId $volId -newName $newName -objType "cgs"
}



function GetIboxCG {
	param(
	    $iBoxCred,
        $filer,
		$CG_Name
	)
	GetIboxObjByName -iBoxCred $iBoxCred -filer $filer -objType "cgs" -name $CG_Name
}
	


function SetIboxCgName {
    param(
        $iBoxCred,
        $filer,
		$volId,
		$newName
    )
	GetIboxObjById -iBoxCred $iBoxCred -filer $filer -objId $volId -newName $newName
}

function SetIboxVolName {
    param(
        $iBoxCred,
        $filer,
		$oldName,
		$newName
    )
	$volume = GetIboxVol -iBoxCred $iboxCred -filer $filer -vol_Name $oldName
	SetIboxVolNameById -iBoxCred $iboxCred -filer $filer -newName $newName -volId $volume.id
}

function GetIboxReplication
{
param(
	$filer,
	$iBoxCred
)
	try {
		$Page =1
		$NumberOfPages = 1
		$Replications = @()
		Do { #Getting All Pages from iBoxes
			$url = 'https://' + $filer +':443/api/rest/replicas?role=SOURCE&page_size=50&page=' +$Page.ToString()
			if ($PSVersionTable.PSEdition -eq "Desktop")
			{
				$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -ErrorAction Stop
			} else {
				$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -SkipCertificateCheck:$true -ErrorAction Stop
			}
			if ($Result.StatusCode -eq 200) #Checking if Get Request getting 200 OK CODE
			{
				$ReplicationsJson = ConvertFrom-Json $Result.Content
				$NumberOfPages = $ReplicationsJson.metadata.pages_total
				$ReplicationsJson.result | %{convertIboxReplication -Replication $_}
				$Replications +=$ReplicationsJson.result
			}
			$Page +=1
		} While ($Page -le $NumberOfPages) #Checking if this is the last page
		$url = 'https://' + $filer +':443/api/rest/volumes?type=eq:master&sort=name&page_size=50&page=1'
		$import = $true
		return $Replications
	} catch {
		$import = $false
		return $null
	}
}

function GetIboxOverview
{
param(
	$filer,
	$iBoxCred
)
	$OverviewJson =$null
	$Page = 1
	try {
			$url = 'https://' + $filer +':443/api/rest/gui/overview?sort=timestamp&page_size=50&page=' +$Page.ToString()
			if ($PSVersionTable.PSEdition -eq "Desktop")
			{
				$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -ErrorAction Stop
			} else {
				$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -SkipCertificateCheck:$true -ErrorAction Stop
			}
			if ($Result.StatusCode -eq 200) #Checking if Get Request getting 200 OK CODE
			{
				$OverviewJson = ConvertFrom-Json $Result.Content
			}
			$Page +=1
		$import = $true
		return $OverviewJson
	} catch {
		$import = $false
		return $null
	}
}


function NewIboxDatasetSnap {
    param(
		$filer,
		$iBoxCred,
		$fileSystem=$false,
        $DatasetName,
        $snapName
    )
	$parent_id =   (GetIboxVol -iBoxCred $iBoxCred -filer $filer -Fs $fileSystem -recursive:$false -vol_name $DatasetName).id
	$name = $snapName
	$body =   $body =  @{parent_id= $parent_id ;name=$name} | ConvertTo-Json
	if ($fileSystem -eq $false)
	{
		$url = 'https://' + $filer + '/api/rest/volumes'
	} else {
		$url = 'https://' + $filer + '/api/rest/filesystems'
	}
	
	if ($PSVersionTable.PSEdition -eq "Desktop")
	{
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -Method POST -Body $body -ContentType "application/json"
	} else {
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -SkipCertificateCheck:$true -Method POST -Body $body -ContentType "application/json"
	}
	if ($Result.StatusCode -eq 200) #Checking if Get Request getting 200 OK CODE
	{
		$Json = ConvertFrom-Json $Result.Content
		$IboxResult = $Json.result
		if (($IboxResult -ne $null) -and ($Json.result.Length -gt 0))
		{
			return $IboxResult
		} elseif ($Json.metadata.number_of_objects -eq "0"){
			return $null
		}
	}
}


function GetIboxObjByID {
		param(
		$filer,
		$iBoxCred,
		$type,
		$Id
	)
	try {
		$url = 'https://' + $filer +':443/api/rest/' + $type + "?" + "id=" +$id.ToString()
		if ($PSVersionTable.PSEdition -eq "Desktop")
		{
			$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -ErrorAction Stop
		} else {
			$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -SkipCertificateCheck:$true -ErrorAction Stop
		}
		if ($Result.StatusCode -eq 200) #Checking if Get Request getting 200 OK CODE
		{
			return (ConvertFrom-Json $Result.Content).result
		}
	} catch {
		$import = $false
		return $null
	}
}

function GetIboxHostById {
	param(
		$filer,
		$iBoxCred,
		$HostId
	)
	try {
		$url = 'https://' + $filer +':443/api/rest/hosts' + "/" + $HostId.ToString()
		if ($PSVersionTable.PSEdition -eq "Desktop")
		{
			$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -ErrorAction Stop
		} else {
			$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -SkipCertificateCheck:$true -ErrorAction Stop
		}
		if ($Result.StatusCode -eq 200) #Checking if Get Request getting 200 OK CODE
		{
			return (ConvertFrom-Json $Result.Content).result
		}
	} catch {
		$import = $false
		return $null
	}
}

function GetIboxHost {
	param(
		$filer,
		$iBoxCred,
		$HostName
	)
	try {
		$url = 'https://' + $filer +':443/api/rest/hosts'
		if ($PSVersionTable.PSEdition -eq "Desktop")
		{
			$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -ErrorAction Stop
		} else {
			$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -SkipCertificateCheck:$true -ErrorAction Stop
		}
		if ($Result.StatusCode -eq 200) #Checking if Get Request getting 200 OK CODE
		{
			$HostsJson = ConvertFrom-Json $Result.Content
			$Hosts =$HostsJson.result
		}
		$import = $true
		if ($HostName -eq $null)
		{
			return $Hosts
		} else {
			$HostObj = $Hosts | where {$_.name -eq $HostName}
			if ($HostObj -eq $null)
			{
				Write-Error ("Host " + $HostName  +" Not Found")
			} else {
				return (GetIboxHostById -filer $filer -iBoxCred $iboxCred -HostId $HostObj.id)
			}
		}
	} catch {
		$import = $false
		return $null
	}
}


function GetIboxClusterById {
	param(
		$filer,
		$iBoxCred,
		$ClusterId
	)
	try {
		$url = 'https://' + $filer +':443/api/rest/clusters' + "/" + $ClusterId.ToString()
		if ($PSVersionTable.PSEdition -eq "Desktop")
		{
			$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -ErrorAction Stop
		} else {
			$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -SkipCertificateCheck:$true -ErrorAction Stop
		}
		if ($Result.StatusCode -eq 200) #Checking if Get Request getting 200 OK CODE
		{
			return (ConvertFrom-Json $Result.Content).result
		}
	} catch {
		$import = $false
		return $null
	}
}

function GetIboxCluster {
	param(
		$filer,
		$iBoxCred,
		$ClusterName
	)
	try {
		$url = 'https://' + $filer +':443/api/rest/clusters'
		if ($PSVersionTable.PSEdition -eq "Desktop")
		{
			$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -ErrorAction Stop
		} else {
			$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -SkipCertificateCheck:$true -ErrorAction Stop
		}
		if ($Result.StatusCode -eq 200) #Checking if Get Request getting 200 OK CODE
		{
			$ClustersJson = ConvertFrom-Json $Result.Content
			$Clusters =$ClustersJson.result
		}
		$import = $true
		if ($ClusterName -eq $null)
		{
			return $Clusters
		} else {
			$ClusterObj = $Clusters | where {$_.name -eq $ClusterName}
			if ($ClusterObj -eq $null)
			{
				Write-Error ("Host " + $ClusterName  +" Not Found")
			} else {
				return (GetIboxClusterById -filer $filer -iBoxCred $iboxCred -ClusterId $ClusterObj.id)
			}
		}
	} catch {
		$import = $false
		return $null
	}
}


function NewIboxDatastoreSnap {
    param(
		$filer,
		$iBoxCred,
		[Parameter(
        ParameterSetName='VMwareDatastore',
        Mandatory=$true,
        Position=0,
        HelpMessage="Datastore VMware type item",
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [Alias("DS")] #attribute must appear once 
        [ValidateNotNullOrEmpty()] 
        [VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.VmfsDatastoreImpl]$Datastore,
        $snapName
    )
	$obj = "" | Select CreateDate,SnapName,Datastore,ParentVolumeName,Status,Result
	$DiskName = $Datastore.ExtensionData.Info.Vmfs.Extent.DiskName
	write-host ("Datastore Name: " + $Datastore.Name); 	$obj.Datastore = $Datastore.Name
	write-host ("Datastore Identifier: " + $DiskName);
	$obj.Datastore = $Datastore.Name
	if ($Datastore -and $DiskName.StartsWith("naa.6742b0f"))
	{
		$Dataset = GetIboxDatasetBySerial -iBoxCred $iBoxCred -filer $filer -DatasetType "volumes" -serial $DiskName.TrimStart("naa.6")
		write-host ("Volume ibox name: " + $Dataset.name) ;	$obj.ParentVolumeName = $Dataset.Name
		write-host ("Volume ibox id: " + $Dataset.id.ToString())
		$obj.SnapName = ($Dataset.id.ToString() + "." + $snapName)
		$obj.Result = NewIboxDatasetSnap -iBoxCred $iBoxCred -filer $filer -fileSystem $false -DatasetName $Dataset.name -snapName $obj.SnapName
		$obj.CreateDate = (get-date)
		$IboxSnap = (GetIboxObjByName -iBoxCred $iBoxCred -filer $filer -objType "volumes" -name $obj.SnapName)
		if ($IboxSnap)
		{
			$obj.Status = "Suceess"
		} else {
			$obj.Status = "Failed"
		}
		$obj
	} else {
		write-error "Not Infinidat Datastore"
	}
}

function GetIboxDatastoreSnap {
	 param(
		$filer,
		$iBoxCred,
		[Parameter(
        ParameterSetName='VMwareDatastore',
        Mandatory=$false,
        Position=0,
        HelpMessage="Datastore VMware type item",
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
        [Alias("DS")] #attribute must appear once 
        [ValidateNotNullOrEmpty()] 
        [VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.VmfsDatastoreImpl]$Datastore,
        [String]$snapName
    )
	$Obj = "" | select Name,ParentName,ParentDatastore,CreateDate
	$Obj.Name = $snapName
	if ($snapName)
	{
		$IboxSnap = GetIboxObjByName -iBoxCred $iBoxCred -filer $filer -objType "volumes" -name $snapName
		$obj.CreateDate = Convert-FromUnixDate -UnixDate $IboxSnap.created_at
		$IboxParentDataset = GetIboxDatasetById -iBoxCred $iBoxCred -filer $filer -DatasetType "volumes" -id $IboxSnap.parent_id
		$obj.ParentName = $IboxParentDataset.name
		$obj.ParentDatastore = Get-Datastore | where {$_.ExtensionData.Info.Vmfs.Extent.DiskName -eq ("naa.6" + $IboxParentDataset.serial)}
		$obj
	} else {
		$DiskName = $Datastore.ExtensionData.Info.Vmfs.Extent.DiskName
		$Dataset = GetIboxDatasetBySerial -iBoxCred $iBoxCred -filer $filer -DatasetType "volumes" -serial $DiskName.TrimStart("naa.6")
		$snaps = GetIboxVolSnaps -iBoxCred $iBoxCred -filer $filer -volId $Dataset.id -Fs $false
		$snaps
	}
}

function UpdateIboxObjAttribute{
	param(
		$filer,
		$iBoxCred,
		$id,
		$objType,
		$data
	)
	$data =  $data |ConvertTo-Json	
	$url = 'https://' + $filer + "/api/rest/" + $objType + "/" + $id.ToString()
	if ($PSVersionTable.PSEdition -eq "Desktop")
	{
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -Method PUT -ContentType "application/json" -body $data
    } else {
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -SkipCertificateCheck:$true -Method PUT -body $data -ContentType "application/json"
	}
    if ($Result.StatusCode -eq 200) #Checking if Get Request getting 200 OK CODE
    {
        $Json = ConvertFrom-Json $Result.Content
		Return $Json.result
        if (($Json -ne $null) -and ($Json.metadata.ready -ne $true))
        {
			write-host "Error $objId"
           return $Json
        }
    }
}

function MapIboxSnap{
	param(
		$filer,
		$iBoxCred,
		$MapObjId,
        $MapobjType,
		$data
    )
	$data =  $data |ConvertTo-Json	
	$url = 'https://' + $filer + "/api/rest/" + $MapobjType + "/" + $MapObjId.ToString() + "/" + "luns"
	if ($PSVersionTable.PSEdition -eq "Desktop")
	{
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -Method POST -ContentType "application/json" -body $data
    } else {
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -SkipCertificateCheck:$true -Method POST -body $data -ContentType "application/json"
	}
    if ($Result.StatusCode -eq 200) #Checking if Get Request getting 200 OK CODE
    {
        $Json = ConvertFrom-Json $Result.Content
		Return $Json.result
        if (($Json -ne $null) -and ($Json.metadata.ready -ne $true))
        {
			write-host "Error $objId"
           return $Json
        }
    }
}

function ExportIboxSnap{
	 param(
		$filer,
		$iBoxCred,
        [String]$snapName,
		$hostName,
		$DataStoreName
    )
	$VMhost = Get-VMHost $hostName
	if ($VMhost)
	{
		$Obj = "" | select snapName,NewSnapName,Result
		$snap = GetIboxDatastoreSnap -filer $filer -iBoxCred $iboxCred -snapName $snapName
		$NewSnapName = $snapName + ".rw"
		NewIboxDatasetSnap -iBoxCred $iBoxCred -filer $filer -fileSystem $false -DatasetName $snapName -snapName $NewSnapName
		sleep 5
		$newSnap = GetIboxObjByName -iBoxCred $iBoxCred -filer $filer -objType "volumes" -name $NewSnapName 
		$newSnap = UpdateIboxObjAttribute -iBoxCred $iBoxCred -filer $filer -objType "volumes" -data @{write_protected = $false} -id $newSnap.id
		$hostIboxObj = GetIboxHost -filer $filer -iBoxCred $iboxCred -HostName $hostName
		$Lun = MapIboxSnap -iBoxCred $iBoxCred -filer $filer -MapobjType "hosts" -data @{volume_id = $newSnap.id} -MapObjId $hostIboxObj.id
		
		$Vmhost | Get-VMHostStorage -RescanAllHba | Out-Null
		$esxcli = $VMhost | get-esxcli -WarningAction SilentlyContinue
		if ($DataStoreName -eq $null)
		{
			$DataStoreName = $snap.ParentName.TrimEnd("-target")
		}
		sleep 5
		$DataStoreSnap = $esxcli.storage.vmfs.snapshot.list() | where {$_.VolumeName -eq $DataStoreName}
		if ($DataStoreSnap)
		{
			$Answer = Read-Host ("Do You Want to Resgniture volume " + $DataStoreName + " (Y/N)")
			if ($Answer -eq "Y")
			{
				$esxcli.storage.vmfs.snapshot.resignature($DataStoreSnap.VolumeName) |out-null
				Get-Datastore -VMHost $Vmhost | where {$_.ExtensionData.Info.Vmfs.Extent.diskName -eq ( "naa.6"  +$newSnap.serial)}
			}
		}
	} else {
		write-error ("VMHost " + $hostName + " Not Found (Vmware)")
	}
}


function RestoreIboxSnap{
	 param(
		$filer,
		$iBoxCred,
        [String]$snapName,
		$ObjType
	)
	$snap = getiboxVol -iBoxCred $iboxCred -filer $filer -vol_name $snapName
	$ParentVol = GetIboxDatasetById -iBoxCred $iboxCred -filer $filer -DatasetType "volumes" -id $snap.parent_id
	$Datastore = Get-Datastore | where {$_.ExtensionData.Info.Vmfs.Extent.DiskName -eq "naa.6"+ $parentVol.serial}
	$MountedCount = ($Datastore.ExtensionData.Host.MountInfo | where {$_.Mounted -eq $true}).count
	if ($MountedCount -eq 0)
	{
		$data =  @{source_id=$snap.id} |ConvertTo-Json	
		$url = 'https://' + $filer + "/api/rest/" + $ObjType + "/" + $ParentVol.id.ToString() +"/restore?approved=true"
		if ($PSVersionTable.PSEdition -eq "Desktop")
		{
			$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -Method POST -ContentType "application/json" -body $data
		} else {
			$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -SkipCertificateCheck:$true -Method POST -body $data -ContentType "application/json"
		}
		if ($Result.StatusCode -eq 200) #Checking if Get Request getting 200 OK CODE
		{
			$Json = ConvertFrom-Json $Result.Content
			if (($Json -ne $null) -and ($Json.error -ne $null))
			{
				write-host "Error $objId"
				return $Json
			}
			Return $Json.result
		}
    } else {
		write-error "Datastore " + $DataStore.Name " is still mounted unmount it first"
	}
}
