Add-Type -AssemblyName System.Windows.Forms


# New File Dialog
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ InitialDirectory = [Environment]::GetFolderPath('Desktop')
                                                                               Filter = 'RsLogix 500 Project (*.rss)|*.rss'
                                                                               Title = 'Select RsLogix 500 Project File'
                                                                             }

# Initial Empty Variables
$FileName = ''
$FileLocation = ''

# Known Possible byte Sequences
# %D byte Sequence
[byte[]]$SearchParam1 = 37,68,0,0,0,0
# %O Byte Sequence
[byte[]]$SearchParam2 = 37,79,0,0,0,0


# Opening Message
Function Open-Msg(){
    Clear-Host
    Write-Host 'This Will Attempt Retrieve The Password To RsLogix 500 Project Files'
    Read-Host -Prompt 'To Continue Press Enter Then Select Your Project File *.RSS'
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


# Read The RSS to Byte Array
Function Read-To-Byte(){
    Write-Host 'Reading'$FileName'...'
    $FileBytes  = [System.IO.File]::ReadAllBytes($FileLocation)
    Write-Host 'Done!'
    Find-Offset $FileBytes
}


# Finds Offset Location Of The Search Parameter In The RSS File
Function Find-Offset([byte[]]$File){

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

    # If Unable To Find With Current Search Params
    Write-Host
    Write-Host "Unable To Find Byte Array %D or %O"
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

    Encrypt_Check($PassArray)

}


# Check For Encription If Found Exits
Function Encrypt_Check([Array[]]$Passwords){

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
    If ([String]::IsNullOrEmpty($Passwords[0])){
        Write-Host 'No Project Password Found'
    } Else {
        Write-Host 'Found A Possible Project Password:' $Passwords[0]
    }
    Write-Host

    #Checks For Master Password
    If ([String]::IsNullOrEmpty($Passwords[1])){
        #Write-Host 'No Master Password Found'
    } Else {
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