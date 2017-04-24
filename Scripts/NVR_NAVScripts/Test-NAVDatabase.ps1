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
        $OutTestFile = '',
        [bool]$ExportOnly=$false,
        [bool]$ReportFailures=$true
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
        if ($env:NAVServicePath -match '.*\\(\d{2,3})\\.*') 
        {
            $NavVersion = $Matches[1]
        }
        $OrigConfigFile = Join-Path $env:ProgramData "Microsoft\Microsoft Dynamics NAV\$NavVersion\ClientUserSettings.config"
        $ConfigFile = Join-Path $env:Temp "ClientUserSettings$([guid]::NewGuid().ToString() -replace '[{}-]','').config"
        $config = [xml](Get-Content $OrigConfigFile)
        $Server=$config.configuration.appSettings.SelectSingleNode('add[@key="Server"]')
        $Server.value = $NAVServerName
        $Instance=$config.configuration.appSettings.SelectSingleNode('add[@key="ServerInstance"]')
        $Instance.value = $NAVServerInstance        
        $config.Save($ConfigFile)
        & $RoleTailoredClientExePath -consolemode `
        -showNavigationPage:0 `
        -settings:"$ConfigFile"`
        "dynamicsnav://$NAVServerName/$NAVServerInstance/$CompanyName/RunCodeunit?Codeunit=$CodeunitId" | Out-Null
        Remove-Item -Path $ConfigFile
    }

    function Save-NAVTestResultNunit 
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

    function Save-NAVTestResultTrx
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
        $Command = "select [No_],[Test Run No_],[Codeunit ID],[Codeunit Name],[Function Name],"+`
                    "[Platform],[Result],[Restore],[Execution Time],[Error Code],[Error Message],"+`
                    "[File],[Call Stack],[User ID], CONVERT(VARCHAR(50),[Start Time], 127) as [Start Time2],"+`
                    "CONVERT(VARCHAR(50),[Finish Time], 127) as [Finish Time2] from [$CompanyName`$$ResultTableName]"
        $SqlResult = Get-SQLCommandResult -Server $SQLServer -Database $SQLDb -Command $Command    
        $FileNo = 0
        $TestResults = [xml]('<?xml version="1.0" encoding="utf-8" standalone="no"?>'+
            '<TestRun>'+
            "<TestRunConfiguration name=`"NAV Automati Test Run`">"+
            '<Description>This is a default test run configuration for a local test run.</Description>'+
            '<TestTypeSpecific /></TestRunConfiguration>'+
            '<ResultSummary outcome="Passed">'+
            '<Counters total="0" executed="0" passed="0" error="0" failed="0" timeout="0" aborted="0" inconclusive="0" passedButRunAborted="0" notRunnable="0" notExecuted="0" disconnected="0" warning="0" completed="0" inProgress="0" pending="0" />'+
            '</ResultSummary>'+
            "<Times creation=`"$(Get-Date -Format o)`" queuing=`"$(Get-Date -Format o)`" start=`"`" finish=`"`" />"+
            '<TestSettings id="010e155f-ff0f-44f5-a83e-5093c2e8dcc4" name="Settings">'+
            '</TestSettings>'+
            '<TestDefinitions></TestDefinitions>'+
            '<TestLists>'+
            '<TestList name="Results Not in a List" id="8c84fa94-04c1-424b-9868-57a2d4851a1d" />'+
            '<TestList name="All Loaded Results" id="19431567-8539-422a-85d7-44ee4e166bda" />'+
            '</TestLists>'+
            '<TestEntries></TestEntries>'+
            '<Results></Results>'+
        '</TestRun>')
        $TestRun = $TestResults.SelectSingleNode('/TestRun')
        $TestRun.SetAttribute('name','NAV Tests')
        $TestRun.SetAttribute('xmlns','http://microsoft.com/schemas/VisualStudio/TeamTest/2010')
        $TestRunConfig=$TestResults.SelectSingleNode('/TestRun/TestRunConfiguration')
        $configid = [guid]::NewGuid() -replace '{}',''
        $TestRunConfig.SetAttribute('id',$configid)
        $testrunid = [guid]::NewGuid() -replace '{}',''
        $TestRun.SetAttribute('id',$testrunid)
        $TestDefinitions=$TestResults.SelectSingleNode('/TestRun/TestDefinitions')
        $TestEntries=$TestResults.SelectSingleNode('/TestRun/TestEntries')
        $Results = $TestResults.SelectSingleNode('/TestRun/Results')
        $ResultsSummary = $TestResults.SelectSingleNode('/TestRun/ResultSummary')                                              
        $Times = $TestResults.SelectNodes('/TestRun/Times')
        
        ForEach ($line in $SqlResult) 
        {
            $TestSuiteName = $line['Codeunit Name']
            $TestDefinition = $TestResults.CreateElement('UnitTest')
            $null = $TestDefinitions.AppendChild($TestDefinition)
            $id = [guid]::NewGuid() -replace '{}',''
            $FunctionName=$line['Codeunit ID'].ToString()+':'+$line['Function Name']
            $TestDefinition.SetAttribute('name',$FunctionName)
            $TestDefinition.SetAttribute('id',$id)
            $TestDefinition.SetAttribute('storage',"$OutFile")
            #$TestDefinition.SetAttribute('nammedCategory',"$TestSuiteName")
            #$Css = $TestResults.CreateElement('Css')
            #$null = $TestDefinition.AppendChild($Css)
            #$Css.SetAttribute('projectStructure','')
            #$Css.SetAttribute('iteration','')
            
            #$Owners = $TestResults.CreateElement('Owners')
            #$null = $TestDefinition.AppendChild($Owners)
            #$Owner = $TestResults.CreateElement('Owner')
            #$null = $Owners.AppendChild($Owner)
            #$Owner.SetAttribute('name',$env:USERNAME)
            $executionid= [guid]::NewGuid() -replace '{}',''
            $Execution = $TestResults.CreateElement('Execution')
            $null = $TestDefinition.AppendChild($Execution)
            $Execution.SetAttribute('id',$executionid)
            $TestMethod = $TestResults.CreateElement('TestMethod')
            $null = $TestDefinition.AppendChild($TestMethod)
            $TestMethod.SetAttribute('codeBase','COD'+$line['Codeunit ID'].ToString()+'.txt')
            #$TestMethod.SetAttribute('adapterTypeName','')
            $TestMethod.SetAttribute('className',$TestSuiteName)
            $TestMethod.SetAttribute('name',$FunctionName)
            $TestEntry = $TestResults.CreateElement('TestEntry')
            $null = $TestEntries.AppendChild($TestEntry)
            $TestEntry.SetAttribute('testId',$id)
            $TestEntry.SetAttribute('executionId',$executionid)
            $TestEntry.SetAttribute('testListId','8c84fa94-04c1-424b-9868-57a2d4851a1d')
            $Result = $TestResults.CreateElement('UnitTestResult')
            $null = $Results.AppendChild($Result)
            $Result.SetAttribute('executionId',$executionid)
            $Result.SetAttribute('testId',$id)
            $Result.SetAttribute('testName',$FunctionName)
            $Result.SetAttribute('computerName',$env:COMPUTERNAME)
            if ($line['Execution Time'] -lt 0) 
            {
                $line['Execution Time'] = -$line['Execution Time']
            }
            $RunTime = [TimeSpan]::FromMilliseconds($line['Execution Time'])
            $Result.SetAttribute('duration',$RunTime.ToString());
            $StartTime = $line['Start Time2']
            $EndTime = $line['Finish Time2']
            $Result.SetAttribute('startTime',$StartTime)
            $Result.SetAttribute('endTime',$EndTime)
            #Passed,Failed,Inconclusive,Incomplete
            $ResultsSummary.Counters.executed = (1+$ResultsSummary.Counters.executed).ToString()
            $ResultsSummary.Counters.total = (1+$ResultsSummary.Counters.total).ToString()
            if ($Times.GetAttribute('start') -eq '') {
                $Times.SetAttribute('start',$StartTime)
            }
            $Times.SetAttribute('finish',$EndTime)
            
            switch ($line['Result']) {
                0 
                {
                    $TestResult = 'Passed'
                    $ResultsSummary.Counters.completed = (1+$ResultsSummary.Counters.completed).ToString()
                    $ResultsSummary.Counters.passed = (1+$ResultsSummary.Counters.passed).ToString()
                }
                1 
                {
                    $TestResult = 'Failed'
                    $ResultsSummary.Counters.completed = (1+$ResultsSummary.Counters.completed).ToString()
                    $ResultsSummary.Counters.failed = (1+$ResultsSummary.Counters.failed).ToString()
                    $Output = $TestResults.CreateElement('Output')
                    $null = $Result.AppendChild($Output)
                    $ErrorInfo = $TestResults.CreateElement('ErrorInfo')
                    $null = $Output.AppendChild($ErrorInfo)
                    $Message = $TestResults.CreateElement('Message')
                    $null = $ErrorInfo.AppendChild($Message)
                    $Message.InnerText = $line['Error Message']
                    if ($line['Call Stack'] -and ($line['Call Stack'].ToString() -gt '')) {
                        $CallStackData = Get-NAVBlobToString -CompressedByteArray $line['Call Stack'] -ErrorAction SilentlyContinue
                        if ($CallStackData.Data)  {
                            $StackTrace = $TestResults.CreateElement('StackTrace')
                            $null = $ErrorInfo.AppendChild($StackTrace)
                            $StackTrace.InnerText = $CallStackData.Data
                        }
                    }
                    $ResultsSummary.SetAttribute('outcome','Failed')
                }
                2 
                {
                    $TestResult = 'Inconclusive'
                    $ResultsSummary.Counters.completed = (1+$ResultsSummary.Counters.completed).ToString()
                    $ResultsSummary.Counters.inconclusive = (1+$ResultsSummary.Counters.inconclusive).ToString()
                }
                3 
                {
                    #$TestResult = 'Incomplete'
                    $TestResult = 'inProgress'
                }
            }
            $Result.SetAttribute('outcome',$TestResult)
            $Result.SetAttribute('testListId','8c84fa94-04c1-424b-9868-57a2d4851a1d')
            $Result.SetAttribute('testType','13cdc9d9-ddb5-4fa4-a97d-d965ccfc6d4b')
        }
        #$TestRun.Times.SetAttribute('finish',(Get-Date -Format o).ToString())
        $TestResults.Save($ActualOutFile)
        if ($ReportFailures) 
        {
            if ($ResultsSummary.GetAttribute('outcome') -eq 'Failed') 
            {
                Write-Error "$($ResultsSummary.Counters.failed) tests of $($ResultsSummary.Counters.total) failed!"
            }
        }
    }
    
    function Save-NAVTestResultSummary
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
        $SqlResult = Get-SQLCommandResult -Server $SQLServer -Database $SQLDb -Command $Command    
        $FileNo = 0
        $TestResults = [xml]@"
<?xml version="1.0" encoding="utf-8"?>
<SummaryResult>
  <TestName>NAV Test Suite</TestName>
  <TestResult>Passed</TestResult>
  <InnerTests>
  </InnerTests>
</SummaryResult>
"@
           
        $Results = $TestResults.SelectSingleNode('/SummaryResult/InnerTests')
        $ResultsSummary = $TestResults.SelectSingleNode('/SummaryResult')                                              
        
        ForEach ($line in $SqlResult) 
        {
            $TestSuiteName = $line['Codeunit Name']
            $TestDefinition = $TestResults.CreateElement('InnerTest')
            $null = $Results.AppendChild($TestDefinition)
            $TestName = $TestResults.CreateElement('TestName')
            $null = $TestDefinition.AppendChild($TestName)
            $TestName.InnerText=$line['Function Name']
            
            switch ($line['Result']) {
                0 
                {
                    $TestResult = 'Passed'
                }
                1 
                {
                    $TestResult = 'Failed'
                    $Message = $TestResults.CreateElement('ErrorMessage')
                    $null = $TestDefinition.AppendChild($Message)
                    $Message.InnerText = $line['Error Message']
                    $SummaryOutcome = $TestResults.SelectSingleNode('/SummaryResult/TestResult')
                    $SummaryOutcome.InnerText = 'Failed'
                }
                2 
                {
                    $TestResult = 'Inconclusive'
                }
                3 
                {
                    $TestResult = 'Incomplete'
                }
            }
            $TestOutcome = $TestResults.CreateElement('TestResult')
            $null = $TestDefinition.AppendChild($TestOutcome)
            $TestOutcome.InnerText=$TestResult
        }
        $TestResults.Save($ActualOutFile)
    }
        #Fill table 130403 withcodeunits to run
    
    $ResultTableName = 'CAL Test Result'
    $ReplaceChars = '."\/%]['''

    #microsoft.Dynamics.Nav.Client.exe
    $RoleTailoredClientExePath = Join-Path -Path $env:NAVIdePath -ChildPath 'Microsoft.Dynamics.Nav.Client.x86.exe'
    if (-not (Test-Path -Path $RoleTailoredClientExePath)) {
        $RoleTailoredClientExePath = Join-Path -Path $env:NAVIdePath -ChildPath 'Microsoft.Dynamics.Nav.Client.exe'
    }

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
    if  ($ExportOnly) {
    } else {
        Start-NAVTest -RoleTailoredClientExePath $RoleTailoredClientExePath -NavServerName $NAVServerName -NAVServerInstance $NAVServerInstance -CompanyName $CompanyName -CodeunitId $CodeunitId
    }
    #Save-NAVTestResultTrx -CompanyName $DBCompanyName -SQLServer $SQLServer -SQLDb $SQLDb -ResultTable $ResultTableName -OutFile $OutTestFile
    Save-NAVTestResultTrx -CompanyName $DBCompanyName -SQLServer $SQLServer -SQLDb $SQLDb -ResultTable $ResultTableName -OutFile $OutTestFile
}
