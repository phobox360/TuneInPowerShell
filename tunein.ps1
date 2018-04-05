
<# TuneIn Script for PowerShell written by phobox360

    Required: Windows PowerShell 3+
    Last modified: 13/1/2018 at 14:41
    Todo:
    write proper exit routine which all functions call to do cleanup of variables etc
    improve interface further
    write proper error checking
#>


Param( 
    [Alias('se')]    [string]$search,
    [Alias('Sn')]   [string]$stationName,
    [Alias('c')]    [int16]$count,
    [Alias('d')]    [switch]$describe,
    [Alias('s')]    [switch]$stop,
    [switch]$status,
    [switch]$setDebug
)
$ErrorActionPreference = "SilentlyContinue"

function displayInto {
    $oc = $host.ui.RawUI.ForegroundColor
    $host.ui.RawUI.ForegroundColor = "Green"
    Write-Output "TuneIn Radio Player v0.7"
    Write-Output "------------------------"
    $host.ui.RawUI.ForegroundColor = $oc
}

function searchfor($i) {

    if ($search.count -gt 0) {
        foreach ($ii in $search)
        {
            $errorCount = 0
            $OpenUrl = Invoke-RestMethod -Uri "http://opml.radiotime.com/Search.ashx?query=$ii&types=station" -Method Get
    
            Write-Output "+ Displaying $($i + 1) results from search for $ii"
            Write-Output ""
            
            foreach ($noLink in $OpenURL.opml.body.outline[0..$i])
            {
                if ($noLink.type -ne "link") {
                    if ($describe) {
                    $oc = $host.ui.RawUI.ForegroundColor
                    $host.ui.RawUI.ForegroundColor = "Yellow"
                    Write-Output $noLink.text
                    $host.ui.RawUI.ForegroundColor = $oc
                    Write-Output " - Currently playing: $($noLink.current_track)"
                    Write-Output " - Format: $($noLink.formats)"
                    Write-Output " - Bitrate: $($noLink.bitrate)"    
                    }
                    if (-not$describe) { 
                        $oc = $host.ui.RawUI.ForegroundColor
                        $host.ui.RawUI.ForegroundColor = "Yellow"
                        Write-Output $noLink.text
                        $host.ui.RawUI.ForegroundColor = $oc
                    }
                }
                if ($noLink.type -eq "link"){ $errorCount++ }
            
            }
            Write-Output ""
            Write-Output "- Omitted $errorCount item(s) from results because item was not a station"

            
            echo ""
        }
    }
    exit
    $OpenUrl = Invoke-RestMethod -Uri "http://opml.radiotime.com/Search.ashx?query=$search&types=station" -Method Get
    
    $outstring = "+ Displaying $($i + 1) results from search for $search"

    Write-Output $outstring
    echo ""
    $OpenUrl.opml.body.outline[0..$i].text
    echo ""
    Write-Output "- Play a station by passing it with the -stationName parameter"
    exit

    }

function getStation {

    $OpenUrl = Invoke-RestMethod -Uri "http://opml.radiotime.com/Search.ashx?query=$stationName" -Method Get

    $streamURL = $OpenURL.opml.body.outline[0].URL
    if ($streamURL -like "*Tune.ashx*") {
        $guideid = $OpenUrl.opml.body.outline[0].guide_id
        if ($describe) {
            Write-Output "- Found $stationName"
            Write-Output "+ Retrieving station information"
            $description = Invoke-RestMethod -Uri "http://opml.radiotime.com/Describe.ashx?c=nowplaying&id=$guideid" -Method Get
            Write-Output "Station: $($description.opml.body.outline.text[0])"
            Write-Output "Description: $($description.opml.body.outline.text[1])"
            Write-Output "Currently playing: $($OpenUrl.opml.body.outline[0].current_track)"
            Write-Output "Format: $($OpenUrl.opml.body.outline[0].formats)"
            Write-Output "Bitrate: $($OpenUrl.opml.body.outline[0].bitrate)"
            echo ""
        }
        Write-Output "+ Found $stationName, beginning playback"
        $playableURL = Invoke-RestMethod -Uri $streamURL -Method Get
        # $playableURL
        playStream $playableURL
        #Start-Job -Name StreamPlayer -InitializationScript $mediaJob -ScriptBlock { playStream $args[0] } -ArgumentList "$playableURL"

        ## & 'C:\Program Files (x86)\AIMP\AIMP.exe' $playableURL
        exit
    }
    Write-Output "- no stream url found for search param, returning contents of parsed url.."
    $streamURL
    exit
}


function notifyBalloon($message)
    {
        [system.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
        $Global:Balloon = New-Object System.Windows.Forms.NotifyIcon
        $balloon.BalloonTipIcon = 'Info'
        $balloon.BalloonTipText = $message
        $balloon.BalloonTipTitle = 'TuneIn Script'
        $balloon.Visible = $true
        $balloon.ShowBalloonTip(3000)
    }

function playStream($playableURL)
    {
            $mediaJob = {

                function writeDebug($outMessage)
                {
                    if ($Global:debugBit -eq 1) {
                        Write-Output "$outMessage"
                    }
                }
                function playAudio($plUrl) {

                    writeDebug "++ debug: got url: $plUrl"
                    Add-Type -AssemblyName PresentationCore
                    $wmplayer = New-Object System.Windows.Media.MediaPlayer
                    $wmplayer.Open($plUrl)
                    $wmplayer.Play()
                    start-sleep 2
                    if ($wmplayer.HasAudio) {
                        writeDebug "++ debug: stream playback started"
                        
                        #write-output "++ Playing back radio stream, pass -s parameter to stop"
                    }
                    if ($wmplayer.IsBuffering) {
                        writeDebug "++ debug: stream buffering"
                        start-sleep 3
                    }
                    while ($wmplayer.HasAudio) {
                    Start-sleep 1
                    }
                    writeDebug "++ Audio stream stopped"
                    $wmplayer.Close()
                    writeDebug "++ Audio stream ended"
                }
            }


            Start-Job -Name StreamPlayer -InitializationScript $mediaJob -ScriptBlock {$Global:debugBit = $args[1]; writedebug "++ Debug bit set"; playAudio $args[0]} -ArgumentList $playableURL, $Global:debugBit | Out-Null
        
            return
            #notifyBalloon("Now playing: $playableURL")
             
    }


displayInto

if ($PSBoundParameters.Count -lt 1) {
        "- You must specify at least one option, as such:

        tunein.ps1 [OPTION]
        
        Options:
            -search [-se] `"search term`"
            -stationName [-sn] `"station name`"
            -count [-c] #
            -describe [-d]
            -stop [-s]
            -status

        Examples:
            Tunein.ps1 -s `"BBC`" -c 4

            This will search for the term BBC and display a max of 4 applicable results

        If you specify search terms AND a station name, the latter will be ignored.
        Omitting the -c or -count option will default to a max of 3 search results.
        You can specify multiple search terms, such as:
            Tunein.ps1 -search `"term1`",`"term2`" etc

        -d or -describe will produce further information about search results and stations
        -stop will stop any currently playing station
        -status will display the status of any currently playing station"
        
        exit
}

if ($setDebug)
    {
        write-output "-+ Debug option set, output will be verbose"
        $Global:debugBit = 1
    }
$Global:debugBit = 0

if ($stop) {

    $jobState = Get-Job
    if ($jobState.name -like "StreamPlayer") {

        $x = Get-Job -Name StreamPlayer
        if ($x.JobStateInfo.state -eq "Running") {
            Write-Output "+ Stopping current playback"
            Receive-Job -Name StreamPlayer
        
            Stop-Job -Name StreamPlayer
            Remove-Job -Name StreamPlayer -force
            Write-Output "+ Stopped"
            exit
        }
        Write-Output "+ Background stream is present, but not running. Clearing job."
            Receive-Job -Name StreamPlayer
            Remove-Job -Name StreamPlayer -force
            Write-Output "- Done."
            exit

    }
    
    Write-Output "- There is nothing currently playing"
    exit
    
}

if ($status) {
    $jobState = Get-Job
    if ($jobState.name -like "StreamPlayer")
        {
            $x = Get-Job -Name StreamPlayer
            if ($x.JobStateInfo.state -eq "Running") {
                Write-Output "- Audio stream is currently running"
                Receive-Job -Name StreamPlayer -Keep
                exit    
            }
            Write-Output "- Background stream is present, but not running. Clearing job."
            Receive-Job -Name StreamPlayer
            Remove-Job -Name StreamPlayer -force
            Write-Output "- Done."
            exit
        }
    Write-Output "- There is nothing currently playing"
}

if ($search) { 
    if ($stationName) {
        Write-Output "- Station specified, ignoring in favour of search results"
    }
    if ($count) {
        if ($count -gt 1) { searchfor ($count - 1) }
        searchfor 0
    }

    Write-Output "- Search option used without count, defaulting to 3"
    searchfor 2
    exit
 }
if ($stationName) { 
    
    $jobState = Get-Job
    if ($jobState.name -like "StreamPlayer") {
        Write-Output "- There is already a station playing"
        Receive-Job -Name StreamPlayer -Keep
        exit
    }
    
    getStation

}

if ($describe) { write-output "- Describe can only be used with other options"}

exit




