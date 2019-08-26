# Azure_StorageAccount_Snapshot_Creation
Powershell Script to check if there was any modifcation to blob or Fileshare and create a snapshot accordingly.


Our Team had received a request to create powershell in automation account which would create snapshot based on checks if there was any modification done in blob storage and fileshare storage in Azure.
So when i tried to code, getting lastmodified time for blob was easy but fetching lastmodified date for file share was not available so used recursive logic to manually check of last modified date of each file and compare with last snapshot taken.

Thought sharing it would help save time and also if there is any modification to increase performance or alternate way comments would be welcomed.
