## NOTE: These variables really should be static strings set at various points, but powershell is a biznitch and i got fed up trying to make it work.
$EMAIL_TO="recipient@domain.tld"
$EMAIL_SUBJECT="Skykick Deployment Script Error: " + [Environment]::MachineName.ToUpper()
$EMAIL_BODY="Please read the attached log."

## This order is set purposely. Make sure the office versions are chronological (in descending time order, duh)
$OFFICE_VERSION_STRINGS = @("Microsoft Office 365 Small Business Premium - en-us", `
    "Microsoft Office Standard 2013", `
    "Microsoft Office Professional Plus 2013", `
    "Microsft Office Professional Plus 2010", `
    "Microsoft Office Professional 2010", `
    "Microsoft Office 2010", `
    "Microsoft Office Ultimate 2007", `
    "Microsoft Office Professional Plus 2007", `
    "Microsoft Office Professional 2007", `
    "Microsoft Office Enterprise 2007", `
    "Microsoft Office Professional Edition 2003", `
    "Microsoft Office")

## Ingenius Email Function
## MailMessage function only supports one attachment because I'm lazy.
Function MailMessage
{
    Param($toField, $subjectField, $bodyField, $attachmentPath=$null, $attachmentType='text/plain')
    
    $mailServer="server.domain.tld"
    $mailServerPort=25
    $mailUser="username"
    $mailPass="password"
    $fromField="somebox@domain.tld"
    
    $message=New-Object Net.Mail.MailMessage
    $client=New-Object Net.Mail.SmtpClient($mailServer, $mailServerPort)
    
    foreach ($rec in $toField) {$message.To.Add($rec) }
    $message.Subject=$subjectField
    $message.From=$fromField
    $message.Body=$bodyField
    if ($attachmentPath -ne $null)
    {
        $attachmentField = New-Object System.Net.Mail.Attachment($attachmentPath, $attachmentType)
        $message.Attachments.Add($attachmentPath)
    }
    $client.Credentials=New-Object Net.NetworkCredential($mailUser, $mailPass)
    $client.Send($message)
}

## START EXECUTION (off with 'er haed!)
##Start-Sleep -s 300
## First see if we already have this installed, and exit if we do and the deployable version is not an upgrade.
try{
    $myout = $null
    $myout = \\server.domain.tld\Software\Powershell\Get-InstalledApp.ps1 -AppName "Outlook Assistant"
    if ($myout -ne $null)
    {
        [System.Reflection.Assembly]::LoadWithPartialName("System.Version")
        $myDeployVersionStr = [string](\\server.domain.tld\Software\Powershell\Get-MSIFileInformation.ps1 \\server.domain.tld\Software\Deployable\Skykick\SKOAx32.msi -Property ProductVersion)
        $myInstalledVersionStr = [string]$myout.Version
        $DEPLOYVER = New-Object System.Version($myDeployVersionStr.Trim())
        $INSTALLVER = New-Object System.Version($myInstalledVersionStr.Trim())
        $ISUPGRADE = $DEPLOYVER.CompareTo($INSTALLVER)
        if ($ISUPGRADE -lt 1){ exit 0 }
    }
    $myout = $null

    # Now check for Office architecture and install the appropriate version of Skykick.
    foreach ($str in $OFFICE_VERSION_STRINGS)
    {
        $myout = \\server.domain.tld\Software\Powershell\Get-InstalledApp.ps1 -AppName $str
        if ($myout -ne $null)
        {
            if ($myout.Architecture -eq "64-bit")
            { 
                ## The PassThru switch is for returning an object representing spawned process in this case. This is a partially common switch, but not all commands support it.
                $myproc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/lvoicewarmup C:\skykick-install64.log /i \\server.domain.tld\Software\Deployable\Skykick\SKOAx64.msi /q" -PassThru
                $myproc | Wait-Process
                if ($myproc.ExitCode -ne 0)
                {
                    $LOGFILE="C:\skykick-install64.log"
                    MailMessage $EMAIL_TO $EMAIL_SUBJECT $EMAIL_BODY $LOGFILE
                    exit $myproc.ExitCode
                }
            }
            else 
            {
                $myproc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/lvoicewarmup C:\skykick-install32.log /i \\server.domain.tld\Software\Deployable\Skykick\SKOAx32.msi /q" -PassThru
                $myproc | Wait-Process
                if ($myproc.ExitCode -ne 0)
                {
                    $LOGFILE="C:\skykick-install32.log"
                    MailMessage $EMAIL_TO $EMAIL_SUBJECT $EMAIL_BODY $LOGFILE
                    exit $myproc.ExitCode
                }
            }
            exit 0
        }
        ## Present the fallback installer to the user if the user has a version of office we haven't accounted for. This installer will install the proper version automatically. However, there are no known silent switches for this installer.
        else 
        {
            $myproc = Start-Process -FilePath "\\server.domain.tld\Software\Deployable\Skykick\setup.exe" -PassThru
            $myproc | Wait-Process
            if ($myproc.ExitCode -ne 0)
            {
                $EMAIL_BODY="Graphical fallback installer failed with return code " + $myproc.ExitCode + ". Please investigate on the subject-named machine."
                MailMessage $EMAIL_TO $EMAIL_SUBJECT $EMAIL_BODY
                exit $myproc.ExitCode
            }
            exit 0
        }
    }
} catch [System.Exception] {
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [System.Windows.Forms.MessageBox]::Show("Please show this message to IT" + [Environment]::NewLine + [Environment]::NewLine + $_, "Skykick Deployment General Failure")
    exit -1
}
