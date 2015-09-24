#requires -Version 2 -Modules CommonPSFunctions
<#
        .Synopsis
        Run NAV Tests and export result as NUnit xml file
        .DESCRIPTION
        RUN NAV Test through selected codeunit. Collect results from the SQL table
        and write them into NUnit xml file.
        .EXAMPLE
        Test-NAVDatabase -SQLServer localhost -SQLDb 'Demo Database NAV (9-0)' -NAVServerName localhost -NAVServerInstance DynamicsNAV90 -CodeunitId 130402 -OutTestFile 'D:\git\TFSTest\test-nav.xml'
#>
function Test-NAVDatabase 
{
    param(
        $SQLServer,
        $SQLDb,
        $NAVServerName,
        $NAVServerInstance,
        #If CompanyName is not used, first CRONUS company will be taken
        $CompanyName,
        $CodeunitId = 130402,
        $OutTestFile = ''
    )

    function Get-FirstCompanyName
    {
        param(
            $SQLServer,
            $SQLDb
        )
        $CompanyName = Get-SQLCommandResult -Server $SQLServer -Database $SQLDb -Command "select TOP 1 [Name] from [Company] where [Name] like 'CRONUS%'"
        return $CompanyName.Name
    }

    function Start-NAVTest
    {
        param(
            $RoleTailoredClientExePath,
            $NAVServerName,
            $NAVServerInstance,
            $CompanyName,
            $CodeunitId
        )
        if ($env:NAVServicePath -match '.*\\\d\d\\.*') 
        {
            $NavVersion = $Mateches[1]
        }
        $OrigConfigFile = Join-Path $env:ProgramData "Microsoft\Microsoft Dynamics NAV\$NavVersion\ClientUserSettings.config"
        $ConfigFile = Join-Path $env:Temp "ClientUserSettings$([guid]::NewGuid().ToString() -replace '[{}-]','').config"
        $config = [xml](Get-Content $OrigConfigFile)
        $Server=$config.configuration.appSettings.SelectSingleNode('add[@key="Server"]')
        $Server.value = $NAVServerName
        $Instance=$config.configuration.appSettings.SelectSingleNode('add[@key="ServerInstance"]')
        $Instance.value = $NAVServerInstance        
        $config.Save($ConfigFile)
        $null = & $RoleTailoredClientExePath -consolemode `
        -showNavigationPage:0 `
        -settings:"$ConfigFile"`
        "dynamicsnav://$NAVServerName/$NAVServerInstance/$CompanyName/RunCodeunit?Codeunit=$CodeunitId"
        Remove-Item -Path $ConfigFile
    }

    function Save-NAVTestResult 
    {
        param(
            $CompanyName,
            $SQLServer,
            $SQLDb,
            $ResultTableName,
            $OutFile
        )
        $MaxTestsPerFile = 100000
        $ActualOutFile = $OutFile
        $Command = "select * from [$CompanyName`$$ResultTableName]"
        $Result = Get-SQLCommandResult -Server $SQLServer -Database $SQLDb -Command $Command    
        $FileNo = 0
        $TestResults = [xml]'<?xml version="1.0" encoding="utf-8" standalone="no"?><test-run></test-run>'
        $TestRun = $TestResults['test-run']
        $TestRun.SetAttribute('id',0)
        $TestRun.SetAttribute('name','NAV Build Test')
        $TestRun.SetAttribute('run-date',(Get-Date -Format yyyy-MM-dd))
        $TestRun.SetAttribute('start-time',(Get-Date -Format hh:mm:ss))
        $TestRun.SetAttribute('testcasecount',0)
        $TestRun.SetAttribute('result','Passed')
        $TestRun.SetAttribute('passed',0)
        $TestRun.SetAttribute('total',0)
        $TestRun.SetAttribute('failed',0)
        $TestRun.SetAttribute('inconclusive',0)
        $TestRun.SetAttribute('skipped',0)
        $TestRun.SetAttribute('asserts',0)
                                                            
        ForEach ($line in $Result) 
        {
            $TestSuiteName = $line['Codeunit Name']
            $TestSuite = $TestRun.SelectSingleNode("/test-run/test-suite[@name='$TestSuiteName']")
            if ($TestSuite) 
            {

            }
            else 
            {
                $TestSuite = $TestResults.CreateElement('test-suite')
                $null = $TestRun.AppendChild($TestSuite)
                $TestSuite.SetAttribute('type','Assembly')
                $TestSuite.SetAttribute('name',"$TestSuiteName")
                $TestSuite.SetAttribute('status','Passed')
                $TestSuite.SetAttribute('testcasecount',0)
                $TestSuite.SetAttribute('result','Passed')
                $TestSuite.SetAttribute('passed',0)
                $TestSuite.SetAttribute('total',0)
                $TestSuite.SetAttribute('failed',0)
                $TestSuite.SetAttribute('inconclusive',0)
                $TestSuite.SetAttribute('skipped',0)
                $TestSuite.SetAttribute('asserts',0)
            }
            $TestSuite.SetAttribute('testcasecount',1+$TestSuite.GetAttribute('testcasecount'))
            $TestRun.SetAttribute('testcasecount',1+$TestRun.GetAttribute('testcasecount'))
            $TestCase = $TestResults.CreateElement('test-case')
            $null = $TestSuite.AppendChild($TestCase)
            #Passed,Failed,Inconclusive,Incomplete
            switch ($line['Result']) {
                0 
                {
                    $TestResult = 'Passed'
                    $TestSuite.SetAttribute('passed',1+$TestSuite.GetAttribute('passed'))
                    $TestRun.SetAttribute('passed',1+$TestRun.GetAttribute('passed'))
                }
                1 
                {
                    $TestResult = 'Failed'
                    $TestSuite.SetAttribute('status','Failed')
                    $TestRun.SetAttribute('status','Failed')
                    $TestSuite.SetAttribute('failed',1+$TestSuite.GetAttribute('failed'))
                    $TestRun.SetAttribute('failed',1+$TestRun.GetAttribute('failed'))
                    $Failure = $TestResults.CreateElement('failure')
                    $null = $TestCase.AppendChild($Failure)
                    $Message = $TestResults.CreateElement('message')
                    $null = $Failure.AppendChild($Message)
                    $Message.InnerText = $line['Error Message']
                    $CallStackData = Get-NAVBlobToString -CompressedByteArray $line['Call Stack']
                    $StackTrace = $TestResults.CreateElement('stack-trace')
                    $null = $Failure.AppendChild($StackTrace)
                    $StackTrace.InnerText = $CallStackData.Data
                }
                2 
                {
                    $TestResult = 'Inconclusive'
                    $TestSuite.SetAttribute('inconclusive',1+$TestSuite.GetAttribute('inconclusive'))
                    $TestRun.SetAttribute('inconclusive',1+$TestRun.GetAttribute('inconclusive'))
                }
                3 
                {
                    $TestResult = 'Incomplete'
                }
            }
            $TestCase.SetAttribute('id',"$($line['No_'])")
            $TestCase.SetAttribute('name',"$($TestSuiteName):$($line['Function Name'])")
            $TestCase.SetAttribute('result',$TestResult)
            if ($line['Execution Time'] -lt 0) 
            {
                $line['Execution Time'] = -$line['Execution Time']
            }
            $RunTime = [TimeSpan]::FromMilliseconds($line['Execution Time'])
            $TestCase.SetAttribute('time',$RunTime.ToString())
            
            #$TestCaseProps = $TestCase.AppendChild($TestResults.CreateElement('properties'))
            #$TestCaseProp = $TestCaseProps.AppendChild($TestResults.CreateElement('property'))
            #$TestCaseProp.SetAttribute('name','Category')            
            #$TestCaseProp.SetAttribute('value',"$($TestSuiteName)")
            #$TestCaseProp = $TestCaseProps.AppendChild($TestResults.CreateElement('property'))
            #$TestCaseProp.SetAttribute('name','Description')
            #$TestCaseProp.SetAttribute('value',"$($TestSuiteName)")
                        
            if ($TestRun.GetAttribute('testcasecount') -eq $MaxTestsPerFile) 
            {
                $TestResults.Save($ActualOutFile)
                $FileNo++
                $ActualOutFile = $OutFile.Insert($OutFile.LastIndexOf('.'),$FileNo)
                $TestResults = [xml]'<?xml version="1.0" encoding="utf-8" standalone="no"?><test-run></test-run>'
                $TestRun = $TestResults['test-run']
                $TestRun.SetAttribute('id',0)
                $TestRun.SetAttribute('name','NAV Build Test')
                $TestRun.SetAttribute('run-date',(Get-Date -Format yyyy-MM-dd))
                $TestRun.SetAttribute('start-time',(Get-Date -Format hh:mm:ss))
                $TestRun.SetAttribute('testcasecount',0)
                $TestRun.SetAttribute('result','Passed')
                $TestRun.SetAttribute('passed',0)
                $TestRun.SetAttribute('total',0)
                $TestRun.SetAttribute('failed',0)
                $TestRun.SetAttribute('inconclusive',0)
                $TestRun.SetAttribute('skipped',0)
                $TestRun.SetAttribute('asserts',0)
            }
        }
        $TestResults.Save($ActualOutFile)
    }
    #Fill table 130403 withcodeunits to run
    
    $ResultTableName = 'CAL Test Result'
    $ReplaceChars = '."\/%]['''

    #microsoft.Dynamics.Nav.Client.exe
    $RoleTailoredClientExePath = Join-Path -Path $env:NAVIdePath -ChildPath 'Microsoft.Dynamics.Nav.Client.exe'

    if (-not $CompanyName) 
    {
        $CompanyName = Get-FirstCompanyName -SQLServer $SQLServer -SQLDb $SQLDb
    }
    
    $DBCompanyName = $CompanyName
    for ($i = 0;$i -lt $ReplaceChars.Length;$i++) 
    {
        $DBCompanyName = $DBCompanyName.Replace($ReplaceChars[$i],'_')
    }
    #Import-Module (Get-NAVAdminModuleName) -Force
    
    Start-NAVTest -RoleTailoredClientExePath $RoleTailoredClientExePath -NavServerName $NAVServerName -NAVServerInstance $NAVServerInstance -CompanyName $CompanyName -CodeunitId $CodeunitId
    Save-NAVTestResult -CompanyName $DBCompanyName -SQLServer $SQLServer -SQLDb $SQLDb -ResultTable $ResultTableName -OutFile $OutTestFile
}
