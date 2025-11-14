@{
    Run = @{
        Path = @('tests')
        IncludeRegex = 'Tests?\.ps1$'
    }

    Filter = @{
        Tag        = @()
        ExcludeTag = @()
    }

    Output = @{
        Verbosity = 'Detailed'
    }

    TestResult = @{
        Enabled    = $false
        OutputPath = 'out/test-results/pester.xml'
        Format     = 'JUnitXml'
    }
}
