


function ToUnixTime
{
    param (
        $date
    )
    ([DateTimeOffset]$date).ToUniversalTime().ToUnixTimeMilliseconds()
}

function Convert-FromMilliseconds($Milliseconds) {
    (New-TimeSpan -Seconds ($Milliseconds/1000))
}


Function Format-FileSize() {
    Param ([int64]$size,$IsTB)
	if ($IsTB -and ($size -gt 0))
	{
			return (($size/ 1000 /1000 /1000 / 1000).ToString() + " TB")
	}
    If     ($size -gt 1TB) {[string]::Format("{0:0.00} TiB", $size / 1TB)}
    ElseIf ($size -gt 1GB) {[string]::Format("{0:0.00} GiB", $size / 1GB)}
    ElseIf ($size -gt 1MB) {[string]::Format("{0:0.00} MiB", $size / 1MB)}
    ElseIf ($size -gt 1KB) {[string]::Format("{0:0.00} kiB", $size / 1KB)}
    ElseIf ($size -gt 0)   {[string]::Format("{0:0.00} B", $size)}
    Else                   {""}
}

Function Convert-FromUnixDate ($UnixDate) {
   [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddMilliseconds($UnixDate))
}

function checkIboxComponents
{
    param (
      $iBoxCred,
      $filer
    )

    $url = 'https://' + $filer +':443/api/rest/components/'
	if ($PSVersionTable.PSEdition -eq "Desktop")
	{
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url
    } else {
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -SkipCertificateCheck:$true
	}
    if ($Result.StatusCode -eq 200) #Checking if Get Request getting 200 OK CODE
    {
        $Json = ConvertFrom-Json $Result.Content
        $IboxResult = $Json.result
    } else {
        return "Login Error"
    }
    #$ibox2.result.enclosures | where {$_.state -ne "OK"}
    #$ibox2.result.enclosures.power_supplies | where {$_.state -ne "OK"}
    #$ibox2.result.enclosures.drives | where {$_.state -ne "ACTIVE"} 
    #Checking Enclosures
    $Alerts = @()
    foreach ($enc in $IboxResult.enclosures)
    {
       $MSG = "Enclosure ID " + $enc.id
       if ($enc.state -ne "OK") {
           $MSG += ": " + $enc.state_description
           $Alerts += $MSG
       }
       
       #Checking power_supplies
       foreach ($power_supply in $enc.power_supplies)
       {
           $MSG = "Enclosure ID " + $enc.id + ", "
           $MSG += "power supplies ID " + $power_supply.id 
           if ($power_supply.state -ne "OK") {
               $MSG += ": " +$power_supply.state_description
               $Alerts += $MSG
           }
       }
    
       #Checking Drives
       foreach ($Drive in $enc.drives)
       {
           $MSG = "enclosure_index " + $Drive.enclosure_index + ", " + "drive_index " +$Drive.drive_index
           if ($Drive.state -ne "ACTIVE") {
               $MSG += ": " + $Drive.state_description
               $Alerts += $MSG
           }
       }
    }
    
    
    foreach  ($ups in $IboxResult.ups)
    {
        $MSG = "UPS ID " + $ups.id
        if ($enc.state -ne "OK") {
            $MSG += ": " + $ups.state_description
            $Alerts += $MSG
        }
    }
    
    
    #$ibox2.result.patch_panels.frames.ports | where {($_.state -ne "OK") -and ($_.state -ne $null)}
    #foreach  ($frame in $IboxResult.patch_panels.frames)
    #{
    #   foreach ($port in $frame.ports)
    #   {
    #       $MSG = $frame.label + "," + "Frame ID " + $frame.component_id
    #       if (($port.state -ne "OK") -and ($port.state -ne $null)) {
    #          $MSG += ": Port Number " + $port.port_num +" " + $port.state
    #          $Alerts += $MSG
    #       }
    #   }
    #}
    
    #$ibox2.result.pdus
    foreach ($pdu in $IboxResult.pdus)
    {
       if ($pdu.state -ne "OK")
       {
           $MSG = $pdu.id + ":" + $pdu.state
           $Alerts += $MSG
       }
    }
    
    foreach ($node in $IboxResult.Nodes)
    {
       $MSG = $node.Name
       if (($node.state -ne "ACTIVE") -and ($node.'ipmi.state' -ne "OK") -and ($node.'ntp.state' -ne "OK") -and ($node.'bios.state' -ne "OK"))
       {
           $MSG = "ipmi.state or ntp.state or bios.state or state is not OK" 
           $Alerts += $MSG
       }
    
       foreach ($service in $node.services)
       {
           $MSG = $node.Name
           if ($service.state -ne "ACTIVE")
           {
               $MSG += ":" + "service name " + $service.name + " role" + $service.role + " "+ $service.state
               $Alerts += $MSG
           }
       }
    
       foreach ($port in $node.ib_ports)
       {
           $MSG = $node.Name
           if ($port.state -ne "OK")
           {
               $MSG +=  "ib port id " + $port.id + " " + $port.state
               $Alerts += $MSG
           }
       }
    
       foreach ($pg in $node.pgs)
       {
           $MSG = $node.Name
           if ($pg.state -ne "OK")
           {
               $MSG +=  $pg.model + ": " +$pg.state
               $Alerts += $MSG
           }
       }
    
       foreach ($power_supply in $node.power_supplies)
       {
           $MSG = "Node Name " + $node.name + ", "
           $MSG += "power supplies ID " + $power_supply.id 
           if ($power_supply.state -ne "OK") {
               $MSG += ": " +$power_supply.state_description
               $Alerts += $MSG
           }
       }
    
       foreach ($hba in $node.hba)
       {
           $MSG = "Node Name " + $node.name + ", "
           $MSG += "hba ID " + $hba.id 
           if ($power_supply.state -ne "OK") {
               $MSG += ": " +$hba.state
               $Alerts += $MSG
           }
       }
    
       $enc_connectivity_Issue = $node.connectivity_status.enclosures | where {$_ -ne "UP"}
       if ($enc_connectivity_Issue -ne $null)
       {
           $Msg = "connectivity issue " + " from enclosures to node " + $node.name 
           $Alerts += $MSG
       }
    
       
       $pdu_connectivity_Issue = $node.connectivity_status.pdu | where {$_ -ne "UP"}
       if ($pdu_connectivity_Issue -ne $null)
       {
           $Msg = "connectivity issue " + " from pdu to node " + $node.name 
           $Alerts += $MSG
       }
    
       $support = $node.connectivity_status.support_appliances | where {$_ -ne "UP"}
       if ($support -ne $null)
       {
           $Msg = "connectivity issue " + " from support to node " + $node.name 
           $Alerts += $MSG
       }
    
       $bbu_connectivity_Issue = $node.connectivity_status.bbu | where {$_.state -ne "OK"}
       if ($bbu_connectivity_Issue -ne $null)
       {
           $Msg = "connectivity issue " + " from bbu to node " + $node.name 
           $Alerts += $MSG
       }
    
       #Checking Drives
       foreach ($drive in $node.drives)
       {
           $MSG = "Node " + $node.name + ", " + "drive_index " +$Drive.drive_index
           if ($drive.state -ne "OK") {
               $MSG += ": " + $Drive.state_description
               $Alerts += $MSG
           }
       }
    
       foreach ($fc_port in $node.fc_ports)
       {
           $MSG = "Node " + $node.name + ", " + "fc port id" +$fc_port.id
           if ($fc_port.state -ne "OK") {
               $MSG += ": " + $fc_ports.link_state
               $Alerts += $MSG
           }
       }
    
       foreach ($tpm in $node.tpm)
       {
           $MSG = "Node " + $node.name + ", " + "tpm id" +$tpm.id
           if ($fc_port.state -ne "OK") {
               $MSG += ": " + $tpm.state
               $Alerts += $MSG
           }
       }
    
      foreach ($port in $node.eth_ports)
      {
           $MSG = "Node " + $node.name + ", " + "eth port id" +$port.id
           if ($fc_port.state -ne "OK") {
               $MSG += ": " + $tpm.link_state
               $Alerts += $MSG
           }
      }
    }
    if ($alerts.Length -eq 0)
    {
        return "No Errors"
    } else {
        $Alerts
    }
}

function checkIboxEvents
{
    param (
      $iBoxCred,
      $filer,
      $SDate,
      $Level
    )

    $unixTime = ToUnixTime -date $SDate
    $url = 'https://' + $filer +':443/api/rest/events?sort=-timestamp&timestamp=ge:' + $unixTime +'&level=in:' + $Level + '&fields=timestamp,level,code,description&page_size=1000&page=1'
    if ($PSVersionTable.PSEdition -eq "Desktop")
	{
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url
    } else {
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -SkipCertificateCheck:$true
	}
    if ($Result.StatusCode -eq 200) #Checking if Get Request getting 200 OK CODE
    {
        $Json = ConvertFrom-Json $Result.Content
        $IboxResult = $Json.result
        if (($IboxResult -ne $null) -and ($Json.result.Length -gt 0))
        {
            $IboxResult | %{$_.timestamp = Convert-FromUnixDate -UnixDate $_.timestamp}
            $IboxResult | where {($_.code -ne "USER_LOGIN_FAILURE") -and ($_.code -ne "EVENT_FLOOD")} 
        } elseif ($Json.metadata.number_of_objects -eq "0"){
            $obj = "" | Select code,level,description,timestamp
            $obj.code = ""
            $obj.level = $Level
            $obj.description = "No Events Found"
            $obj.timestamp = Get-Date
            @($obj)
        }
    } else {
            $obj = "" | Select code,level,description,timestamp
            $obj.code = "LoginError"
            $obj.level = $Level
            $obj.description = $Result.StatusCode + $Result 
            $obj.timestamp = Get-Date
            @($obj)
    }
}

function convertIboxPool {
param ($pool)
    $pool | Add-Member -Name 'P Pool (TiB)' -MemberType NoteProperty -Value (Format-FileSize -size $pool.physical_capacity)
    $pool | Add-Member -Name 'V Pool (TiB)' -MemberType NoteProperty -Value (Format-FileSize -size $pool.virtual_capacity)
	$pool | Add-Member -Name 'VirtualFree(%)' -MemberType NoteProperty -Value ($pool.free_virtual_space / $pool.virtual_capacity).ToString('P2')
	$pool | Add-Member -Name 'VirtualAllocated(%)' -MemberType NoteProperty -Value (1- ($pool.free_virtual_space / $pool.virtual_capacity)).ToString('P2')
	$pool | Add-Member -Name 'Virtual Free (TiB)' -MemberType NoteProperty -Value (Format-FileSize -size $pool.free_virtual_space)
	$pool | Add-Member -Name 'Virtual Allocated (TiB)' -MemberType NoteProperty -Value (Format-FileSize -size ($pool.virtual_capacity - $pool.free_virtual_space))
	$pool | Add-Member -Name 'PhysicalFree(%)' -MemberType NoteProperty -Value ($pool.free_physical_space / $pool.physical_capacity).ToString('P2')
	$pool | Add-Member -Name 'PhysicalAllocated(%)' -MemberType NoteProperty -Value ($pool.allocated_physical_space / $pool.physical_capacity).ToString('P2')
	$pool | Add-Member -Name 'Physical Free (TiB)' -MemberType NoteProperty -Value (Format-FileSize -size $pool.free_physical_space)
	$pool | Add-Member -Name 'Physical Allocated (TiB)' -MemberType NoteProperty -Value (Format-FileSize -size $pool.allocated_physical_space)
}

function convertIboxReplication {
param ($Replication)
    $Replication | Add-Member -Name RestorePoint -MemberType NoteProperty -Value (convert-FromUnixDate -UnixDate $Replication.restore_point)
    $Replication | Add-Member -Name NextJobStartTime -MemberType NoteProperty -Value (convert-FromUnixDate -UnixDate $Replication.next_job_start_time)
    $Replication | Add-Member -Name SyncInterval -MemberType NoteProperty -Value (Convert-FromMilliseconds -Milliseconds $Replication.sync_interval)
    $Replication | Add-Member -Name RpoValue -MemberType NoteProperty -Value (Convert-FromMilliseconds -Milliseconds $Replication.rpo_value)
    $Replication | Add-Member -Name SyncDuration -MemberType NoteProperty -Value (Convert-FromMilliseconds -Milliseconds $Replication.sync_duration)
}

function convertIboxDDE {
param ($DDE)
    $DDE | Add-Member -Name TotalDiskCapacity -MemberType NoteProperty -Value (Format-FileSize -size $DDE.state.total_disk_capacity -IsTB $true)
    $DDE | Add-Member -Name AvailableDiskCapacity -MemberType NoteProperty -Value (Format-FileSize -size $DDE.state.available_disk_capacity -IsTB $true)
    $DDE | Add-Member -Name UsedDiskCapacity -MemberType NoteProperty -Value (Format-FileSize -size $DDE.state.used_disk_capacity -IsTB $true)
    if ($DDE.state.total_disk_capacity -eq -1)
    {
		$DDE | Add-Member -Name 'UsedDiskCapacity(%)' -MemberType NoteProperty -Value ""
    } else {
		$DDE | Add-Member -Name 'UsedDiskCapacity(%)' -MemberType NoteProperty -Value ($DDE.state.used_disk_capacity / $DDE.state.total_disk_capacity).ToString('P2')
		$DDE | Add-Member -Name 'FreeDiskCapacity(%)' -MemberType NoteProperty -Value ( 1- ($DDE.state.used_disk_capacity / $DDE.state.total_disk_capacity)).ToString('P2')
    }
    $DDE | Add-Member -Name TotalReductionRatio -MemberType NoteProperty -Value ($DDE.state.total_reduction_ratio)
}

function ToString {
    param(
        $int
    )
	if ($int -ne $null)
	{
		$int.ToString()
	} else {
		""
	}
}


function GetIboxVol {
    param(
        $iBoxCred,
        $filer,
        $recursive,
		$Fs=$false,
		$vol_name
    )
	if ($vol_name)
	{
		if ($Fs) {
			return (GetIboxObjByName -iBoxCred $iBoxCred -filer $filer -objType "filesystems" -name $vol_Name)
		} else {
			return (GetIboxObjByName -iBoxCred $iBoxCred -filer $filer -objType "volumes" -name $vol_Name)
		}

	}
	if ($Fs) {
		$url = 'https://' + $filer +':443/api/rest/filesystems?sort=name&type=eq:master&page_size=1000&page=1'
	} else {
		$url = 'https://' + $filer +':443/api/rest/volumes?sort=name&type=eq:master&page_size=1000&page=1'
    }
    if ($PSVersionTable.PSEdition -eq "Desktop")
	{
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url
    } else {
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -SkipCertificateCheck:$true
	}
	
    if ($Result.StatusCode -eq 200) #Checking if Get Request getting 200 OK CODE
    {
        $Json = ConvertFrom-Json $Result.Content
        $IboxResult = $Json.result
        if (($IboxResult -ne $null) -and ($Json.result.Length -gt 0))
        {
            foreach ($vol in $json.result)
            {
                if ($recursive -and ($vol.has_children -eq 'True'))
                {
					$snapsEvery = $null
					$snapsDailyRetention = $null
					$snapsDaily = $null
					$SnapEvery60Min7_24 = $null
					$SnapEvery60Min14_24 = $null
					$SnapsTest = $null
					$SnapsTarget = $null
					
                    $snaps = GetIboxVolSnaps -iBoxCred $iBoxCred -filer $filer -volId $vol.id -Fs $Fs
                    $snapsDaily = $snaps | where {($_.name -match ($vol.id.tostring() + "." + "Daily_Snap_Report_Once_In_Day")) -or ($_.cg_name -match ((ToString -int $vol.cg_id) + "." + "Daily_Snap_Report_Once_In_Day"))}
                    
					$SnapEvery60Min7_24  = $snaps | where {($_.name -match ($vol.id.tostring() + "." + "Every_60__Min_7-24")) -or ($_.cg_name -match ((ToString -int $vol.cg_id) + "." + "Every_60__Min_7-24"))}
					if ($SnapEvery60Min7_24 -eq $null)
					{
						$SnapEvery60Min7_24  = $snaps | where {($_.name -match ($vol.id.tostring() + "." + "Every_60_Min_7-24")) -or ($_.cg_name -match ((ToString -int $vol.cg_id) + "." + "Every_60_Min_7-24"))}
					}
					$SnapEvery60Min14_24  = $snaps | where {($_.name -match ($vol.id.tostring() + "." + "Every_60__Min_14-24")) -or ($_.cg_name -match ((ToString -int $vol.cg_id) + "." + "Every_60__Min_14-24"))}
					$SnapsTest     = $snaps | where {($_.name -match ($vol.id.tostring() + "." + "Test_Once_In-Day_7_Days")) -or ($_.cg_name -match ((ToString -int $vol.cg_id)+ "." + "Test_Once_In-Day_7_Days"))}
					if ($SnapsTest -eq $null) {
						$SnapsTest    = $snaps | where {($_.name -match ($vol.id.tostring() + "." + "Snap_For_test_Vol_3Times_In_a_day")) -or ($_.cg_name -match ((ToString -int $vol.cg_id) + "." + "Snap_For_test_Vol_3Times_In_a_day"))}
					}
					
					$SnapsTarget = $snaps | where {($_.name -match ($vol.id.tostring() + "." + "Daily_Backup_Retention")) -or ($_.cg_name -match ((ToString -int $vol.cg_id)+ "." + "Daily_Backup_Retention"))}
					$SnapsExported = $snaps | where  {$_.mapped -eq "True"}
					
					if ($SnapEvery60Min14_24 -ne $null )
					{
						$vol | Add-Member -MemberType NoteProperty -Name "SnapSched" -Value "PsgEvery60Min_14_Days"
						$snapsEvery = $SnapEvery60Min14_24
					} elseif ($SnapEvery60Min7_24 -ne $null ){
						$vol | Add-Member -MemberType NoteProperty -Name "SnapSched" -Value "Every60Min_7_Days"
						$snapsEvery = $SnapEvery60Min7_24
					} elseif ($SnapsTest -ne $null ){
						$vol | Add-Member -MemberType NoteProperty -Name "SnapSched" -Value "SnapTest"
						$snapsEvery = $SnapsTest
					} elseif ($SnapsTarget -ne $null) {
						$vol | Add-Member -MemberType NoteProperty -Name "SnapSched" -Value "Daily_Backup_Retention"
					} else {
						$vol | Add-Member -MemberType NoteProperty -Name "SnapSched" -Value "NotFoundSchedSnaps"
					}
					

					$snapsDailyRetention = $SnapsTarget 
					$vol | Add-Member -MemberType NoteProperty -Name "Snaps" -Value $snaps
                    $vol | Add-Member -MemberType NoteProperty -Name "snapsDaily" -Value $snapsDaily.count
					$vol | Add-Member -MemberType NoteProperty -Name "snapName" -Value $snapsDaily.count
					
					$vol | Add-Member -MemberType NoteProperty -Name "SnapsExportedCount" -Value  $SnapsExported.count
					$vol | Add-Member -MemberType NoteProperty -Name "SnapsExportedSize" -Value  ($SnapsExported |Measure-Object -Property allocated -Sum).Sum
					$vol | Add-Member -MemberType NoteProperty -Name "SnapsExportedHSize" -Value  (Format-FileSize -size $vol.SnapsExportedSize)
					
					$vol | Add-Member -MemberType NoteProperty -Name "SnapsCount" -Value $snaps.count
					
					$vol | Add-Member -MemberType NoteProperty -Name "SnapsDailyRetentionCount" -Value  $snapsDailyRetention.count
					$vol | Add-Member -MemberType NoteProperty -Name "SnapsDailyRetentionSize" -Value  ($snapsDailyRetention |Measure-Object -Property allocated -Sum).Sum
					$vol | Add-Member -MemberType NoteProperty -Name "SnapsDailyRetentionHSize" -Value  (Format-FileSize -size $vol.SnapsDailyRetentionSize)
					if ($PSEdition -eq "Core")
					{
						$vol | Add-Member -MemberType NoteProperty -Name "LastSnapDaily" -Value ($snapsDaily| Sort-Object -Property created_at -Bottom 1).created_at
						$vol | Add-Member -MemberType NoteProperty -Name "LastSnapHourly" -Value ($snapsEvery| Sort-Object -Property created_at -Bottom 1).created_at
						$vol | Add-Member -MemberType NoteProperty -Name "LastSnapDailyRetention" -Value ($snapsDailyRetention| Sort-Object -Property created_at -Bottom 1).created_at
					} else {
						$vol | Add-Member -MemberType NoteProperty -Name "LastSnapDaily" -Value ($snapsDaily| Sort-Object -Property created_at | select-object -Last 1).created_at
						$vol | Add-Member -MemberType NoteProperty -Name "LastSnapHourly" -Value ($snapsEvery| Sort-Object -Property created_at| select-object -Last 1).created_at
						$vol | Add-Member -MemberType NoteProperty -Name "LastSnapDailyRetention" -Value ($snapsDailyRetention| Sort-Object -Property created_at | select-object -Last 1).created_at
					}
					$vol | Add-Member -MemberType NoteProperty -Name "snapsEvery" -Value $snapsEvery.count
					$vol | Add-Member -MemberType NoteProperty -Name "SnapsEveryHourSize" -Value  ($snapsEvery |Measure-Object -Property allocated -Sum).Sum
					$vol | Add-Member -MemberType NoteProperty -Name "SnapsEveryHourHSize" -Value  (Format-FileSize -size $vol.SnapsEveryHourSize)
                }

                $vol.created_at = Convert-FromUnixDate -UnixDate $vol.created_at
                $vol.updated_at = Convert-FromUnixDate -UnixDate $vol.updated_at

                $vol | Add-Member -MemberType NoteProperty -Name "Hsize" -Value (Format-FileSize -size $vol.size)
                $vol | Add-Member -MemberType NoteProperty -Name "Hused" -Value (Format-FileSize -size $vol.used)
                $vol | Add-Member -MemberType NoteProperty -Name "Hallocated" -Value (Format-FileSize -size $vol.allocated)
				if ($vol.tree_allocated -eq "")
				{
					$vol | Add-Member -MemberType NoteProperty -Name "Htree_allocated" -Value 0
				} else {
					$vol | Add-Member -MemberType NoteProperty -Name "Htree_allocated" -Value (Format-FileSize -size $vol.tree_allocated)
				}
				$vol
			}
        } elseif ($Json.metadata.number_of_objects -eq "0"){
            $obj = "" | Select code,level,description,timestamp
            $obj.code = ""
            $obj.level = $Level
            $obj.description = "No Events Found"
            $obj.timestamp = Get-Date
            @($obj)
        }
    }
    
}

function GetIboxVolSnaps {
    param(
        $iBoxCred,
        $filer,
        $volId,
		$Fs=$false
    )
	if ($Fs)
	{
		$url = 'https://' + $filer +':443/api/rest/filesystems?sort=created_at&parent_id=eq:' + $volId + '&page_size=1000&page=1'
	} else {
		$url = 'https://' + $filer +':443/api/rest/volumes?sort=created_at&parent_id=eq:' + $volId + '&page_size=1000&page=1'
	}
	if ($PSVersionTable.PSEdition -eq "Desktop")
	{
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url
    } else {
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -SkipCertificateCheck:$true
	}
    if ($Result.StatusCode -eq 200) #Checking if Get Request getting 200 OK CODE
    {
        $Json = ConvertFrom-Json $Result.Content
        $IboxResult = $Json.result
        if (($IboxResult -ne $null) -and ($Json.result.Length -gt 0))
        {
            foreach ($vol in $json.result)
            {
				if ($vol.has_children -eq 'True')
				{
					$snaps = GetIboxVolSnaps -iBoxCred $iBoxCred -filer $filer -volId $vol.id -Fs $Fs 
					$vol | Add-Member -MemberType NoteProperty -Name "Snaps" -Value $snaps					
					$vol | Add-Member -MemberType NoteProperty -Name "SnapsCount" -Value $snaps.count
                }
				$vol.created_at = Convert-FromUnixDate -UnixDate $vol.created_at
                $vol.updated_at = Convert-FromUnixDate -UnixDate $vol.updated_at
		
                $vol | Add-Member -MemberType NoteProperty -Name "Hsize" -Value (Format-FileSize -size $vol.size)
                $vol | Add-Member -MemberType NoteProperty -Name "Hused" -Value (Format-FileSize -size $vol.used)
                $vol | Add-Member -MemberType NoteProperty -Name "Hallocated" -Value (Format-FileSize -size $vol.allocated)
            }
			$IboxResult
        } elseif ($Json.metadata.number_of_objects -eq "0"){
            return $null
        }
    }
}

#https://172.16.103.220
#
#https://172.16.103.220/api/rest/notifications/targets/{id}/test
#
#{
#    "r": "a@b.com"
#}

function GetIboxNortificationTargets {
    param(
        $iBoxCred,
        $filer
    )
		
	$url = 'https://' + $filer +':443/api/rest/notifications/targets'
	if ($PSVersionTable.PSEdition -eq "Desktop")
	{
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url
    } else {
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -SkipCertificateCheck:$true
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

function TestIboxNortificationTargets {
    param(
        $iBoxCred,
        $filer,
		$id,
		$to
    )
	$body =  @{recipients=@($To)} | ConvertTo-Json
	$url = 'https://' + $filer + '/api/rest/notifications/targets/' + $id + '/test'
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

function GetIboxNodeTime {
    param(
        $iBoxCred,
        $filer
    )
	$url = 'https://' + $filer + '/api/rest/system/ntp_status/'
	if ($PSVersionTable.PSEdition -eq "Desktop")
	{
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -Method GET 
    } else {
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -SkipCertificateCheck:$true -Method GET 
	}
    if ($Result.StatusCode -eq 200) #Checking if Get Request getting 200 OK CODE
    {
        $Json = ConvertFrom-Json $Result.Content
		$Nodes = @()
		foreach ($node in $Json.result)
		{
			$obj = "" | Select Node,TimeSpan
			$obj.Node = $node.node_id
			$obj.TimeSpan = Convert-FromUnixDate -UnixDate $node.last_probe_timestamp
			$Nodes += $obj
		}
        if (($Json -ne $null) -and ($Json.result.Length -gt 0))
        {
           return $Nodes
        } elseif ($Json.metadata.number_of_objects -eq "0"){
            return $null
        }
    }
}


#https://172.16.103.84/api/rest/volumes?name=DC_iBox02_AlgoTrade_BF-target
#PUT api/rest/cgs/{id}	
#{
#    "name": "newCgName"
#}

function SetIboxObjById{
	param(
        $iBoxCred,
        $filer,
		$objType,
		$objId,
		$newName		
	)
	$objId = $objId.ToString()
	$url = 'https://' + $filer + "/api/rest/" + $objType + "/$objId/"
	$data = @{
		name = $newName
	} |ConvertTo-Json
	if ($PSVersionTable.PSEdition -eq "Desktop")
	{
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -Method PUT -body $data -ContentType "application/json"
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


function GetIboxObjByName{
	param(
        $iBoxCred,
        $filer,
		$objType,
		$Name		
	)
	$url = 'https://' + $filer + "/api/rest/" + $objType + "?name=" + $name
	if ($PSVersionTable.PSEdition -eq "Desktop")
	{
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -Method Get 
    } else {
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -SkipCertificateCheck:$true -Method Get
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

function GetIboxDatasetBySerial{
	param(
        $iBoxCred,
        $filer,
		$DatasetType,
		$serial		
	)
	$url = 'https://' + $filer + "/api/rest/" + $DatasetType + "?serial=" + $serial
	if ($PSVersionTable.PSEdition -eq "Desktop")
	{
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -Method Get 
    } else {
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -SkipCertificateCheck:$true -Method Get
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


function GetIboxDatasetById{
	param(
        $iBoxCred,
        $filer,
		$DatasetType,
		$id		
	)
	$url = 'https://' + $filer + "/api/rest/" + $DatasetType + "?id=" + $id.ToString()
	if ($PSVersionTable.PSEdition -eq "Desktop")
	{
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -Method Get 
    } else {
		$Result = Invoke-WebRequest -Credential $iBoxCred -Uri $url -SkipCertificateCheck:$true -Method Get
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
	
#$iBoxes = @(@{Name="DC_iBox01"; IP="172.16.103.94"},
#            @{Name="DC_iBox02"; IP="172.16.103.140"},
#            @{Name="DR_iBox01"; IP="172.16.103.98"},
#            @{Name="DR_iBox02"; IP="172.16.103.84"})


#checkIboxEvents -filer 172.16.103.220 -iBoxCred $iBoxCred -SDate (Get-Date).AddDays(-1) -Level 'WARNING'
#checkIboxEvents -filer 172.16.103.220 -iBoxCred $iBoxCred -SDate (Get-Date).AddDays(-1) -Level 'ERROR'
#checkIboxEvents -filer 172.16.103.220 -iBoxCred $iBoxCred -SDate (Get-Date).AddDays(-1) -Level 'CRITICAL'

 #$IboxResult = $ibox2.result
 #$ibox2.result.ups | where {$_.state -ne "OK"}
 #$ibox2.result.enclosures | where {$_.state -ne "OK"}
 #$ibox2.result.enclosures.power_supplies | where {$_.state -ne "OK"}
 #$ibox2.result.enclosures.drives | where {$_.state -ne "ACTIVE"} 
 #$ibox2.result.patch_panels.frames.ports | where {($_.state -ne "OK") -and ($_.state -ne $null)}
 #$ibox2.result.pdus | where {$_.state -ne "OK"}
 #$ibox2.result.nodes | where {($_.state -ne "ACTIVE") -and ('ipmi.state' -ne "OK") -and ('ntp.state' -ne "OK") -and ('bios.state' -ne "OK")}
 #$ibox2.result.nodes.services | where {$_.state -ne "ACTIVE"}
 #$ibox2.result.nodes.ib_ports | where {$_.state -ne "OK"}
 #$ibox2.result.nodes.pgs | where {$_.state -ne "OK"}
 #$ibox2.result.nodes.power_supplies | where {$_.state -ne "OK"}
 #$ibox2.result.nodes.hba | where {$_.state -ne "OK"}
 #$ibox2.result.nodes.connectivity_status.enclosures | where {$_ -ne "UP"}
 #$ibox2.result.nodes.connectivity_status.pdu | where {$_ -ne "UP"}
 #$ibox2.result.nodes.connectivity_status.support_appliances | where {$_ -ne "UP"}
 #$ibox2.result.nodes.connectivity_status.bbu  | where {$_.state -ne "OK"}
 #$ibox2.result.nodes.drives | where {$_.state -ne "OK"}
 #$ibox2.result.nodes.fc_ports | where {$_.state -ne "OK"}
 #$ibox2.result.nodes.tpm | where {$_.state -ne "OK"}
 #$ibox2.result.nodes.eth_ports | where {$_.state -ne "OK"}




# $ibox2.result.enclosures | where {$_.state -ne "OK"}
# $ibox2.result.enclosures.power_supplies | where {$_.state -ne "OK"}
# $ibox2.result.enclosures.drives | where {$_.state -ne "ACTIVE"} 
