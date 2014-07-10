##setup errorr handling
$ErrorActionPreference ="SilentlyContinue"

##import the SSH module
Import-Module SSH-Sessions



################################################################
################# Must complete this section ###################
################################################################



#////////////////////// Host Settings //////////////////////////
$DeviceList = Import-Csv C:\Audit\hosts.csv  


#////////////////// Output File Settings ///////////////////////

$time ="$(get-date -f yyyy-MM-dd)" ## get the date 
$filename ="config" ## optional text to add to filename
$ext =".txt" ## extension for the filename
$filepath ="C:\Audit\Configs\" ## location to store the output files


#////////////////// Connection Settings ////////////////////////

$connectionType ="telnet" ## connection type can be 'telnet' or 'ssh'
$username ="cisco" ## username for device logins
$password ="cisco" ## password for device logins
$termlength = "term len 0" ## useful for older consoles that have line display limitations
$enable = "en" ## useful for appliances like cisco switches that have an 'enable' command mode
$enablepassword = "" ## add enable password if there is one
$commandDelay = 1000 ## add a delay between commands

#////////////////// Command Settings ////////////////////////
$runCommands = ("show tech")

$pattern = '([A-Z])\w+#'

################################################################
##################### Optional Section #########################
################################################################

# If there are any devices with different username/password then 
# add them below
# e.g.:
#   $d1 ="192.168.1.1"
#   $d2 ="192.168.2.1
#   $d3 ="192.168.3.1
#   $d4 ="192.168.4.1
#   $d5 ="192.168.5.1
#   $d6 ="192.168.6.1

# Add devices here
$d1 =""

# add custom logins here, or just one if the same across all devices
# increment the $u variable each time a custome username is added
# e.g. 
# $u1 = "admin"
# $u2 = "dave"
$u1 =""

# below is your custom list of passwords that each device will use,
# if all devices use the same password just specify one variable.
$p1 =""


################################################################


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# DON'T ALTER THE CODE BELOW
# NO USER TUNABLE SETTINGS
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

## create array to store failed connections
$deadHosts = @()
$hostNoLogin = @()


## read output from remote host
function GetOutput
{
    ## buffer to receive the response
    $buffer = new-object System.Byte[] 1024 ## buffer size
    $encoding = new-object System.Text.AsciiEncoding ## buffer encoding

    $outputBuffer = "" ## define and clear the output from this function
    $foundMore = $false ## needs to be false to first check the buffer

    ## read all data available from the stream, writing it to the
    ## output buffer when done.
    do
    {
        ## allow data to buffer for a bit
        start-sleep -m 1000

        ## read what data is available
        $foundmore = $false
        $stream.ReadTimeout = 1000

        do
        {
            try 
            {
                $read = $stream.Read($buffer, 0, 1024) 

                if($read -gt 0) ## anything in the buffer?
                {
                    $foundmore = $true ## yes, there is
                    $outputBuffer += ($encoding.GetString($buffer, 0, $read)) ## add string to output
                    
                }
            } 
            catch 
            { 
                $foundMore = $false; $read = 0 ## couldn't read the buffer, exits the function 
            }
        } 
        while($read -gt 0) ## if there is something still in the buffer, loop back through
    } 
    while($foundmore) ## first time through, foundmore will be false so enter do

    $outputBuffer ## return the buffer output that we grabbed
}


function Main
{
    ## open the socket, and connect to the device on the specified port

    write-host "$hostname : Connecting on port $port" 
    $socket = new-object System.Net.Sockets.TcpClient ## create the socket

    ## let's check if we can open the socket
    try 
    { 
        $socket.Connect($hostname, $port)
        Write-Host "$hostname : Connection successful"
    }
    catch 
    { 
        Write-Host "$hostname : Connection Failed"
        $deadHosts += $hostname ## add the host to an array of dead hosts
    }
    finally
    {
        if ($socket.Connected) ## is our socket connected? let's login!
        {
            Write-Host "$hostname : Logging in"
            ## get the data stream from the socket
            $stream = $socket.GetStream() 
            ## get ready write to the socket
            $writer = new-object System.IO.StreamWriter $stream 

            ## we'll assume that our connection is fine, we'll check soon

            ## send the username
            $writer.WriteLine($username)
            $writer.Flush()
            Start-Sleep -m $commandDelay
            ## send the password
            $writer.WriteLine($password)
            $writer.Flush()
            Start-Sleep -m $commandDelay
            ## prevent the -- more -- when we run long commands
            $writer.WriteLine($termlength)
            $writer.Flush()
            Start-Sleep -m $commandDelay
            ## enter enable mode, this command is harmless if we are already
            ## priv 15 and we can avoid checking for the enable prompt :)
            ## if we aren't priv 15 then we will be prompted for the enable password. 
            $writer.WriteLine($enable)
            $writer.Flush()
            Start-Sleep -m $commandDelay
            ## send the enable password
            $writer.WriteLine($enablepassword)
            $writer.Flush()
            Start-Sleep -m $commandDelay

            ## all the output from the login should be in the buffer now, let's
            ## grab it and see if we were able to login
            $SCRIPT:output += GetOutput ## assign buffer content to a variable

            ## check the variable for a privileged exec prompt $pattern is the
            ## regex to find the enable prompt: Hostname#
            ## $result should return True if we found our priv exec prompt
            $result = $output -Match $pattern 

            ## if we have a prompt then we can run some commands
            if ($result)
            {
                Write-Host "$hostname : Login successful!"
                ## clear the buffer because our login was successful and we don't
                ## want to see the login process in our output file
                $output = ''
                ## start executing our commands that we set-up earlier
                foreach ($command in $runCommands)
                {
                    echo "$hostname : Executing $command"
                    $writer.WriteLine($command) ## executes commands from runCommands array
                    $writer.Flush()
                    Start-Sleep -m $commandDelay
                }

                ## get the output from the buffer
                $SCRIPT:output += GetOutput

                ## bit of exception handling, just in case the user made a mistake when they
                ## set the file-save directory
                try
                {
                    ## set our filename 
                    ## TODO: This should be an option in the settings so the user can customise
                    ## their file output
                    $output | Out-File ("$filepath$hostname-$filename-$time$ext") 
                    echo "$hostname : Config saved successfully"
                    echo "-------------------------------------"
                    $SCRIPT:output = ""
                }

                catch
                {
                    ## TODO: should probably add something here, maybe prompt for a directory
                    ## that actually exists, or check earlier on if it's valid.
                    echo "$hostname : Error saving config"
                    $SCRIPT:output = ""
                }
            }

            else
            {
                ## we couldn't login or didn't get a privileged exec prompt. add the host
                ## to a separate list hosts that are alive, but with perhaps different user
                ## and password.
                Write-Host "Login failed for $hostname"
                $hostNoLogin += $hostname
            }
            ## Close the streams
            $writer.Close()
            $stream.Close()
        }
    }
}


## First part of the script that actually runs, check to see if the user specified
## ssh or telnet and run up the appropriate client to connect through
switch ($connectionType)
{
    ssh {
        $port = 22
        foreach ($IP_add in $Devicelist) ## iterate through hosts CSV file
        {
            $hostname = $IP_add.IPAddress; ## assign the IP to a variable

            ## Exception handling as a failed connection will kill the whole script
            ## this is the behaviour of the SSH-Sessions module
            try{
                $connectionStatus = New-SshSession $hostname -Username $username -Password "$password" -ErrorAction "SilentlyContinue" ## start session
            }
            ## TODO: need to actually do something with this exception rather than just
            ## log it
            Catch{
                $ErrorMessage = $_.Exception.Message
                $FailedItem = $_.Exception.ItemName
            }
            ## TODO: need to bring this up to speed with the telnet section so that we
            ## can use all the commands in the array and just be a bit more 'smart'
            $Results = Invoke-Sshcommand -InvokeOnAll -Command "$c1" | Out-File "$filepath$hostname-$filename-$time$ext" ## save results
            Remove-SshSession -computername $hostname ## close session
        }
    }
    telnet {
        ## run the Telnet function
        $port = 23
        foreach ($IP_add in $Devicelist)
        {
            $hostname = $IP_add.IPAddress; ## assign the IP to a variable
            . Main ## run the Main function to create a socket and execute our commands
        }
    }
    default {
        ## if the user doesn't specify telnet or ssh in the settings then they hit this section
        "Unknown connectionType of: $connectionType" 
        "Please select either 'ssh' or 'telnet'"
    }

}
## if we have any hosts that were not reachable
if ($deadHosts)
{
    $errorCount = $deadHosts.count ## count how many we couldn't reach
    echo "$errorCount hosts could not be reached:" ## tell the user
    echo $deadHosts ## list the hosts so they can check it out
}
if ($hostNoLogin)
{
    $errorCount = $hostNoLogin.count ## count how many we couldn't reach
    echo "Could not login to $errorCount hosts:" ## tell the user
    echo $hostNoLogin ## list the hosts so they can check it out
}
## keeps the window open so the user can see if there were any problems
## 
Write-Host "Operation complete"
Write-Host "Press any key to continue ..."

$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# DON'T ALTER THE CODE ABOVE
# NO USER TUNABLE SETTINGS
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

