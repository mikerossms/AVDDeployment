# In this example, the function connects to the Azure Storage services using the New-AzStorageBlobClient and New-AzStorageFileClient cmdlets from the Azure PowerShell module. It uses the GetBlobReferenceFromServer and GetFileReference cmdlets to check if the file exists in the archive container or cold file share. If the file does not exist in either location, it returns a HTTP response with a status code of 404 and a message "File not found in archive or cold storage". If the file is found in the archive container, the function uses the StartCopy cmdlet to copy the file to the hot file share.
# Please make sure you have the Azure PowerShell module installed, and replace the placeholder values with the appropriate information for your environment, such as the storage account name, account key and the container names.

# n this example, the function connects to the table storage using the New-AzStorageTableClient cmdlet and creates a new table named "movestatus" if it does not exist, then it creates an entity object with the file name, source, and status. Next, it inserts the entity into the table using the InsertEntity cmdlet. After that, it waits for the move to complete by checking the copy state of the file in hot storage using the CopyState.Status property. Finally, it updates the status of the move in the table to "done" using the InsertOrReplaceEntity cmdlet.
# Please make sure you have the Azure PowerShell module installed, and replace the placeholder values with the appropriate information for your environment, such as the storage account name and connection string.

function Move-ColdArchiveFileToHot {
param($Request, $TriggerMetadata)

param($Request, $TriggerMetadata)

$filename = $Request.Query.filename

# Connect to blob service
$blob_client = New-AzStorageBlobClient -ConnectionString "your_connection_string"

# Check if file exists in archive container
try {
    $archive_blob = $blob_client.GetBlobReferenceFromServer("archive/$filename")
} catch {
    # Connect to file service
    $file_client = New-AzStorageFileClient -ConnectionString "your_connection_string"

    # Check if file exists in cold file share
    try {
        $cold_file = $file_client.GetFileReference("cold/$filename")
    } catch {
        return [HttpResponseContext]::new(404, "File not found in archive or cold storage.")
    }

    # Copy file to hot file share
    $hot_file = $file_client.GetFileReference("hot/$filename")
    $cold_file.StartCopy([Uri]$hot_file.Uri)

    # Update move status in storage table
    $move_status = "cold"
}

# Copy file to hot file share
$hot_file = $file_client.GetFileReference("hot/$filename")
$archive_blob.StartCopy([Uri]$hot_file.Uri)

# Update move status in storage table
$move_status = "archive"


# Connect to table storage
$table_client = New-AzStorageTableClient -ConnectionString "your_connection_string"

# Create a new table if it does not exist
$table_client.CreateTableIfNotExists("movestatus")

# Create an entity object to store move details
$move_details = [PSCustomObject]@{
    'PartitionKey' = $filename
    'RowKey' = (Get-Date).Ticks.ToString()
    'FileName' = $filename
    'Source' = $move_status
    'Status' = "pending"
}

# Insert the entity into the table
$table_client.InsertEntity("movestatus", $move_details)

# Wait for move to complete
while ($hot_file.CopyState.Status -eq "pending") {
    Start-Sleep -Seconds 5
    $hot_file.FetchAttributes()
}

# Update move status in table
$move_details.Status = "done"
$table_client.InsertOrReplaceEntity("movestatus", $move_details)

return [HttpResponseContext]::new(200, "File moved from $move_status to hot storage.")

}


function Get-ColdArchiveFileList {
    param($Request, $TriggerMetadata)

    # Connect to blob service
    $blob_client = New-AzStorageBlobClient -ConnectionString "your_connection_string"

    # Get list of files in archive container
    $archive_blobs = $blob_client.ListBlobs("archive")
    $archive_files = @()

    foreach ($blob in $archive_blobs) {
        $file = [PSCustomObject]@{
            'name' = $blob.Name
            'storage' = 'archive'
        }
        $archive_files += $file
    }

    # Connect to file service
    $file_client = New-AzStorageFileClient -ConnectionString "your_connection_string"

    # Get list of files in cold file share
    $cold_files = $file_client.ListFiles("cold")

    foreach ($file in $cold_files) {
        $file = [PSCustomObject]@{
            'name' = $file.Name
            'storage' = 'cold'
        }
        $archive_files += $file
    }

    # Return combined list of files
    return [HttpResponseContext]::new(200, (ConvertTo-Json $archive_files))
}

# In this example, the function connects to the table storage using the New-AzStorageTableClient cmdlet and retrieves the start and end date from the query string parameters of the request. If no date range is specified, it defaults to the last 7 days. It then creates a query object to filter the entities based on the specified date range using the TableQuery class. Next, it
function Get-TransferReport {

    param($Request, $TriggerMetadata)

    # Connect to table storage
    $table_client = New-AzStorageTableClient -ConnectionString "your_connection_string"

    $start_date = $Request.Query.startdate
    $end_date = $Request.Query.enddate

    # Default to last 7 days if no date range specified
    if (!$start_date) {
        $start_date = (Get-Date).AddDays(-7)
    }

    if (!$end_date) {
        $end_date = (Get-Date)
    }

    # Get all entities within the specified date range
    $query = New-Object -TypeName Microsoft.Azure.Cosmos.Table.TableQuery
    $query.FilterString = "Timestamp ge datetime'$start_date' and Timestamp le datetime'$end_date'"
    $results = $table_client.QueryEntities("movestatus", $query)

    # Group entities by status
    $status_group = $results.entities | Group-Object -Property Status

    # Output results
    $output = [PSCustomObject]@{
        'Pending' = ($status_group | Where-Object {$_.Name -eq "pending"}).Count
        'Completed' = ($status_group | Where-Object {$_.Name -eq "done"}).Count
    }

    return [HttpResponseContext]::new(200, (ConvertTo-Json $output))

}

# In this example, the function connects to the Azure Storage services using the New-AzStorageFileClient and New-AzStorageBlobClient cmdlets from the Azure PowerShell module. Next, it retrieves a list of the files using the ListFiles cmdlet from the file share container, then it iterates over the files and checks the age of each file using the LastModified property from the Properties object of the file. If the age of the file is greater than 60 days, it copies the file to the archive container using the StartCopy cmdlet and then deletes the file from the cold file share using the Delete cmdlet.
# Please make sure you have the Azure PowerShell module installed, and replace the placeholder values with the appropriate information for your environment, such as the storage account name, account key and the container names.
function Put-ColdToArchiveFile {

    param($Request, $TriggerMetadata)

    # Connect to file service
    $file_client = New-AzStorageFileClient -ConnectionString "your_connection_string"
    # Connect to blob service
    $blob_client = New-AzStorageBlobClient -ConnectionString "your_connection_string"

    # Get list of files in cold file share
    $cold_files = $file_client.ListFiles("cold")

    foreach ($file in $cold_files) {
        #Check the age of the file
        $age = (Get-Date) - $file.Properties.LastModified
        if ($age.TotalDays -gt 60) {
            # Copy file to archive container
            $archive_blob = $blob_client.GetBlobReference("archive/$($file.Name)")
            $file.StartCopy([Uri]$archive_blob.Uri)
            # Wait for copy to complete
            while ($archive_blob.CopyState.Status -eq "pending") {
                Start-Sleep -Seconds 5
                $archive_blob.FetchAttributes()
            }
            # Delete file from cold file share
            $file.Delete()
        }
    }

    return [HttpResponseContext]::new(200, "Cold files older than 60 days moved to archive.")

}

function Send-EmailOnStatusChange {
    param($Request, $TriggerMetadata)

    # Connect to table storage
    $table_client = New-AzStorageTableClient -ConnectionString "your_connection_string"

    # Get all entities with status "done" and no notification sent
    $query = New-Object -TypeName Microsoft.Azure.Cosmos.Table.TableQuery
    $query.FilterString = "Status eq 'done' and NotificationSent eq false"
    $results = $table_client.QueryEntities("movestatus", $query)

    foreach ($entity in $results.entities) {
        # Send email notification
        $email_to = $Request.Query.email
        $email_subject = "File move status update: $($entity.FileName)"
        $email_body = "The file $($entity.FileName) has been moved from $($entity.Source) to hot storage successfully."
        Send-MailMessage -To $email_to -Subject $email_subject -Body $email_body -SmtpServer "smtp.example.com" -From "noreply@example.com"
        # Update notification sent status
        $entity.NotificationSent = $true
        $table_client.InsertOrReplaceEntity("movestatus", $entity)
    }

    return [HttpResponseContext]::new(200, "Notification emails sent.")

}