#setup errorr handling
$ErrorActionPreference ="SilentlyContinue"

#import the SSH module
Import-Module SSH-Sessions

#setup our filename
$time ="$(get-date -f yyyy-MM-dd)"
$filename ="config"
$ext =".txt"

# Change the storage location of the configs below
$filepath ="C:\Audit\Configs\"

################################################################
################# Must complete this section ###################
################################################################

# Default username and password
$username =""
$password =""
# Connection type can be 'telnet' or 'ssh'
$connectionType ="telnet"
# Get device IPs from *.csv file( named "hosts.csv").
$DeviceList = Import-Csv C:\Audit\hosts.csv  


$termlength = "term len 0" #Useful for older consoles that have line display limitations
$enable = "en" #useful for appliances like Cisco switches that have an 'enable' command mode
$enablepassword = ""
$commandDelay = 1000

# insert each command that you need to run for each device in this
# array
$runCommands = ("show run","show ip int brie")

# create array to store failed connections
$hostsWithError = @()

################################################################

#---------------------------------------------------------------

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

## Read output from a remote host
function GetOutput
{
  ## Create a buffer to receive the response
  $buffer = new-object System.Byte[] 1024
  $encoding = new-object System.Text.AsciiEncoding

  $outputBuffer = ""
  $foundMore = $false

  ## Read all the data available from the stream, writing it to the
  ## output buffer when done.
  do
  {
    ## Allow data to buffer for a bit
    start-sleep -m 1000

    ## Read what data is available
    $foundmore = $false
    $stream.ReadTimeout = 1000

    do
    {
        try
        {
            $read = $stream.Read($buffer, 0, 1024)

            if($read -gt 0)
            {
                $foundmore = $true
                $outputBuffer += ($encoding.GetString($buffer, 0, $read))
            }
        } 
        catch 
        { 
            $foundMore = $false; $read = 0 
        }
        } while($read -gt 0)
        } while($foundmore)

        $outputBuffer
    }


    function Main
    {
      ## Open the socket, and connect to the computer on the specified port

      write-host "Connecting to $hostname on port $port"
      try
      {
          $socket = new-object System.Net.Sockets.TcpClient($hostname, $port)
      }
      catch 
      {
        $hostsWithError += $hostname
    }
    if ($stream)
    {
        write-host "Connected. Press ^D followed by [ENTER] to exit.`n"

        $stream = $socket.GetStream()

        $writer = new-object System.IO.StreamWriter $stream

        ## Receive the output that has buffered so far
        $SCRIPT:output += GetOutput

        $writer.WriteLine($username)
        $writer.Flush()
        Start-Sleep -m $commandDelay
        $writer.WriteLine($password)
        $writer.Flush()
        Start-Sleep -m $commandDelay
        $writer.WriteLine($termlength)
        $writer.Flush()
        Start-Sleep -m $commandDelay
        $writer.WriteLine($enable)
        $writer.Flush()
        Start-Sleep -m $commandDelay
        $writer.WriteLine($enablepassword)
        $writer.Flush()
        Start-Sleep -m $commandDelay
        foreach ($command in $runCommands)
        {
            echo "Executing $command"
            $writer.WriteLine($command) #executes commands from runCommands array
            $writer.Flush()
            Start-Sleep -m $commandDelay
        }
        $SCRIPT:output += GetOutput

        ## Close the streams
        $writer.Close()
        $stream.Close()

        try{
            $output | Out-File ("$filepath$hostname-$filename-$time$ext") #Change this to suit your environment
            echo "Config saved successfully"
        }
        catch{
            echo "Error saving config"
        }
        

    }
    
}


#Loop through each host/IP and get the running config
switch ($connectionType)
{
    ssh {
        $port = 22
        foreach ($IP_add in $Devicelist)
        {
            $hostname = $IP_add.IPAddress; 
            try{
                $connectionStatus = New-SshSession $hostname -Username $username -Password "$password" -ErrorAction "SilentlyContinue" #start session
            }
            Catch{
                $ErrorMessage = $_.Exception.Message
                $FailedItem = $_.Exception.ItemName
            }
            $Results = Invoke-Sshcommand -InvokeOnAll -Command "$c1" | Out-File "$filepath$hostname-$filename-$time$ext" #save results
            Remove-SshSession -computername $hostname # close session
        }
    }
    telnet {
        # run the Telnet function
        $port = 23
        foreach ($IP_add in $Devicelist)
        {
            $hostname = $IP_add.IPAddress; 
            . Main
        }
    }
    default {
        "Unknown connectionType of: $connectionType"
        "Please select either 'ssh' or 'telnet'"
    }

}
if ($hostsWithError)
{
   $errorCount = $hostsWithError.count 
   echo "$errorCount hosts could not be reached:"
   echo $hostsWithError 
}


Write-Host "Press any key to continue ..."

$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")


# DON'T ALTER THE CODE ABOVE
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


# Uncomment and add extra lines for devices with non-standard username/password
# New-SshSession $d1 -Username $u1 -Password "$p1" #start session
# New-SshSession $d2 -Username $u2 -Password "$p2" #start session
# $Results = Invoke-Sshcommand -InvokeOnAll -Command "$c1" | Out-File "$filepath$filename-$time$ext" #save results
# Remove-SshSession -RemoveAll

# Exit PowerShell
# exit
