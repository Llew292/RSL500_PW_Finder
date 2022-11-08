Add-Type -AssemblyName System.Windows.Forms


# New File Dialog
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ InitialDirectory = [Environment]::GetFolderPath('Desktop')
                                                                               Filter = 'RsLogix 500 Files (*.rss, *.ach)|*.rss;*.ach|RsLogix 500 Project (*.rss)|*.rss|RsLogix 500 Archive (*.ach)|*.ach'
                                                                               Title = 'Select RsLogix 500 Project File'
                                                                             }

# Initial Empty Variables
$FileName = ''
$FileLocation = ''

# Known Possible byte Sequences

# *.rss Files
# %D byte Sequence
[byte[]]$SearchParam1 = 37,68,0,0,0,0
# %O Byte Sequence
[byte[]]$SearchParam2 = 37,79,0,0,0,0

# *.ach Files
# 20-00-00-30 Byte Sequence
[byte[]]$SearchParam3 = 32,0,0,48



# Opening Message
Function Open-Msg(){
    Clear-Host
    Write-Host 'This Will Attempt Retrieve The Password To RsLogix 500 Files'
    Read-Host -Prompt 'To Continue Press Enter Then Select Your Project File (*.RSS) Or Your Project Archive File (*.ACH)'
    Open-Diag
}



# Open File Selection Dialog
Function Open-Diag(){
    $null = $FileBrowser.ShowDialog()

    # Check If Selection Successful
    If ([string]::IsNullOrEmpty($FileBrowser.SafeFileName)) {
        $input = Read-Host -Prompt 'Selection Failed Try Again?(y)'
        If ($input.Contains('y')){
            Open-Diag
        }
        else{
            exit
        }
    } else {

        # File Params
        $FileName = $FileBrowser.SafeFileName
        $FileLocation = $FileBrowser.FileName
        Read-To-Byte
    }
}



# Read The File to Byte Array
Function Read-To-Byte(){
    Write-Host 'Reading'$FileName'...'
    $FileBytes  = [System.IO.File]::ReadAllBytes($FileLocation)
    Write-Host 'Done!'
    Find-Offset $FileBytes
}



# Finds Offset Location Of The Search Parameter In The File
Function Find-Offset([byte[]]$File){
    $FileExt = (Get-ChildItem $FileLocation | select Extension).Extension.toLower()
    
    # *.rss files
    If ($FileExt.Equals('.rss')){
        # Searches For %D First $SearchParam1
        Write-Host 'Searching %D In'$FileName'...'
        $ByteOffset = Find-Bytes $File $SearchParam1
        If ([string]::IsNullOrEmpty($ByteOffset)){
            Write-Host '%D Not Found'
        }
        else {
            Pin-To-String $File ($ByteOffset+$SearchParam1.Count)
        }

        # Searches For %O Second $SearchParam2
        Write-Host 'Searching %O In'$FileName'...'
        $ByteOffset = Find-Bytes $File $SearchParam2
        If ([string]::IsNullOrEmpty($ByteOffset)){
            Write-Host '%O Not Found' 
        }
        else {
            Pin-To-String $File ($ByteOffset+$SearchParam2.Count)
        }
    }

    # *.ach files
    If ($FileExt.Equals('.ach')){
        # Searches For (*.ACH) Array 20-00-00-30 Third $SearchParam2
        Write-Host 'Searching 20-00-00-30 In'$FileName'...'
        $ByteOffset = Find-Bytes $File $SearchParam3
        If ([string]::IsNullOrEmpty($ByteOffset)){
            Write-Host '20-00-00-30 Not Found' 
        }
        else {
            Pin-To-String $File ($ByteOffset+$SearchParam3.Count)
        }
    }

    # If Unable To Find With Current Search Params
    Write-Host
    Write-Host "Unable To Find Byte Array %D, %O or known (*.ach) Arrays"
    Write-Host
    Read-Host -Prompt 'Press Enter To Close'
    exit
}



# Creates a Password Array of Both Project Password And Master Password If Found
Function Pin-To-String([byte[]]$File, [int]$Offset){
    #Create Empty Byte Arrays
    [byte[]]$ProjectPass = new-object byte[] 0
    [byte[]]$MasterPass = new-object byte[] 0

    #Create Empty Array Of Length 2
    [Array[]]$PassArray = new-object Array[] 2

    # Get Pass of Extension *.rss
    If ($FileExt.Equals('.rss')){
        # Get Length Of Project Password
        [Int]$ProjectPasslength = $File[$Offset]

        #Get Length Of Master Password
        [Int]$MasterPasslength = $File[$Offset+$ProjectPasslength+1]

        # If Password Length Is Found Get Project Password
        If ($ProjectPasslength -gt 0){
            $i = $Offset+1
            for(;$i -le ($Offset+$ProjectPasslength);$i++)
            {
                $ProjectPass = $ProjectPass+$File[$i]
            }
            $PassArray[0] = [System.Text.Encoding]::ASCII.GetString($ProjectPass)
        }

        # If Password Length Is Found Get Master Password
        If ($MasterPasslength -gt 0){
            $i = $Offset+$ProjectPasslength+2
            for(;$i -le ($Offset+$ProjectPasslength+1+$MasterPasslength);$i++)
            {
                $MasterPass = $MasterPass+$File[$i]
            }
            $PassArray[1] = [System.Text.Encoding]::ASCII.GetString($MasterPass)
        }
    }

    # Get Pass of Extension *.ach
    If ($FileExt.Equals('.ach')){

        # Find Passwords
        $i = $Offset
        for(;$i -le $Offset+19;$i++){
        
            # Project Password
            If (($File[$i] -ne 0) -and ($i -lt ($Offset+10))){
                $ProjectPass = $ProjectPass+$File[$i]
            }
            # Master Password
            ElseIf(($File[$i] -ne 0) -and ($i -ge ($Offset+10))){
                $MasterPass = $MasterPass+$File[$i]
            }
        }
        $PassArray[0] = [System.Text.Encoding]::ASCII.GetString($ProjectPass)
        $PassArray[1] = [System.Text.Encoding]::ASCII.GetString($MasterPass)
    }

    Message_Check($PassArray)

}



# Tests Messages
Function Message_Check([Array[]]$Passwords){
    
    # Tests For Empty Strings In Both Project And Master Fields
    If ([String]::IsNullOrEmpty($Passwords[0]) -and [String]::IsNullOrEmpty($Passwords[1])){
        Write-Host
        Write-Host 'No Password Found In Project'
        Write-Host
        Read-Host -Prompt 'Press Enter To Close'
        exit
    }

    # Test For Encrypted Passwords
    If ((-Not [String]::IsNullOrEmpty($Passwords[0]) -and (Is-Numeric ($Passwords[0]))) -or (-Not [String]::IsNullOrEmpty($Passwords[1]) -and (Is-Numeric ($Passwords[1])))){

        Found-Pass $Passwords

    } Else {

        # Shows Message If Password Is Encrypted
        Write-Host
        Write-Host "Encrypted Password Found!"
        Write-Host "Unable To Decrypt At This Time"
        Write-Host
        Read-Host -Prompt 'Press Enter To Close'
        exit
    }

}



# Shows Messages With One Or Both Passwords
Function Found-Pass([Array[]]$Passwords){
    Write-Host

    # Checks For Project Password
    If ((-Not [String]::IsNullOrEmpty($Passwords[0])) -and (Is-Numeric ($Passwords[0]))){
        Write-Host 'Found A Possible Project Password:' $Passwords[0]
    } Else {
        Write-Host 'No Project Password Found'
    }
    Write-Host

    #Checks For Master Password
    If ((-Not [String]::IsNullOrEmpty($Passwords[1])) -and (Is-Numeric ($Passwords[1]))){
        Write-Host 'Found A Possible Master Password:' $Passwords[1]
        Write-Host
    }

    Read-Host -Prompt 'Press Enter To Close'
    exit
}



# Find Bytes In Byte Array
Function Find-Bytes([byte[]]$Bytes, [byte[]]$Search, [int]$Start, [Switch]$All) {
    For ($Index = $Start; $Index -le $Bytes.Length - $Search.Length ; $Index++) {
        For ($i = 0; $i -lt $Search.Length -and $Bytes[$Index + $i] -eq $Search[$i]; $i++) {}
        If ($i -ge $Search.Length) { 
            $Index
            If (!$All) { Return }
        } 
    }
}



# Checks String For Numeric Value
function Is-Numeric ($Value) {
    return $Value -match "^[\d\.]+$"
}



# Script Start
Open-Msg
