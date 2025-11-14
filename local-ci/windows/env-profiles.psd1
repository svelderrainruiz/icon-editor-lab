@{
    Profiles = @(
        @{
            Name        = 'labview-2021-x64'
            DisplayName = 'LabVIEW 2021 (64-bit)'
            Requirements = @(
                @{
                    Type        = 'File'
                    Path        = 'C:\Program Files\National Instruments\LabVIEW 2021\LabVIEW.exe'
                    Description = 'LabVIEW 2021 (64-bit) executable'
                },
                @{
                    Type        = 'File'
                    Path        = 'C:\Program Files (x86)\National Instruments\Shared\LabVIEW CLI\LabVIEWCLI.exe'
                    Description = 'LabVIEW CLI executable'
                },
                @{
                    Type        = 'Command'
                    Command     = 'g-cli'
                    Description = 'G CLI'
                },
                @{
                    Type        = 'Directory'
                    Path        = '%ProgramData%\National Instruments'
                    Optional    = $true
                    Description = 'Shared National Instruments data directory'
                }
            )
        }
    )
}
