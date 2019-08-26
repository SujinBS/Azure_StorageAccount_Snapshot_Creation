function Recur_Dir ( $path ){    
    $flag=0
    $functionindex=0
    #"Getting List under directory"+$path
    $temp = Get-AzureStorageFile -ShareName $Name -Context $ctx -Path $path
    $d = $temp | Get-AzureStorageFile
    $List = $d.Name
    #"List = "+$List
    foreach($a in $List){
        if ($d[$functionindex].GetType().Name -eq "CloudFileDirectory" -and $flag -eq 0 ) {
            $newpath = $path+'/'+$a
            $Output = Recur_Dir ( $newpath )
            $Output
            $flag = $Output[-1]
        }
        elseif ($d[$functionindex].GetType().Name -eq "CloudFile" -and $flag -eq 0 ) {
            $temppath=$path+'/'+$a
            $b = Get-AzureStorageFile -ShareName $Name -Context $ctx -Path $temppath
            "Found a file :"+$a+": under path :"+$path+": with last Modified date -"+$b.Properties.LastModified
            if ($b.Properties.LastModified -ge $s.SnapshotTime.DateTime){
                $flag=1
            }
        }
        else{
            "File:"+$a+"   is of type : "+$d[$functionindex].GetType().Name+"Under Path"+$path+"Not Matching Predefined values"
        }
        $functionindex++;
    }
    return $flag
}   

"Script Started on "+ [datetime]::today
"Step1: to Login to Azure Subscription"
$connectionName = "AzureRunAsConnection"
$RunAsConnection = Get-AutomationConnection -Name AzureRunAsConnection
Connect-AzureRmAccount -ServicePrincipal -TenantId $RunAsConnection.TenantId -ApplicationId $RunAsConnection.ApplicationId -CertificateThumbprint $RunAsConnection.CertificateThumbprint -ErrorAction Stop


$FileName = Get-AutomationVariable -Name 'StorageBackupFileName' 
$csvfile = Invoke-RestMethod -Uri $FileName | convertfrom-csv

foreach ($Sline in $csvfile) {
    "Match Storage file "    
    $StorageAccountName = $Sline.StorageAccountName         
    $StorageAccountKey = $Sline.StorageAccountKey
    $IsBlob = $Sline.IsBlob
    $Name = $Sline.Name
    $ResourceGroupName = $Sline.ResourceGroupName
    $Flag = $Sline.Flag     
    If ( $Flag -eq "Yes" ) {
        if ( $IsBlob -eq "Yes" ){
            "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"                      
            "Step2 : Create the context and taking back up of container "
            $Ctx = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey             
            $ListBlob = Get-AzureStorageBlob –Context $Ctx -Container $Name  | Where-Object { $_.ICloudBlob.IsSnapshot -eq $false  -and $_.SnapshotTime -eq $null }                   
                foreach($b in $ListBlob) { 
                "Step3 Found a blob with name : "+$b.Name
                "Step4 Getting Blob's Modified timestamp   : "+$b.LastModified
                $s = Get-AzureStorageBlob –Context $Ctx -Container $Name -prefix $b.Name | Where-Object { $_.ICloudBlob.IsSnapshot  }    
                "Step5 Getting respective snapshot's timestamp  : " +$s.SnapshotTime
                if ( $s.SnapshotTime -le $b.LastModified -or $s.SnapshotTime -eq $null ) {
                    "Step6 Deleting old snapshot : "+ $s.Name
                    $s.ICloudBlob.Delete()
                    "Step7 deletion of old snapshot completed "
                    $blob = Get-AzureStorageBlob -Context $Ctx -Container $Name -Blob $b.Name 
                    $snap = $blob.ICloudBlob.CreateSnapshot()
                    "Step8 Snapshot has been created"
                    $s = Get-AzureStorageBlob –Context $Ctx -Container $Name -prefix $b.Name | Where-Object { $_.ICloudBlob.IsSnapshot  }    
                    if ( $s.SnapshotTime -ge $b.LastModified ) {
                            "Step9 Created new snapshot with name : " + $s.Name 
                    }

                }
                else{
                    "Step 6 Snapshots are upto date, No New Snapshots created"
                }  
            }              
            "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        }
        else {
            "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
            "Step2 : Create the context"            
            $Ctx = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
            $flag=0
            $f = Get-AzureStorageShare -Context $Ctx  -Prefix $Name | Where-Object { $_.IsSnapshot -eq $false }
           $d = $f | Get-AzureStorageFile
            $s = Get-AzureStorageShare  –Context $Ctx  -Prefix $f.Name | Where-Object { $_.IsSnapshot -eq $true } 
            if($s.Exists()){
                "Step4 : found a Snapshot for file "+ $s.Name
                "Snapshot taken Timestamp  "+$s.SnapshotTime.DateTime
            }
            else{
                "Step4 : snapshot not found for file hence setting flag to 1 "
                $flag=1
            }
    
            $List = $d.Name
            $index=0
            foreach($a in $List){
                if ($d[$index].GetType().Name -eq "CloudFileDirectory" -and $flag -eq 0){                        
                    $OutputM = Recur_Dir( $a )
                    $OutputM
                    $flag = $OutputM[-1]

                }
                elseif ($d[$index].GetType().Name -eq "CloudFile" -and $flag -eq 0 ){
                    $b = Get-AzureStorageFile -ShareName $Name -Context $ctx -Path $d[$index]
                    "Found a file"+$a+"with last Modified date"+$b.Properties.LastModified.DateTime
                }
                else{
                     "File:"+$a+"   is of type : "+$d[$index].GetType().Name+"in File share path Not Matching Predefined values"                
                }   
                $index++;    
            }       

            if($flag -eq 1){
                "Found a modification done in Name hence taking new snapshot while deleting old"
                $s.Delete()
                $snapshot = $f.Snapshot()
                $s = Get-AzureStorageShare  –Context $Ctx  -Prefix $f.Name | Where-Object { $_.IsSnapshot -eq $true }  
                if( $f.Name -eq $s.Name  ){
                    "Step5 : New Snapshot was created successfully "+ $s.Name                    
                }  
                else {"Step5 : failure in creating new snapshot"+ $snapshot }                                 
            }
            else{
                "Not Taking any Snapshot for :"+$Name
            }                        
            "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"        
        }
    }   
}
"Script Ended at "+$dt


