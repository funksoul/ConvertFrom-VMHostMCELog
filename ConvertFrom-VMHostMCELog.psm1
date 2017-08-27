function Read-Register {
    <#
    .SYNOPSIS
    Read values(bits) from a MSR(Model Specific Register).

    .DESCRIPTION
    Read values(bits) from a MSR(Model Specific Register).

    .PARAMETER Register
    A Register to read from.
    .PARAMETER StartIndex
    A start index. Should be greater than EndIndex.
    .PARAMETER EndIndex
    An end index. You don't have to use this parameter if you want to read just single bit.

    .EXAMPLE
    Read-Register $IA32_MCi_STATUS_MSR 63

    0


    ** Read single bit from the $IA32_MCi_STATUS_MSR register (ex. at index 63)

    .EXAMPLE
    Read-Register $IA32_MCi_STATUS_MSR 15 0

    101111011010011


    ** Read range of bits from the $IA32_MCi_STATUS_MSR register (ex. between index 15:0)

    .NOTES
    Author                      : Han Ho-Sung
    Author email                : funksoul@insdata.co.kr
    Version                     : 0.8
    Dependencies                :
    ===Tested Against Environment====
    ESXi Version                :
    PowerCLI Version            :
    PowerShell Version          : 5.1.14393.693
    #>

    Param(
        [Parameter(Mandatory=$true, Position=0)][String]$Register,
        [Parameter(Mandatory=$true, Position=1)][Int]$StartIndex,
        [Parameter(Mandatory=$false, Position=2)][Int]$EndIndex = -1
    )

    Process {
        if ($EndIndex -eq -1) {
            # Index validation check
            if (($StartIndex -ge 0) -and ($StartIndex -lt $Register.Length)) {
                $index = $Register.Length - 1 - $StartIndex
                return [String]$Register[$index]
            }
        }
        else {
            # Index validation check
            if ($StartIndex -gt $EndIndex) {
                if (($StartIndex -lt $Register.Length) -and ($EndIndex -ge 0)) {
                    $substring_start = $Register.Length - 1 - $StartIndex
                    $substring_size = $StartIndex - $EndIndex + 1
                    return [String]$Register.Substring($substring_start, $substring_size)
                }
            }
        }
    }
}

function ConvertFrom-VMHostCPUID {
    <#
    .SYNOPSIS
    Fetch CPUID information of given ESXi Host

    .DESCRIPTION
    CPUID instruction returns processor identification and feature information in the EAX, EBX, ECX, and EDX registers.
    The instruction's output is dependent on the contents of the EAX register upon execution (in some cases, ECX as well).
    ESXi provides subset of CPUID informations via esxcli.
    * CPUID information (Processor Signature: DisplayFamily_DisplayModel) can be utilized on incremental decoding of a MCE log.

    .EXAMPLE
    ConvertFrom-VMHostCPUID -VMHost vmhost.example.com

    Name                           Value
    ----                           -----
    CPUID_01H                      {EAX, ECX, EBX, EDX}
    CPUID_80000001H                {EAX, ECX, EBX, EDX}
    CPUID_80000008H                {EAX, ECX, EBX, EDX}
    CPUID_80000000H                {EAX, ECX, EBX, EDX}
    CPUID                          {80000000, 80000008, 8000000a, 80000001...}


    ** Fetch CPUID information from an ESXi Host

    .EXAMPLE
    ConvertFrom-VMHostCPUID -VMHost vmhost.example.com | %{ $_.CPUID_01H.EAX }

    Name                           Value
    ----                           -----
    Stepping ID                    BH
    DisplayFamily_DisplayModel     06_0FH
    Family ID                      06H
    Extended Model ID              0H
    Model ID                       0FH
    Processor Type                 Original OEM Processor
    Extended Family ID             00H


    ** INPUT EAX = 01H: Model, Family, Stepping Information

    .EXAMPLE
    ConvertFrom-VMHostCPUID -VMHost vmhost.example.com -ProcessorSignature
    06_0FH


    ** Read Processor Signature only


    .NOTES
    Author                      : Han Ho-Sung
    Author email                : funksoul@insdata.co.kr
    Version                     : 0.8
    Dependencies                :
    ===Tested Against Environment====
    ESXi Version                :
    PowerCLI Version            :
    PowerShell Version          : 5.1.14393.693
    #>

    Param(
        [Parameter(Mandatory=$true, Position=0)]$VMHost,
        [Parameter(Mandatory=$false)][Switch]$ProcessorSignature = $false
    )

    Begin {
        $ProcessorType = @{
            "00" = "Original OEM Processor"
            "01" = "Intel OverDrive(R) Processor"
            "10" = "Dual processor (not applicable to Intel486 processors)"
            "11" = "Intel reserved"
        }

        $BrandIndex = @{
            "00" = "This processor does not support the brand identification feature"
            "01" = "Intel(R) Celeron(R) processor"
            "02" = "Intel(R) Pentium(R) III processor"
            "03" = "Intel(R) Pentium(R) III Xeon(R) processor" # If processor signature = 000006B1h, then Intel(R) Celeron(R) processor
            "04" = "Intel(R) Pentium(R) III processor"
            "06" = "Mobile Intel(R) Pentium(R) III processor-M"
            "07" = "Mobile Intel(R) Celeron(R) processor1"
            "08" = "Intel(R) Pentium(R) 4 processor"
            "09" = "Intel(R) Pentium(R) 4 processor"
            "0A" = "Intel(R) Celeron(R) processor"
            "0B" = "Intel(R) Xeon(R) processor" # If processor signature = 00000F13h, then Intel(R) Xeon(R) processor MP
            "0C" = "Intel(R) Xeon(R) processor MP"
            "0E" = "Mobile Intel(R) Pentium(R) 4 processor-M" # If processor signature = 00000F13h, then Intel(R) Xeon(R) processor
            "0F" = "Mobile Intel(R) Celeron(R) processor"
            "11" = "Mobile Genuine Intel(R) processor"
            "12" = "Intel(R) Celeron(R) M processor"
            "13" = "Mobile Intel(R) Celeron(R) processor"
            "14" = "Intel(R) Celeron(R) processor"
            "15" = "Mobile Genuine Intel(R) processor"
            "16" = "Intel(R) Pentium(R) M processor"
            "17" = "Mobile Intel(R) Celeron(R) processor"
            "18" = "RESERVED"
        }

        $CPUID = @{}

        $CPUID_01H = [ordered]@{
            "EAX" = [ordered]@{
                "Stepping ID" = $null
                "Model ID" = $null
                "Family ID" = $null
                "Processor Type" = $null
                "Extended Model ID" = $null
                "Extended Family ID" = $null
                "DisplayFamily_DisplayModel" = $null
            }
            "EBX" = [ordered]@{
                "Brand Index" = $null # Bits 07 - 00: Brand Index.
                "CFLUSH line size" = $null # Bits 15 - 08: CLFLUSH line size (Value ∗ 8 = cache line size in bytes; used also by CLFLUSHOPT).
                "Maximum number of addressable IDs for logical processors in this physical package" = $null # Bits 23 - 16: Maximum number of addressable IDs for logical processors in this physical package*.
                "Initial APIC ID" = $null # Bits 31 - 24: Initial APIC ID.
            }
            "ECX" = [ordered]@{
                # ECX Feature Information (see Figure 3-7 and Table 3-10).
                "SSE3" = $null # Streaming SIMD Extensions 3 (SSE3).
                "PCLMULQDQ" = $null # Carryless Multiplication
                "DTES64" = $null # 64-bit DS Area.
                "MONITOR" = $null # MONITOR/MWAIT.
                "DS-CPL" = $null # CPL Qualified Debug Store.
                "VMX" = $null # Virtual Machine Extensions.
                "SMX" = $null # Safer Mode Extensions.
                "EIST" = $null # Enhanced Intel SpeedStep® technology.
                "TM2" = $null # Thermal Monitor 2.
                "SSSE3" = $null # Supplemental Streaming SIMD Extensions 3 (SSSE3).
                "CNXT-ID" = $null # L1 Context ID.
                "SDBG" = $null
                "FMA" = $null # Fused Multiply Add
                "CMPXCHG16B" = $null # CMPXCHG16B Available.
                "xTPR Update Control" = $null # xTPR Update Control
                "PDCM" = $null # Perfmon and Debug Capability.
                "PCID" = $null # Process-context identifiers.
                "DCA" = $null # Direct Cache Access
                "SSE4.1" = $null
                "SSE4.2" = $null
                "x2APIC" = $null
                "MOVBE" = $null
                "POPCNT" = $null
                "TSC-Deadline" = $null
                "AESNI" = $null
                "XSAVE" = $null
                "OSXSAVE" = $null
                "AVX" = $null
                "F16C" = $null
                "RDRAND" = $null
            }
            "EDX" = [ordered]@{
                # EDX Feature Information (see Figure 3-8 and Table 3-11).
                "FPU" = $null # Floating Point Unit On-Chip.
                "VME" = $null # Virtual 8086 Mode Enhancements.
                "DE" = $null # Debugging Extensions.
                "PSE" = $null # Page Size Extension.
                "TSC" = $null # Time Stamp Counter. 
                "MSR" = $null # Model Specific Registers RDMSR and WRMSR Instructions.
                "PAE" = $null # Physical Address Extension.
                "MCE" = $null # Machine Check Exception.
                "CX8" = $null # CMPXCHG8B Instruction.
                "APIC" = $null # APIC On-Chip.
                "SEP" = $null # SYSENTER and SYSEXIT Instructions.
                "MTRR" = $null # Memory Type Range Registers.
                "PGE" = $null # Page Global Bit.
                "MCA" = $null # Machine Check Architecture.
                "CMOV" = $null # Conditional Move Instructions.
                "PAT" = $null # Page Attribute Table.
                "PSE-36" = $null # 36-Bit Page Size Extension.
                "PSN" = $null # Processor Serial Number.
                "CLFSH" = $null # CLFLUSH Instruction.
                "DS" = $null # Debug Store.
                "ACPI" = $null # Thermal Monitor and Software Controlled Clock Facilities.
                "MMX" = $null # Intel MMX Technology.
                "FXSR" = $null # FXSAVE and FXRSTOR Instructions.
                "SSE" = $null # SSE.
                "SSE2" = $null # SSE2.
                "SS" = $null # Self Snoop.
                "HTT" = $null # Max APIC IDs reserved field is Valid.
                "TM" = $null # Thermal Monitor.
                "PBE" = $null # Pending Break Enable.
            }
        }

        $CPUID_80000000H = [ordered]@{
            "EAX" = [ordered]@{
                "Maximum Input Value for Extended Function CPUID Information" = $null
            }
            "EBX" = [ordered]@{
                # Reserved.
            }
            "ECX" = [ordered]@{
                # Reserved.
            }
            "EDX" = [ordered]@{
                # Reserved.
            }
        }

        $CPUID_80000001H = [ordered]@{
            "EAX" = [ordered]@{
                # Extended Processor Signature and Feature Bits.
            }
            "EBX" = [ordered]@{
                # Reserved.
            }
            "ECX" = [ordered]@{
                "LAHF/SAHF" = $null # Bit 00: LAHF/SAHF available in 64-bit mode.
                "LZCNT" = $null # Bit 05
                "PREFETCHW" = $null # Bit 08
            }
            "EDX" = [ordered]@{
                "SYSCALL/SYSRET" = $null # Bit 11: SYSCALL/SYSRET available in 64-bit mode.
                "XD" = $null # Bit 20: Execute Disable Bit available.
                "GBPAGE" = $null # Bit 26: 1-GByte pages are available if 1.
                "RDTSCP/IA32_TSC_AUX" = $null # Bit 27: RDTSCP and IA32_TSC_AUX are available if 1.
                "INTEL64" = $null # Bit 29: Intel® 64 Architecture available if 1.
            }
        }

        $CPUID_80000008H = [ordered]@{
            "EAX" = [ordered]@{
                "Physical Address Bits" = $null # Bits 07 - 00: #Physical Address Bits*.
                "Linear Address Bits" = $null # Bits 15 - 08: #Linear Address Bits.
            }
            "EBX" = [ordered]@{
                # Reserved.
            }
            "ECX" = [ordered]@{
                # Reserved.
            }
            "EDX" = [ordered]@{
                # Reserved.
            }
        }

        $Supported = @{
            "0" = "No"
            "1" = "Yes"
        }
    }

    Process {
        # Fetch ESXi CPUID information via esxcli (processor #0)
        Try {
            $esxcli = Get-EsxCli -V2 -VMHost $VMHost
            $arguments = $esxcli.hardware.cpu.cpuid.get.CreateArgs()
            $arguments.cpu = 0
            $esxcli.hardware.cpu.cpuid.get.Invoke($arguments) | ForEach-Object {
                $CPUID.Add(("{0:x}" -f [Int64]$_.Level), @{"EAX" = $_.EAX; "EBX" = $_.EBX; "ECX" = $_.ECX; "EDX" = $_.EDX})
            }
        }
        Catch [System.Management.Automation.ParameterBindingException] {
            $esxcli = Get-EsxCli -VMHost $VMHost
            $esxcli.hardware.cpu.cpuid.get(0) | ForEach-Object {
                $CPUID.Add(("{0:x}" -f [Int64]$_.Level), @{"EAX" = $_.EAX; "EBX" = $_.EBX; "ECX" = $_.ECX; "EDX" = $_.EDX})
            }
        }
        Catch {
            Write-Warning "Could not fetch ESXi CPUID information via esxcli."
            return
        }

        # Decode 01H/EAX
        $CPUID_01H_EAX_MSR = [System.Convert]::ToString($CPUID."1".EAX, 2).PadLeft(32,"0")
        $CPUID_01H.EAX."Stepping ID" = "{0:X}H" -f [System.Convert]::ToInt16((Read-Register $CPUID_01H_EAX_MSR 3 0), 2)
        $CPUID_01H.EAX."Model ID" = "{0:X2}H" -f [System.Convert]::ToInt16((Read-Register $CPUID_01H_EAX_MSR 7 4), 2)
        $CPUID_01H.EAX."Family ID" = "{0:X2}H" -f [System.Convert]::ToInt16((Read-Register $CPUID_01H_EAX_MSR 11 8), 2)
        $CPUID_01H.EAX."Processor Type" = $ProcessorType.(Read-Register $CPUID_01H_EAX_MSR 13 12)
        $CPUID_01H.EAX."Extended Model ID" = "{0:X}H" -f [System.Convert]::ToInt16((Read-Register $CPUID_01H_EAX_MSR 19 16), 2)
        $CPUID_01H.EAX."Extended Family ID" = "{0:X2}H" -f [System.Convert]::ToInt16((Read-Register $CPUID_01H_EAX_MSR 27 20), 2)

        # Determine DisplayFamily_DisplayModel
        if ($CPUID_01H.EAX."Family ID" -ne "0FH") { # Family ID
            $DisplayFamily = "{0:X2}" -f [System.Convert]::ToInt16((Read-Register $CPUID_01H_EAX_MSR 11 8), 2)
        }
        else { # (Extended Family ID << 4) + Family ID
            $DisplayFamily = "{0:X}" -f [System.Convert]::ToInt16((Read-Register $CPUID_01H_EAX_MSR 27 20), 2) + `
                "{0:X}" -f [System.Convert]::ToInt16((Read-Register $CPUID_01H_EAX_MSR 11 8), 2)
        }
        if (($CPUID_01H.EAX."Family ID" -eq "06H") -or ($CPUID_01H.EAX."Family ID" -eq "0FH")) { # (Extended_Model_ID << 4) + Model_ID
            $DisplayModel = "{0:X}" -f [System.Convert]::ToInt16((Read-Register $CPUID_01H_EAX_MSR 19 16), 2) + `
                "{0:X}H" -f [System.Convert]::ToInt16((Read-Register $CPUID_01H_EAX_MSR 7 4), 2)
        }
        else { # Model ID
            $DisplayModel = "{0:X2}H" -f [System.Convert]::ToInt16((Read-Register $CPUID_01H_EAX_MSR 7 4), 2)
        }
        $CPUID_01H.EAX.DisplayFamily_DisplayModel = $DisplayFamily + "_" + $DisplayModel

        # Decode 01H/EBX
        # Starting with processor signature family ID = 0FH, model = 03H, brand index method is no longer supported.
        # 0F_03H: Intel Xeon (Nocona/Prescott) Series Processor
        # https://software.intel.com/en-us/articles/intel-architecture-and-processor-identification-with-cpuid-model-and-family-numbers
        $CPUID_01H_EBX_MSR = [System.Convert]::ToString($CPUID."1".EBX, 2).PadLeft(32,"0")
        $CPUID_01H.EBX."Brand Index" = $BrandIndex.("{0:X2}" -f [System.Convert]::ToInt16((Read-Register $CPUID_01H_EBX_MSR 7 0), 2))
        $CPUID_01H.EBX."CFLUSH line size" = [System.Convert]::ToInt16((Read-Register $CPUID_01H_EBX_MSR 15 8), 2)
        $CPUID_01H.EBX."Maximum number of addressable IDs for logical processors in this physical package" = [System.Convert]::ToInt16((Read-Register $CPUID_01H_EBX_MSR 23 16), 2)
        $CPUID_01H.EBX."Initial APIC ID" = [System.Convert]::ToInt16((Read-Register $CPUID_01H_EBX_MSR 31 24), 2)

        # Brand Index exceptions
        if (($CPUID_01H.EBX."Brand Index" -eq "Intel(R) Pentium(R) III Xeon(R) processor") `
            -and ("{0:X8}h" -f [System.Convert]::ToInt32($CPUID_01H_EAX_MSR, 2) -eq "000006B1h")) {
                $CPUID_01H.EBX."Brand Index" = "Intel(R) Celeron(R) processor"
        }
        if (($CPUID_01H.EBX."Brand Index" -eq "Intel(R) Xeon(R) processor") `
            -and ("{0:X8}h" -f [System.Convert]::ToInt32($CPUID_01H_EAX_MSR, 2) -eq "00000F13h")) {
                $CPUID_01H.EBX."Brand Index" = "Intel(R) Xeon(R) processor MP"
        }
        if (($CPUID_01H.EBX."Brand Index" -eq "Mobile Intel(R) Pentium(R) 4 processor-M") `
            -and ("{0:X8}h" -f [System.Convert]::ToInt32($CPUID_01H_EAX_MSR, 2) -eq "00000F13h")) {
                $CPUID_01H.EBX."Brand Index" = "Intel(R) Xeon(R) processor"
        }

        # Decode 01H/ECX
        $CPUID_01H_ECX_MSR = [System.Convert]::ToString($CPUID."1".ECX, 2).PadLeft(32,"0")
        if ($CPUID_01H_ECX_MSR.Length -eq 32) {
            $CPUID_01H.ECX."SSE3" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 0)
            $CPUID_01H.ECX."PCLMULQDQ" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 1)
            $CPUID_01H.ECX."DTES64" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 2)
            $CPUID_01H.ECX."MONITOR" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 3)
            $CPUID_01H.ECX."DS-CPL" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 4)
            $CPUID_01H.ECX."VMX" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 5)
            $CPUID_01H.ECX."SMX" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 6)
            $CPUID_01H.ECX."EIST" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 7)
            $CPUID_01H.ECX."TM2" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 8)
            $CPUID_01H.ECX."SSSE3" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 9)
            $CPUID_01H.ECX."CNXT-ID" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 10)
            $CPUID_01H.ECX."SDBG" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 11)
            $CPUID_01H.ECX."FMA" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 12)
            $CPUID_01H.ECX."CMPXCHG16B" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 13)
            $CPUID_01H.ECX."xTPR Update Control" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 14)
            $CPUID_01H.ECX."PDCM" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 15)
            $CPUID_01H.ECX."PCID" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 17)
            $CPUID_01H.ECX."DCA" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 18)
            $CPUID_01H.ECX."SSE4.1" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 19)
            $CPUID_01H.ECX."SSE4.2" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 20)
            $CPUID_01H.ECX."x2APIC" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 21)
            $CPUID_01H.ECX."MOVBE" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 22)
            $CPUID_01H.ECX."POPCNT" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 23)
            $CPUID_01H.ECX."TSC-Deadline" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 24)
            $CPUID_01H.ECX."AESNI" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 25)
            $CPUID_01H.ECX."XSAVE" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 26)
            $CPUID_01H.ECX."OSXSAVE" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 27)
            $CPUID_01H.ECX."AVX" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 28)
            $CPUID_01H.ECX."F16C" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 29)
            $CPUID_01H.ECX."RDRAND" = $Supported.(Read-Register $CPUID_01H_ECX_MSR 30)
        }

        # Decode 01H/EDX
        $CPUID_01H_EDX_MSR = [System.Convert]::ToString($CPUID."1".EDX, 2).PadLeft(32,"0")
        if ($CPUID_01H_EDX_MSR.Length -eq 32) {
            $CPUID_01H.EDX."FPU" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 0)
            $CPUID_01H.EDX."VME" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 1)
            $CPUID_01H.EDX."DE" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 2)
            $CPUID_01H.EDX."PSE" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 3)
            $CPUID_01H.EDX."TSC" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 4)
            $CPUID_01H.EDX."MSR" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 5)
            $CPUID_01H.EDX."PAE" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 6)
            $CPUID_01H.EDX."MCE" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 7)
            $CPUID_01H.EDX."CX8" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 8)
            $CPUID_01H.EDX."APIC" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 9)
            $CPUID_01H.EDX."SEP" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 11)
            $CPUID_01H.EDX."MTRR" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 12)
            $CPUID_01H.EDX."PGE" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 13)
            $CPUID_01H.EDX."MCA" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 14)
            $CPUID_01H.EDX."CMOV" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 15)
            $CPUID_01H.EDX."PAT" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 16)
            $CPUID_01H.EDX."PSE-36" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 17)
            $CPUID_01H.EDX."PSN" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 18)
            $CPUID_01H.EDX."CLFSH" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 19)
            $CPUID_01H.EDX."DS" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 21)
            $CPUID_01H.EDX."ACPI" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 22)
            $CPUID_01H.EDX."MMX" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 23)
            $CPUID_01H.EDX."FXSR" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 24)
            $CPUID_01H.EDX."SSE" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 25)
            $CPUID_01H.EDX."SSE2" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 26)
            $CPUID_01H.EDX."SS" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 27)
            $CPUID_01H.EDX."HTT" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 28)
            $CPUID_01H.EDX."TM" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 29)
            $CPUID_01H.EDX."PBE" = $Supported.(Read-Register $CPUID_01H_EDX_MSR 31)

            # CPUID.1.EBX."Maximum number of addressable IDs for logical processors in this physical package"[bits 23:16] field
            # is only valid if # CPUID.1.EDX.HTT[bit 28]= 1.
            if ($CPUID_01H.EDX."HTT" -eq "Yes") {
                [String]$CPUID_01H.EBX."Maximum number of addressable IDs for logical processors in this physical package" += " (valid)"
            }
            else {
                [String]$CPUID_01H.EBX."Maximum number of addressable IDs for logical processors in this physical package" += " (invalid)"
            }
        }

        # Decode 80000000H/EAX
        $CPUID_80000000H_EAX_MSR = [System.Convert]::ToString($CPUID."80000000".EAX, 2).PadLeft(32,"0")
        if ($CPUID_80000000H_EAX_MSR.Length -eq 32) {
            $CPUID_80000000H.EAX."Maximum Input Value for Extended Function CPUID Information" = "{0:X8}" -f [System.Convert]::ToInt64((Read-Register $CPUID_80000000H_EAX_MSR 31 0), 2)
        }

        # Decode 80000001H/ECX
        $CPUID_80000001H_ECX_MSR = [System.Convert]::ToString($CPUID."80000001".ECX, 2).PadLeft(32,"0")
        if ($CPUID_80000001H_ECX_MSR.Length -eq 32) {
            $CPUID_80000001H.ECX."LAHF/SAHF" = $Supported.(Read-Register $CPUID_80000001H_ECX_MSR 0)
            $CPUID_80000001H.ECX."LZCNT" = $Supported.(Read-Register $CPUID_80000001H_ECX_MSR 5)
            $CPUID_80000001H.ECX."PREFETCHW" = $Supported.(Read-Register $CPUID_80000001H_ECX_MSR 8)
        }

        # Decode 80000001H/EDX
        $CPUID_80000001H_EDX_MSR = [System.Convert]::ToString($CPUID."80000001".EDX, 2).PadLeft(32,"0")
        if ($CPUID_80000001H_EDX_MSR.Length -eq 32) {
            $CPUID_80000001H.EDX."SYSCALL/SYSRET" = $Supported.(Read-Register $CPUID_80000001H_EDX_MSR 11)
            $CPUID_80000001H.EDX."XD" = $Supported.(Read-Register $CPUID_80000001H_EDX_MSR 20)
            $CPUID_80000001H.EDX."GBPAGE" = $Supported.(Read-Register $CPUID_80000001H_EDX_MSR 26)
            $CPUID_80000001H.EDX."RDTSCP/IA32_TSC_AUX" = $Supported.(Read-Register $CPUID_80000001H_EDX_MSR 27)
            $CPUID_80000001H.EDX."INTEL64" = $Supported.(Read-Register $CPUID_80000001H_EDX_MSR 29)
        }

        # Decode 80000008H/EAX
        $CPUID_80000008H_EAX_MSR = [System.Convert]::ToString($CPUID."80000008".EAX, 2).PadLeft(32,"0")
        if ($CPUID_80000008H_EAX_MSR.Length -eq 32) {
            $CPUID_80000008H.EAX."Physical Address Bits" = [System.Convert]::ToInt16((Read-Register $CPUID_80000008H_EAX_MSR 7 0), 2)
            $CPUID_80000008H.EAX."Linear Address Bits" = [System.Convert]::ToInt16((Read-Register $CPUID_80000008H_EAX_MSR 15 8), 2)
        }
    }

    End {
        if ($CPUID.Count) {
            if ($ProcessorSignature) {
                return $CPUID_01H.EAX.DisplayFamily_DisplayModel
            }
            else {
                return [ordered]@{
                    "CPUID" = $CPUID
                    "CPUID_01H" = $CPUID_01H
                    "CPUID_80000000H" = $CPUID_80000000H
                    "CPUID_80000001H" = $CPUID_80000001H
                    "CPUID_80000008H" = $CPUID_80000008H
                }
            }
        }
    }
}

function ConvertFrom-IA32_MCG_CAP {
    <#
    .SYNOPSIS
    Decode IA32_MCG_CAP MSR. (Model Specific Register)

    .DESCRIPTION
    The IA32_MCG_CAP MSR is a read-only register that provides information about the machine-check architecture of the processor.
    ESXi dumps IA32_MCG_CAP MSR when it boots.

    * ESXi 5.x, 6.x
        [root@vmhost:~] zcat /var/log/boot.gz | grep MCG_CAP
        0:00:00:07.008 cpu0:32768)MCE: 1480: Detected 9 MCE banks. MCG_CAP MSR:0x1c09

    .PARAMETER MSR
    IA32_MCG_CAP MSR (in hex)

    .EXAMPLE
    ConvertFrom-IA32_MCG_CAP 0x1c09

    Name                           Value
    ----                           -----
    MCG_Count                      9
    MCG_CTL_P                      0
    MCG_EXT_P                      0
    MCG_CMCI_P                     1
    MCG_TES_P                      1
    MCG_SER_P                      0
    MCG_EMC_P                      0
    MCG_ELOG_P                     0
    MCG_LMCE_P                     0

    .NOTES
    Author                      : Han Ho-Sung
    Author email                : funksoul@insdata.co.kr
    Version                     : 0.8
    Dependencies                :
    ===Tested Against Environment====
    ESXi Version                :
    PowerCLI Version            :
    PowerShell Version          : 5.1.14393.693
    #>

    Param(
        [Parameter(Mandatory=$true, Position=0)][Int32]$MSR
    )

    Begin {
        $IA32_MCG_CAP = [ordered]@{
            "MCG_Count" = $null # bits 7:0 - number of hardware unit error-reporting banks available
            "MCG_CTL_P" = $null # bit 8 - control MSR present
            "MCG_EXT_P" = $null # bit 9 - extended MSRs present
            "MCG_CMCI_P" = $null # bit 10 - Corrected MC error counting/signaling extension present
            "MCG_TES_P" = $null # bit 11 - threshold-based error status present
            # "MCG_EXT_CNT" = $null # bits 23:16 - the number of extended machine-check state registers present (will be added later, on demand)
            "MCG_SER_P" = $null # bit 24 - software error recovery support present
            "MCG_EMC_P" = $null # bit 25 - Enhanced Machine Check Capability
            "MCG_ELOG_P" = $null # bit 26 - extended error logging
            "MCG_LMCE_P" = $null # bit 27 - local machine check exception
        }
    }

    Process {
        # Decode IA32_MCG_CAP MSR
        $IA32_MCG_CAP_MSR = ([System.Convert]::ToString($MSR, 2)).PadLeft(64, "0")
        $IA32_MCG_CAP.MCG_Count = [System.Convert]::ToInt16((Read-Register $IA32_MCG_CAP_MSR 7 0), 2)
        $IA32_MCG_CAP.MCG_CTL_P = Read-Register $IA32_MCG_CAP_MSR 8
        $IA32_MCG_CAP.MCG_EXT_P = Read-Register $IA32_MCG_CAP_MSR 9
        $IA32_MCG_CAP.MCG_CMCI_P = Read-Register $IA32_MCG_CAP_MSR 10
        $IA32_MCG_CAP.MCG_TES_P = Read-Register $IA32_MCG_CAP_MSR 11
        if ($IA32_MCG_CAP.MCG_EXT_P -eq "1") {
            $IA32_MCG_CAP.Add("MCG_EXT_CNT", [System.Convert]::ToInt16((Read-Register $IA32_MCG_CAP_MSR 23 16), 2))
        }
        $IA32_MCG_CAP.MCG_SER_P = Read-Register $IA32_MCG_CAP_MSR 24
        $IA32_MCG_CAP.MCG_EMC_P = Read-Register $IA32_MCG_CAP_MSR 25
        $IA32_MCG_CAP.MCG_ELOG_P = Read-Register $IA32_MCG_CAP_MSR 26
        $IA32_MCG_CAP.MCG_LMCE_P = Read-Register $IA32_MCG_CAP_MSR 27
    }

    End {
        return $IA32_MCG_CAP
    }
}

function ConvertFrom-VMHostMCELog {
    <#
    .SYNOPSIS
    Decode MCE(Machine Check Exception) log entry of the ESXi vmkernel.log.

    .DESCRIPTION
    The machine check architecture is a mechanism within a CPU to detect and report hardware issues. When a problem is detected, a Machine Check Exception (MCE) is thrown.
    MCE consists of a set of model-specific registers (MSRs) that are used to set up machine checking and additional banks of MSRs used for recording errors that are detected.
    This Cmdlet reads MSRs from the vmkernel.log and decodes its contents as much as possible.
    * IA32_MCG_CAP MSR and Processor Signature is required (Cmdlets are provided separately - ConvertFrom-IA32_MCG_CAP and ConvertFrom-VMHostCPUID)
    * Only Intel(R) Processors are supported.

    .EXAMPLE
    Get-Content vmkernel.log | ConvertFrom-VMHostMCELog -IA32_MCG_CAP 0x1c09 -ProcessorSignature 06_0FH

    .EXAMPLE
    Get-Content vmkernel.log | ConvertFrom-VMHostMCELog -IA32_MCG_CAP (ConvertFrom-IA32_MCG_CAP 0x1c09) -ProcessorSignature (ConvertFrom-VMHostCPUID vmhost.example.com -ProcessorSignature)

    .EXAMPLE
    "2017-07-07T18:25:27.441Z cpu2:36681)MCE: 190: cpu1: bank3: status=0x9020000f0120100e: (VAL=1, OVFLW=0, UC=1, EN=1, PCC=1, S=0, AR=0), Addr:0x0 (invalid), Misc:0x0 (invalid)" | ConvertFrom-VMHostMCELog -IA32_MCG_CAP 0x1c09 -ProcessorSignature 06_0FH -Verbose

    VERBOSE: Processor Signature: 06_0FH
    VERBOSE: Contents of IA32_MCG_CAP:
    VERBOSE:   => MCG_Count   9 (bits 7:0   - number of hardware unit error-reporting banks available
    VERBOSE:   => MCG_CTL_P   0 (bit 8      - control MSR present
    VERBOSE:   => MCG_EXT_P   0 (bit 9      - extended MSRs present
    VERBOSE:   => MCG_CMCI_P  1 (bit 10     - Corrected MC error counting/signaling extension present
    VERBOSE:   => MCG_TES_P   1 (bit 11     - threshold-based error status present
    VERBOSE:   => MCG_SER_P   0 (bit 24     - software error recovery support present
    VERBOSE:   => MCG_EMC_P   0 (bit 25     - Enhanced Machine Check Capability
    VERBOSE:   => MCG_ELOG_P  0 (bit 26     - extended error logging
    VERBOSE:   => MCG_LMCE_P  0 (bit 27     - local machine check exception

    Id                                           : 0
    Timestamp                                    : 2017-07-07T18:25:27.441Z
    cpu                                          : 1
    bank                                         : 3
    IA32_MCi_STATUS                              : 0x9020000f0120100e
    IA32_MCi_MISC                                : 0x0
    IA32_MCi_ADDR                                : 0x0
    VAL                                          : 1
    OVER                                         : 0
    UC                                           : 0
    EN                                           : 1
    MISCV                                        : 0
    ADDRV                                        : 0
    PCC                                          : 0
    MCA Error Type                               : Compound
    MCA Error Code                               : Generic Cache Hierarchy
    MCA Error Interpretation                     : Generic cache hierarchy error
    MCA Error Meaning                            : Generic Cache Hierarchy / Level 2
    Correction Report Filtering                  : corrected
    Model Specific Errors                        :
    Reserved, Error Status and Other Information : {Corrected_Error_Count, Threshold-Based_Error_Status}
    UCR Error Classification                     :
    Address Mode                                 :
    Recoverable Address LSB                      :
    Address Valid                                :
    Address GiB                                  :
    Incremental Decoding Information             : No


    ** You can copy & paste a line from vmkernel.log directly

    .NOTES
    Author                      : Han Ho-Sung
    Author email                : funksoul@insdata.co.kr
    Version                     : 0.8
    Dependencies                :
    ===Tested Against Environment====
    ESXi Version                : 5.x, 6.0
    PowerCLI Version            :
    PowerShell Version          : 5.1.14393.693

    .LINK
    Decoding Machine Check Exception (MCE) output after a purple screen error (1005184)
    https://kb.vmware.com/kb/1005184
    Intel(R) 64 and IA-32 Architectures Software Developer's Manual:
    https://software.intel.com/en-us/articles/intel-sdm
    Intel Architecture and Processor Identification With CPUID Model and Family Numbers
    https://software.intel.com/en-us/articles/intel-architecture-and-processor-identification-with-cpuid-model-and-family-numbers
    #>

    Param (
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)][AllowEmptyString()][String[]]$InputObject,
        [Parameter(Mandatory=$true)]$IA32_MCG_CAP,
        [Parameter(Mandatory=$true)][String]$ProcessorSignature
    )

    Begin {
        $IA32_MCi_STATUS_Sub_Fields = @{
            "mca_error" = @{
                "TT" = @{ # Encoding of Transaction Type (TT) sub-field
                    "00" = @{"Mnemonic" = "I"; "Transaction_Type" = "Instruction"}
                    "01" = @{"Mnemonic" = "D"; "Transaction_Type" = "Data"}
                    "10" = @{"Mnemonic" = "G"; "Transaction_Type" = "Generic"}
                }
                "LL" = @{ # Encoding of Memory Hierarchy Level (LL) sub-field
                    "00" = @{"Mnemonic" = "L0"; "Hierarchy_Level" = "Level 0"}
                    "01" = @{"Mnemonic" = "L1"; "Hierarchy_Level" = "Level 1"}
                    "10" = @{"Mnemonic" = "L2"; "Hierarchy_Level" = "Level 2"}
                    "11" = @{"Mnemonic" = "LG"; "Hierarchy_Level" = "Generic"}
                }
                "MMM" = @{ # Encoding of memory transaction type (MMM) sub-field
                    "000" = @{"Mnemonic" = "GEN"; "Transaction" = "Generic undefined request"}
                    "001" = @{"Mnemonic" = "RD"; "Transaction" = "Memory read error"}
                    "010" = @{"Mnemonic" = "WR"; "Transaction" = "Memory write error"}
                    "011" = @{"Mnemonic" = "AC"; "Transaction" = "Address/Command Error"}
                    "100" = @{"Mnemonic" = "MS"; "Transaction" = "Memory Scrubbing Error"}
                    "101" = @{"Mnemonic" = "RSVD"; "Transaction" = "Reserved"} # No Corresponding Mnemonic
                    "110" = @{"Mnemonic" = "RSVD"; "Transaction" = "Reserved"} # No Corresponding Mnemonic
                    "111" = @{"Mnemonic" = "RSVD"; "Transaction" = "Reserved"} # No Corresponding Mnemonic
                }
                "RRRR" = @{ # Encoding of Request (RRRR) sub-field
                    "0000" = @{"Mnemonic" = "ERR"; "Request_Type" = "Generic Error"}
                    "0001" = @{"Mnemonic" = "RD"; "Request_Type" = "Generic Read"}
                    "0010" = @{"Mnemonic" = "WR"; "Request_Type" = "Generic Write"}
                    "0011" = @{"Mnemonic" = "DRD"; "Request_Type" = "Data Read"}
                    "0100" = @{"Mnemonic" = "DWR"; "Request_Type" = "Data Write"}
                    "0101" = @{"Mnemonic" = "IRD"; "Request_Type" = "Instruction Fetch"}
                    "0110" = @{"Mnemonic" = "PREFETCH"; "Request_Type" = "Prefetch"}
                    "0111" = @{"Mnemonic" = "EVICT"; "Request_Type" = "Eviction"}
                    "1000" = @{"Mnemonic" = "SNOOP"; "Request_Type" = "Snoop"}
                }
                "PP" = @{ # Encoding of Participation Processor (PP) sub-field
                    "00" = @{"Mnemonic" = "SRC"; "Transaction" = "Local processor originated request"}
                    "01" = @{"Mnemonic" = "RES"; "Transaction" = "Local processor responded to request"}
                    "10" = @{"Mnemonic" = "OBS"; "Transaction" = "Local processor* observed error as third party"}
                    "11" = @{"Mnemonic" = "GEN"; "Transaction" = "Generic"} # No Corresponding Mnemonic
                }
                "T" = @{ # Encoding of Timeout (T) sub-field
                    "0" = @{"Mnemonic" = "NOTIMEOUT"; "Transaction" = "Request did not time out"}
                    "1" = @{"Mnemonic" = "TIMEOUT"; "Transaction" = "Request timed out"}
                }
                "II" = @{ # Encoding of Memory/IO (II) sub-field
                    "00" = @{"Mnemonic" = "M"; "Transaction" = "Memory Access"}
                    "01" = @{"Mnemonic" = "RSVD"; "Transaction" = "Reserved"} # No Corresponding Mnemonic
                    "10" = @{"Mnemonic" = "IO"; "Transaction" = "I/O"}
                    "11" = @{"Mnemonic" = "OTR"; "Transaction" = "Other transaction"} # No Corresponding Mnemonic
                }
                "F" = @{ # Correction_Report_Filtering
                    "0" = "normal"
                    "1" = "corrected"
                }
            }
            "threshold_based_error" = @{
                "00" = "No tracking" # No hardware status tracking is provided for the structure reporting this event.
                "01" = "Green" # Status tracking is provided for the structure posting the event; the current status is green (below threshold).
                "10" = "Yellow" # Status tracking is provided for the structure posting the event; the current status is yellow (above threshold).
                "11" = "Reserved" # Reserved for future use
            }
        }
        $IA32_MCi_MISC_Sub_Fields = @{
            "Address_Modes" = @{
                "000" = "Segment Offset"
                "001" = "Linear Address"
                "010" = "Physical Address"
                "011" = "Memory Address"
                "100" = "Reserved"
                "101" = "Reserved"
                "110" = "Reserved"
                "111" = "Generic"
            }
        }
        $result = @()
        $id = 0
        if ($IA32_MCG_CAP.GetType().Name -in @("Int32", "String")) {
            $IA32_MCG_CAP = ConvertFrom-IA32_MCG_CAP $IA32_MCG_CAP
        }
        elseif ($IA32_MCG_CAP.GetType().Name -eq "OrderedDictionary") {
            if ($IA32_MCG_CAP.Count -notin @(9, 10)) {
                Write-Warning "Invalid IA32_MCG_CAP, stop decoding."
                exit 1
            }
        }
        else {
            Write-Warning "Invalid IA32_MCG_CAP, stop decoding."
            exit 1
        }

        # Display Processor Signature
        Write-Verbose "Processor Signature: $ProcessorSignature"

        # Display contents of IA32_MCG_CAP
        Write-Verbose "Contents of IA32_MCG_CAP:"
        $message = "  => MCG_Count   " + $IA32_MCG_CAP.MCG_Count + " (bits 7:0   - number of hardware unit error-reporting banks available"; Write-Verbose $message
        $message = "  => MCG_CTL_P   " + $IA32_MCG_CAP.MCG_CTL_P + " (bit 8      - control MSR present"; Write-Verbose $message
        $message = "  => MCG_EXT_P   " + $IA32_MCG_CAP.MCG_EXT_P + " (bit 9      - extended MSRs present"; Write-Verbose $message
        $message = "  => MCG_CMCI_P  " + $IA32_MCG_CAP.MCG_CMCI_P + " (bit 10     - Corrected MC error counting/signaling extension present"; Write-Verbose $message
        $message = "  => MCG_TES_P   " + $IA32_MCG_CAP.MCG_TES_P + " (bit 11     - threshold-based error status present"; Write-Verbose $message
        if ($IA32_MCG_CAP.MCG_EXT_CNT) {
            $message = "  => MCG_EXT_CNT " + $IA32_MCG_CAP.MCG_EXT_CNT + " (bits 23:16 - the number of extended machine-check state registers present"; Write-Verbose $message
        }
        $message = "  => MCG_SER_P   " + $IA32_MCG_CAP.MCG_SER_P + " (bit 24     - software error recovery support present"; Write-Verbose $message
        $message = "  => MCG_EMC_P   " + $IA32_MCG_CAP.MCG_EMC_P + " (bit 25     - Enhanced Machine Check Capability"; Write-Verbose $message
        $message = "  => MCG_ELOG_P  " + $IA32_MCG_CAP.MCG_ELOG_P + " (bit 26     - extended error logging"; Write-Verbose $message
        $message = "  => MCG_LMCE_P  " + $IA32_MCG_CAP.MCG_LMCE_P + " (bit 27     - local machine check exception"; Write-Verbose $message
    }

    Process {
        $InputObject -split "`n" | Where-Object { $_ -like "*MCE:*cpu*bank*status*[Addr|Misc]:*" } | ForEach-Object {
            $parsed_data = @{
                "timestamp" = ($_ -split " ")[0]
                "status" = ((($_ -split "status")[1] -split " ")[0]) -replace ":|=",""
                "cpu" = (($_ -split "cpu")[1] -split ":")[0]
                "bank" = (($_ -split "bank")[1] -split ":")[0]
                "addr" = ((($_ -split "Addr")[1] -split " ")[0]) -replace ":",""
                "misc" = ((($_ -split "Misc")[1] -split " ")[0]) -replace ":",""
            }
            Write-Verbose "Parsed Data:"
            $message = "  => Timestamp: " + $parsed_data.timestamp; Write-Verbose $message
            $message = "  => Status:    " + $parsed_data.status; Write-Verbose $message
            $message = "  => cpu:       " + $parsed_data.cpu; Write-Verbose $message
            $message = "  => bank:      " + $parsed_data.bank; Write-Verbose $message
            $message = "  => Addr:      " + $parsed_data.addr; Write-Verbose $message
            $message = "  => Misc:      " + $parsed_data.misc; Write-Verbose $message

            # IA32_MCi_STATUS MSRs
            $IA32_MCi_STATUS = @{
                "mca_error_codes" = @{ # MCA (machine-check architecture) error code field, bits 15:0
                    "Binary_Encoding" = $null
                    "Type" = $null
                    "Error_Code" = $null
                    "Meaning" = $null
                }
                "model_specific_errors" = [ordered]@{} # Model-specific error code field, bits 31:16
                "reserved_error_status_other_information" = [ordered]@{} # Reserved, Error Status and Other Information fields, bits 56:32
                "status_register_validity_indicators" = [ordered]@{ # bits [63:57]
                    "VAL"   = $null # IA32_MCi_STATUS register valid
                    "OVER"  = $null # machine check overflow
                    "UC"    = $null # error uncorrected
                    "EN"    = $null # error enabled
                    "MISCV" = $null # IA32_MCi_MISC register valid
                    "ADDRV" = $null # IA32_MCi_ADDR register valid
                    "PCC"   = $null # processor context corrupt
                }
            }
            # IA32_MCi_MISC MSRs
            $IA32_MCi_MISC = @{
            }
            # IA32_MCi_ADDR MSRs
            $IA32_MCi_ADDR = @{
            }

            # Decode IA32_MCi_STATUS MSRs
            $IA32_MCi_STATUS_MSR = [System.Convert]::ToString($parsed_data.status, 2)
            $IA32_MCi_STATUS.status_register_validity_indicators.VAL = Read-Register $IA32_MCi_STATUS_MSR 63

            if ($IA32_MCi_STATUS.status_register_validity_indicators.VAL -eq "1") {
                # Status register validity indicators
                $IA32_MCi_STATUS.status_register_validity_indicators.OVER = Read-Register $IA32_MCi_STATUS_MSR 62
                $IA32_MCi_STATUS.status_register_validity_indicators.UC = Read-Register $IA32_MCi_STATUS_MSR 61
                $IA32_MCi_STATUS.status_register_validity_indicators.EN = Read-Register $IA32_MCi_STATUS_MSR 60
                $IA32_MCi_STATUS.status_register_validity_indicators.MISCV = Read-Register $IA32_MCi_STATUS_MSR 59
                $IA32_MCi_STATUS.status_register_validity_indicators.ADDRV = Read-Register $IA32_MCi_STATUS_MSR 58
                $IA32_MCi_STATUS.status_register_validity_indicators.PCC = Read-Register $IA32_MCi_STATUS_MSR 57

                # If IA32_MCG_CAP[11] is 1, bits 56:53 are architectural (not model-specific).
                # In this case, bits 56:53 have the following functionality:
                if ($IA32_MCG_CAP.MCG_TES_P -eq "1") {
                    # If IA32_MCG_CAP[24] is 1, bits 56:55 are defined as follows:
                    # S (Signaling) flag, bit 56 - Signals the reporting of UCR errors in this MC bank.
                    # AR (Action Required) flag, bit 55 - Indicates (when set) that MCA error code specific recovery
                    #     action must be performed by system software at the time this error was signaled.
                    if ($IA32_MCG_CAP.MCG_SER_P -eq "1") {
                        $IA32_MCi_STATUS.reserved_error_status_other_information.Add("S", (Read-Register $IA32_MCi_STATUS_MSR 56))
                        $IA32_MCi_STATUS.reserved_error_status_other_information.Add("AR", (Read-Register $IA32_MCi_STATUS_MSR 55))
                    }
                    # If IA32_MCG_CAP[24] is 0, bits 56:55 are reserved.
                    else {
                    }

                    # If the UC bit (Figure 15-6) is 0, bits 54:53 indicate the status of the hardware structure
                    # that reported the threshold-based error.
                    if ($IA32_MCi_STATUS.status_register_validity_indicators.UC -eq "0") {
                        $IA32_MCi_STATUS.reserved_error_status_other_information.Add("Threshold-Based_Error_Status", $IA32_MCi_STATUS_Sub_Fields.threshold_based_error.(Read-Register $IA32_MCi_STATUS_MSR 54 53))
                    }
                    # If the UC bit (Figure 15-6) is 1, bits 54:53 are undefined.
                    else {
                    }
                }
                # If IA32_MCG_CAP[11] is 0, bits 56:53 are part of the “Other Information” field. (model-specific)
                else {
                }

                # Indicates (when set) that the processor supports software error recovery
                # Determine Type of Error
                if ($IA32_MCG_CAP.MCG_SER_P -eq "1") {
                    $MC_Error_Type_Code = $IA32_MCi_STATUS.status_register_validity_indicators.UC `
                        + $IA32_MCi_STATUS.status_register_validity_indicators.EN `
                        + $IA32_MCi_STATUS.status_register_validity_indicators.PCC `
                        + $IA32_MCi_STATUS.reserved_error_status_other_information.S `
                        + $IA32_MCi_STATUS.reserved_error_status_other_information.AR
                    Write-Verbose "Status register validity indicators:"
                    $message = "  => UC:  " + $IA32_MCi_STATUS.status_register_validity_indicators.UC; Write-Verbose $message
                    $message = "  => EN:  " + $IA32_MCi_STATUS.status_register_validity_indicators.EN; Write-Verbose $message
                    $message = "  => PCC: " + $IA32_MCi_STATUS.status_register_validity_indicators.PCC; Write-Verbose $message
                    $message = "  => S:   " + $IA32_MCi_STATUS.reserved_error_status_other_information.S; Write-Verbose $message
                    $message = "  => AR:  " + $IA32_MCi_STATUS.reserved_error_status_other_information.AR; Write-Verbose $message
                    Write-Verbose "UCR Error Type Code: $MC_Error_Type_Code"

                    Switch -Regex ($MC_Error_Type_Code) {
                        "111.." {
                            $MC_Error_Type = "UC" # Uncorrected Error
                            break
                        }
                        "11011" {
                            $MC_Error_Type = "SRAR" # Software recoverable action required (SRAR)
                            break
                        }
                        "11010" {
                            $MC_Error_Type = "SRAO" # Software recoverable action optional (SRAO) / MCE Signaling
                            break
                        }
                        "1.000" {
                            # Uncorrected no action required (UCNA) / SRAO if CMC Signaling
                            # Actually vmkernel.log has separate log entry on MCA errors detected via CMCI, they're ignored here for simplicity.
                            # 2016-06-28T11:57:11.793Z cpu20:37018)MCE: 1012: cpu20: MCA error detected via CMCI (Gbl status=0x0): Restart IP: invalid, Error IP: invalid, MCE in progress: no.
                            $MC_Error_Type = "SRAO/UCNA"
                            break
                        }
                        "0...." {
                            $MC_Error_Type = "CE" # Corrected Error
                            break
                        }
                        Default {
                            Write-Warning "UCR Error Classification could not be identified"
                        }
                    }
                }

                # If IA32_MCG_CAP[10] is 1, bits 52:38 are architectural (not model-specific).
                # In this case, bits 52:38 reports the value of a 15 bit counter that increments
                # each time a corrected error is observed by the MCA recording bank.
                # This count value will continue to increment until cleared by software.
                if ($IA32_MCG_CAP.MCG_CMCI_P -eq "1") {
                    if ($IA32_MCi_STATUS.status_register_validity_indicators.UC -eq "0") {
                        # The most significant bit, 52, is a sticky count overflow bit.
                        if ((Read-Register $IA32_MCi_STATUS_MSR 52) -eq "0") {
                            $IA32_MCi_STATUS.reserved_error_status_other_information.Add("Corrected_Error_Count", [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 51 38), 2))
                        }
                        else {
                            $IA32_MCi_STATUS.reserved_error_status_other_information.Add("Corrected_Error_Count", "Overflow")
                        }
                    }
                }
                # When IA32_MCG_CAP[10] = 0, bits 52:38 are part of the “Other Information” field. (model-specific)
                else {
                }

                # If IA32_MCG_CAP.MCG_EMC_P[bit 25] is 0, bits 37:32 contain “Other Information” that is implementation-
                # specific and is not part of the machine-check architecture.
                if ($IA32_MCG_CAP.MCG_EMC_P -eq "0") {
                }
                # If IA32_MCG_CAP.MCG_EMC_P is 1, “Other Information” is in bits 36:32.
                else {
                    # If bit 37 is 0, system firmware has not changed the contents of IA32_MCi_STATUS.
                    $IA32_MCi_STATUS.reserved_error_status_other_information.Add("Firmware_updated_error_status_indicator", (Read-Register $IA32_MCi_STATUS_MSR 37))
                }

                # Decode IA32_MCi_ADDR MSRs (if ADDRV flag bit was set)
                if ($IA32_MCi_STATUS.status_register_validity_indicators.ADDRV -eq "1") {
                    $IA32_MCi_ADDR.Add("Address", $parsed_data.addr)
                }

                # Decode IA32_MCi_MISC MSRs (if MISCV flag bit was set)
                if ($IA32_MCi_STATUS.status_register_validity_indicators.MISCV -eq "1") {
                    $IA32_MCi_MISC_MSR = ([System.Convert]::ToString($parsed_data.misc, 2)).PadLeft(64, "0")

                    # If both MISCV and IA32_MCG_CAP[24] are set
                    if ($IA32_MCG_CAP.MCG_SER_P -eq "1") {
                        $IA32_MCi_MISC.Add("Address_Mode", ($IA32_MCi_MISC_Sub_Fields.Address_Modes.(Read-Register $IA32_MCi_MISC_MSR 8 6)))
                        $IA32_MCi_MISC.Add("Recoverable_Address_LSB", ([System.Convert]::ToInt16((Read-Register $IA32_MCi_MISC_MSR 5 0), 2)))

                        # Ignore last bits of the recoverable error address in IA32_MCi_ADDR (amount of 'Recoverable Address LSB')
                        if (($IA32_MCi_STATUS.status_register_validity_indicators.ADDRV -eq "1") -and ($IA32_MCi_MISC.Recoverable_Address_LSB -ne 0)) {
                            $IA32_MCi_ADDR_MSR = ([System.Convert]::ToString($IA32_MCi_ADDR.Address, 2)).PadLeft(64, "0")
                            $IA32_MCi_ADDR_MSR_Valid = $IA32_MCI_ADDR_MSR.Substring(0, (64 - [Int16]$IA32_MCi_MISC.Recoverable_Address_LSB)).PadRight(64, "0")
                            $IA32_MCi_ADDR.Add("Address_Valid", ("0x{0:x}" -f [System.Convert]::ToInt64($IA32_MCi_ADDR_MSR_Valid, 2)))
                        }
                    }
                }

                # MCA (machine-check architecture) error code field, bits 15:0
                $IA32_MCi_STATUS.mca_error_codes.Binary_Encoding = Read-Register $IA32_MCi_STATUS_MSR 15 0
                Switch -Regex ($IA32_MCi_STATUS.mca_error_codes.Binary_Encoding) {
                    # Simple Error Codes
                    "0000000000000000" {
                        $IA32_MCi_STATUS.mca_error_codes.Type = "Simple"
                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "No Error"
                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "No error has been reported to this bank of error-reporting registers."
                        break
                    }
                    "0000000000000001" {
                        $IA32_MCi_STATUS.mca_error_codes.Type = "Simple"
                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Unclassified"
                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "This error has not been classified into the MCA error classes."
                        break
                    }
                    "0000000000000010" {
                        $IA32_MCi_STATUS.mca_error_codes.Type = "Simple"
                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Microcode ROM Parity Error"
                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "Parity error in internal microcode ROM"
                        break
                    }
                    "0000000000000011" {
                        $IA32_MCi_STATUS.mca_error_codes.Type = "Simple"
                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "External Error"
                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "The BINIT# from another processor caused this processor to enter machine check."
                        break
                    }
                    "0000000000000100" {
                        $IA32_MCi_STATUS.mca_error_codes.Type = "Simple"
                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "FRC Error"
                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "FRC (functional redundancy check) master/slave error"
                        break
                    }
                    "0000000000000101" {
                        $IA32_MCi_STATUS.mca_error_codes.Type = "Simple"
                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Internal Parity Error"
                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "Internal parity error."
                        break
                    }
                    "0000000000000110" {
                        $IA32_MCi_STATUS.mca_error_codes.Type = "Simple"
                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "SMM Handler Code Access Violation"
                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "An attempt was made by the SMM Handler to execute outside the ranges specified by SMRR."
                        break
                    }
                    "0000010000000000" {
                        $IA32_MCi_STATUS.mca_error_codes.Type = "Simple"
                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Internal Timer Error"
                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "Internal timer error."
                        break
                    }
                    "0000111000001011" {
                        $IA32_MCi_STATUS.mca_error_codes.Type = "Simple"
                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "I/O Error"
                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "generic I/O error."
                        break
                    }
                    #"000001.........." {
                    # At least one X must equal one. Internal unclassified errors have not been classified.
                    "^(000001)(0{0,}1{1,})" {
                        $IA32_MCi_STATUS.mca_error_codes.Type = "Simple"
                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Internal Unclassified"
                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "Internal unclassified errors."
                        break
                    }

                    # Compound Error Codes
                    "000.0000000011.." { # 000F 0000 0000 11LL
                        # Generic Cache Hierarchy
                        $memory_hierarchy_level = $IA32_MCi_STATUS_Sub_Fields.mca_error.LL.(Read-Register $IA32_MCi_STATUS_MSR 1 0)

                        $IA32_MCi_STATUS.mca_error_codes.Type = "Compound"
                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Generic Cache Hierarchy"
                        $IA32_MCi_STATUS.mca_error_codes.Add("Interpretation", "Generic cache hierarchy error")
                        $IA32_MCi_STATUS.mca_error_codes.Meaning = $IA32_MCi_STATUS.mca_error_codes.Error_Code + " / " + $memory_hierarchy_level.Hierarchy_Level

                        break
                    }
                    "000.00000001...." { # 000F 0000 0001 TTLL
                        # TLB Errors
                        $transaction_type = $IA32_MCi_STATUS_Sub_Fields.mca_error.TT.(Read-Register $IA32_MCi_STATUS_MSR 3 2)
                        if (! $transaction_type) {
                            Write-Warning "Transaction type not found."
                        }
                        $memory_hierarchy_level = $IA32_MCi_STATUS_Sub_Fields.mca_error.LL.(Read-Register $IA32_MCi_STATUS_MSR 1 0)

                        $IA32_MCi_STATUS.mca_error_codes.Type = "Compound"
                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "TLB Errors"
                        $IA32_MCi_STATUS.mca_error_codes.Add("Interpretation", ($transaction_type.Mnemonic + "TLB_" + $memory_hierarchy_level.Mnemonic + "_ERR"))
                        $IA32_MCi_STATUS.mca_error_codes.Meaning = $IA32_MCi_STATUS.mca_error_codes.Error_Code + " / " + $transaction_type.Transaction_Type + " / " + $memory_hierarchy_level.Hierarchy_Level

                        break
                    }
                    "000.00001......." { # 000F 0000 1MMM CCCC
                        # Memory Controller Errors
                        $memory_transaction_type = $IA32_MCi_STATUS_Sub_Fields.mca_error.MMM.(Read-Register $IA32_MCi_STATUS_MSR 6 4)
                        $channel_number = [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 3 0), 2)
                        if ( $channel_number -eq 15 ) {
                            $channel = @{"Mnemonic" = "NaN"; "Transaction" = "Channel not specified"}
                        }
                        else {
                            $channel = @{"Mnemonic" = "CHN"; "Transaction" = $channel_number}
                        }

                        $IA32_MCi_STATUS.mca_error_codes.Type = "Compound"
                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Memory Controller Errors"
                        $IA32_MCi_STATUS.mca_error_codes.Add("Interpretation", ($memory_transaction_type.Mnemonic + "_CHANNEL" + $channel.Mnemonic + "_ERR"))
                        $IA32_MCi_STATUS.mca_error_codes.Meaning = $IA32_MCi_STATUS.mca_error_codes.Error_Code + " / " + $memory_transaction_type.Transaction + " / " + $channel.Transaction

                        # Architecturally Defined SRAO Errors
                        if (($IA32_MCi_STATUS.status_register_validity_indicators.OVER -eq "0") `
                            -and ($IA32_MCi_STATUS.status_register_validity_indicators.UC -eq "1") `
                            -and ($IA32_MCi_STATUS.status_register_validity_indicators.MISCV -eq "1") `
                            -and ($IA32_MCi_STATUS.status_register_validity_indicators.ADDRV -eq "1") `
                            -and ($IA32_MCi_STATUS.status_register_validity_indicators.PCC -eq "0") `
                            -and ($IA32_MCi_STATUS.reserved_error_status_other_information.AR -eq "0")) {
                            # Memory Scrubbing
                            if ($memory_transaction_type.Transaction -eq "Memory Scrubbing Error") {
                                $IA32_MCi_STATUS.mca_error_codes.Meaning = "Architecturally Defined SRAO Errors / Memory Scrubbing / " + $channel.Transaction
                                $MC_Error_Type = "SRAO"
                                # For the memory scrubbing and L3 explicit writeback errors,
                                # the address mode in the IA32_MCi_MISC register should be set as physical address mode (010b)
                                # and the address LSB information in the IA32_MCi_MISC register should indicate
                                # the lowest valid address bit in the address information provided from the IA32_MCi_ADDR register.
                                if ($IA32_MCi_MISC.Address_Mode -ne "Physical Address") {
                                    Write-Warning "The address mode in the IA32_MCi_MISC register should be set as physical address mode (010b)."
                                }
                            }
                        }

                        break
                    }
                    "000.0001........" { # 000F 0001 RRRR TTLL
                        # Cache Hierarchy Errors
                        $request = $IA32_MCi_STATUS_Sub_Fields.mca_error.RRRR.(Read-Register $IA32_MCi_STATUS_MSR 7 4)
                        if (! $request) {
                            Write-Warning "Request could not be identified."
                        }
                        $transaction_type = $IA32_MCi_STATUS_Sub_Fields.mca_error.TT.(Read-Register $IA32_MCi_STATUS_MSR 3 2)
                        $memory_hierarchy_level = $IA32_MCi_STATUS_Sub_Fields.mca_error.LL.(Read-Register $IA32_MCi_STATUS_MSR 1 0)

                        $IA32_MCi_STATUS.mca_error_codes.Type = "Compound"
                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Cache Hierarchy Errors"
                        $IA32_MCi_STATUS.mca_error_codes.Add("Interpretation", ($transaction_type.Mnemonic + "CACHE" + $memory_hierarchy_level.Mnemonic + "_" + $request.Mnemonic + "_ERR"))
                        $IA32_MCi_STATUS.mca_error_codes.Meaning = $IA32_MCi_STATUS.mca_error_codes.Error_Code + " / " + $transaction_type.Transaction_Type + " / " + $memory_hierarchy_level.Hierarchy_Level + " / " + $request.Request_Type

                        # Architecturally Defined SRAO Errors
                        if (($IA32_MCi_STATUS.status_register_validity_indicators.OVER -eq "0") `
                            -and ($IA32_MCi_STATUS.status_register_validity_indicators.UC -eq "1") `
                            -and ($IA32_MCi_STATUS.status_register_validity_indicators.MISCV -eq "1") `
                            -and ($IA32_MCi_STATUS.status_register_validity_indicators.ADDRV -eq "1") `
                            -and ($IA32_MCi_STATUS.status_register_validity_indicators.PCC -eq "0") `
                            -and ($IA32_MCi_STATUS.reserved_error_status_other_information.AR -eq "0")) {
                            # L3 Explicit Writeback
                            if (($request.Request_Type -eq "Eviction") `
                                -and ($transaction_type.Transaction_Type -eq "Generic") `
                                -and ($memory_hierarchy_level.Hierarchy_Level -eq "Level 2")) {
                                $IA32_MCi_STATUS.mca_error_codes.Meaning = "Architecturally Defined SRAO Errors / L3 Explicit Writeback"
                                $MC_Error_Type = "SRAO"
                                # For the memory scrubbing and L3 explicit writeback errors,
                                # the address mode in the IA32_MCi_MISC register should be set as physical address mode (010b)
                                # and the address LSB information in the IA32_MCi_MISC register should indicate
                                # the lowest valid address bit in the address information provided from the IA32_MCi_ADDR register.
                                if ($IA32_MCi_MISC.Address_Mode -ne "Physical Address") {
                                    Write-Warning "The address mode in the IA32_MCi_MISC register should be set as physical address mode (010b)."
                                }
                            }
                        }

                        # Architecturally Defined SRAR Errors
                        if (($IA32_MCi_STATUS.status_register_validity_indicators.OVER -eq "0") `
                            -and ($IA32_MCi_STATUS.status_register_validity_indicators.UC -eq "1") `
                            -and ($IA32_MCi_STATUS.status_register_validity_indicators.EN -eq "1") `
                            -and ($IA32_MCi_STATUS.status_register_validity_indicators.MISCV -eq "1") `
                            -and ($IA32_MCi_STATUS.status_register_validity_indicators.ADDRV -eq "1") `
                            -and ($IA32_MCi_STATUS.status_register_validity_indicators.PCC -eq "0") `
                            -and ($IA32_MCi_STATUS.reserved_error_status_other_information.S -eq "1") `
                            -and ($IA32_MCi_STATUS.reserved_error_status_other_information.AR -eq "1")) {
                            # Data Load
                            if (($request.Request_Type -eq "Data Read") -and
                                ($transaction_type.Transaction_Type -eq "Data") -and
                                ($memory_hierarchy_level.Hierarchy_Level -eq "Level 0")) {
                                $IA32_MCi_STATUS.mca_error_codes.Meaning = "Architecturally Defined SRAR Errors / Data Load"
                                $MC_Error_Type = "SRAR"
                            }
                            # Instruction Fetch
                            elseif (($request.Request_Type -eq "Instruction Fetch") -and
                                ($transaction_type.Transaction_Type -eq "Instruction") -and
                                ($memory_hierarchy_level.Hierarchy_Level -eq "Level 0")) {
                                $IA32_MCi_STATUS.mca_error_codes.Meaning = "Architecturally Defined SRAR Errors / Instruction Fetch"
                                $MC_Error_Type = "SRAR"
                            }
                            # For the data load and instruction fetch errors,
                            # the address mode in the IA32_MCi_MISC register should be set as physical address mode (010b)
                            # and the address LSB information in the IA32_MCi_MISC register should indicate
                            # the lowest valid address bit in the address information provided from the IA32_MCi_ADDR register.
                            if ($IA32_MCi_MISC.Address_Mode -ne "Physical Address") {
                                Write-Warning "The address mode in the IA32_MCi_MISC register should be set as physical address mode (010b)."
                            }
                        }

                        break
                    }
                    "000.1..........." { # 000F 1PPT RRRR IILL
                        # Bus and Interconnect Errors
                        $participation = $IA32_MCi_STATUS_Sub_Fields.mca_error.PP.(Read-Register $IA32_MCi_STATUS_MSR 10 9)
                        $time_out = $IA32_MCi_STATUS_Sub_Fields.mca_error.T.(Read-Register $IA32_MCi_STATUS_MSR 8)
                        $request = $IA32_MCi_STATUS_Sub_Fields.mca_error.RRRR.(Read-Register $IA32_MCi_STATUS_MSR 7 4)
                        if (! $request) {
                            Write-Warning "Request could not be identified."
                        }
                        $memory_or_io = $IA32_MCi_STATUS_Sub_Fields.mca_error.II.(Read-Register $IA32_MCi_STATUS_MSR 3 2)
                        $memory_hierarchy_level = $IA32_MCi_STATUS_Sub_Fields.mca_error.LL.(Read-Register $IA32_MCi_STATUS_MSR 1 0)

                        $IA32_MCi_STATUS.mca_error_codes.Type = "Compound"
                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Bus and Interconnect Errors"
                        $IA32_MCi_STATUS.mca_error_codes.Add("Interpretation", ("BUS" + $memory_hierarchy_level.Mnemonic + "_" + $participation.Mnemonic + "_" + $request.Mnemonic + "_" + $memory_or_io.Mnemonic + "_" + $time_out.Mnemonic + "_ERR"))
                        $IA32_MCi_STATUS.mca_error_codes.Meaning = $IA32_MCi_STATUS.mca_error_codes.Error_Code + " / " + $participation.Transaction + " / " + $time_out.Transaction + " / " + $request.Request_Type + " / " + $memory_or_io.Transaction + " / " + $memory_hierarchy_level.Hierarchy_Level

                        break
                    }
                    Default {
                        Write-Warning "MCA Error Code could not be identified, stop decoding."
                        return
                    }
                }
                # Starting with Intel Core Duo processors, bit 12 is used to indicate that a particular posting to a log
                # may be the last posting for corrections in that line/entry, at least for some time
                # Filtering has meaning only for corrected errors (UC=0 in IA32_MCi_STATUS MSR).
                # System software must ignore filtering bit (12) for uncorrected errors.
                # The correction report filtering (F) bit (bit 12) of the MCA error must be ignored in case of SRAO/SRAR errors.
                if (($IA32_MCi_STATUS.mca_error_codes.Type -eq "Compound") `
                    -and ($IA32_MCi_STATUS.status_register_validity_indicators.UC -eq "0") `
                    -and ($IA32_MCi_STATUS.mca_error_codes.Meaning -notmatch "^Architecturally Defined SRA[OR] Errors.*")) {
                    $IA32_MCi_STATUS.mca_error_codes.Add("Correction_Report_Filtering", ($IA32_MCi_STATUS_Sub_Fields.mca_error.F.(Read-Register $IA32_MCi_STATUS_MSR 12)))
                }

                # Incremental Decoding Information
                $incremental_decoding_information = "No"
                $MSR_ERROR_CONTROL = @{1 = "1"}

                Switch ($ProcessorSignature) {
                    # Processor Family 06H
                    # 06_0EH Intel Core Duo, Intel Core Solo processors
                    # 06_0DH Intel Pentium M processor
                    # 06_09H Intel Pentium M processor
                    # 06_7H, 06_08H, 06_0AH, 06_0BH Intel Pentium III Xeon Processor, Intel Pentium III Processor
                    # 06_03H, 06_05H Intel Pentium II Xeon Processor, Intel Pentium II Processor
                    # 06_01H Intel Pentium Pro Processor
                    { $ProcessorSignature -in @("06_0EH", "06_0DH", "06_09H", "06_7H", "06_08H", "06_0AH", "06_0BH", "06_03H", "06_05H", "06_01H") } {
                        if ($IA32_MCi_STATUS.mca_error_codes.Error_Code -eq "Bus and Interconnect Errors") { # 000F 1PPT RRRR IILL
                            $incremental_decoding_information = "Yes"

                            # Reset "Model specific errors" and "Reserved, Error Status, and Other information"
                            $IA32_MCi_STATUS.model_specific_errors = @{}
                            $IA32_MCi_STATUS.reserved_error_status_other_information = @{}

                            # Model specific errors
                            $bus_queue_request_type = @{
                                "000000" = "BQ_DCU_READ_TYPE error"
                                "000010" = "BQ_IFU_DEMAND_TYPE error"
                                "000011" = "BQ_IFU_DEMAND_NC_TYPE error"
                                "000100" = "BQ_DCU_RFO_TYPE error"
                                "000101" = "BQ_DCU_RFO_LOCK_TYPE error"
                                "000110" = "BQ_DCU_ITOM_TYPE error"
                                "001000" = "BQ_DCU_WB_TYPE error"
                                "001010" = "BQ_DCU_WCEVICT_TYPE error"
                                "001011" = "BQ_DCU_WCLINE_TYPE error"
                                "001100" = "BQ_DCU_BTM_TYPE error"
                                "001101" = "BQ_DCU_INTACK_TYPE error"
                                "001110" = "BQ_DCU_INVALL2_TYPE error"
                                "001111" = "BQ_DCU_FLUSHL2_TYPE error"
                                "010000" = "BQ_DCU_PART_RD_TYPE error"
                                "010010" = "BQ_DCU_PART_WR_TYPE error"
                                "010100" = "BQ_DCU_SPEC_CYC_TYPE error"
                                "011000" = "BQ_DCU_IO_RD_TYPE error"
                                "011001" = "BQ_DCU_IO_WR_TYPE error"
                                "011100" = "BQ_DCU_LOCK_RD_TYPE error"
                                "011110" = "BQ_DCU_SPLOCK_RD_TYPE error"
                                "011101" = "BQ_DCU_LOCK_WR_TYPE error"
                            }
                            $bus_queue_error_type = @{
                                "000" = "BQ_ERR_HARD_TYPE error"
                                "001" = "BQ_ERR_DOUBLE_TYPE error"
                                "010" = "BQ_ERR_AERR2_TYPE error"
                                "100" = "BQ_ERR_SINGLE_TYPE error"
                                "101" = "BQ_ERR_AERR1_TYPE error"
                            }
                            $IA32_MCi_STATUS.model_specific_errors.Add("Bus_queue_request_type", $bus_queue_request_type.(Read-Register $IA32_MCi_STATUS_MSR 24 19))
                            if (! $IA32_MCi_STATUS.model_specific_errors.Bus_queue_request_type) {
                                Write-Warning "Bus queue request type not found."
                            }
                            $IA32_MCi_STATUS.model_specific_errors.Add("Bus_queue_error_type", $bus_queue_error_type.(Read-Register $IA32_MCi_STATUS_MSR 27 25))
                            if (! $IA32_MCi_STATUS.model_specific_errors.Bus_queue_error_type) {
                                Write-Warning "Bus queue error type not found."
                            }
                            $IA32_MCi_STATUS.model_specific_errors.Add("FRC_error", (Read-Register $IA32_MCi_STATUS_MSR 28))
                            $IA32_MCi_STATUS.model_specific_errors.Add("BERR", (Read-Register $IA32_MCi_STATUS_MSR 29))
                            $IA32_MCi_STATUS.model_specific_errors.Add("Internal_BINIT", (Read-Register $IA32_MCi_STATUS_MSR 30))

                            # Other information
                            $IA32_MCi_STATUS.reserved_error_status_other_information.Add("External_BINIT", (Read-Register $IA32_MCi_STATUS_MSR 35))
                            $IA32_MCi_STATUS.reserved_error_status_other_information.Add("Response_parity_error", (Read-Register $IA32_MCi_STATUS_MSR 36))
                            $IA32_MCi_STATUS.reserved_error_status_other_information.Add("Bus_BINIT", (Read-Register $IA32_MCi_STATUS_MSR 37))
                            $IA32_MCi_STATUS.reserved_error_status_other_information.Add("Timeout_BINIT", (Read-Register $IA32_MCi_STATUS_MSR 38))
                            $IA32_MCi_STATUS.reserved_error_status_other_information.Add("Hard_error", (Read-Register $IA32_MCi_STATUS_MSR 42))
                            $IA32_MCi_STATUS.reserved_error_status_other_information.Add("IERR", (Read-Register $IA32_MCi_STATUS_MSR 43))
                            $IA32_MCi_STATUS.reserved_error_status_other_information.Add("AERR", (Read-Register $IA32_MCi_STATUS_MSR 44))
                            $IA32_MCi_STATUS.reserved_error_status_other_information.Add("UECC", (Read-Register $IA32_MCi_STATUS_MSR 45))
                            $IA32_MCi_STATUS.reserved_error_status_other_information.Add("CECC", (Read-Register $IA32_MCi_STATUS_MSR 45))
                            $IA32_MCi_STATUS.reserved_error_status_other_information.Add("ECC_syndrome", (Read-Register $IA32_MCi_STATUS_MSR 54 47))
                        }
                        break
                    }

                    # Intel Core 2 Processor Family
                    # 06_1DH Intel Xeon Processor 7400 series.
                    # 06_17H Intel Xeon Processor 5200, 5400 series, Intel Core 2 Quad processor Q9650.
                    # 06_0FH Intel Xeon Processor 3000, 3200, 5100, 5300, 7300 series, Intel Core 2 Quad, Intel Core 2 Extreme, Intel Core 2 Duo processors, Intel Pentium dual-core processors.
                    { $ProcessorSignature -in @("06_1DH", "06_17H", "06_0FH") } {
                        if ($IA32_MCi_STATUS.mca_error_codes.Error_Code -eq "Bus and Interconnect Errors") { # 000F 1PPT RRRR IILL
                            $incremental_decoding_information = "Yes"

                            # Reset "Model specific errors" and "Reserved, Error Status, and Other information"
                            $IA32_MCi_STATUS.model_specific_errors = @{}
                            $IA32_MCi_STATUS.reserved_error_status_other_information = @{}

                            # Model specific errors
                            $bus_queue_request_type = @{
                                "000001" = "BQ_PREF_READ_TYPE error"
                                "000000" = "BQ_DCU_READ_TYPE error"
                                "000010" = "BQ_IFU_DEMAND_TYPE error"
                                "000011" = "BQ_IFU_DEMAND_NC_TYPE error"
                                "000100" = "BQ_DCU_RFO_TYPE error"
                                "000101" = "BQ_DCU_RFO_LOCK_TYPE error"
                                "000110" = "BQ_DCU_ITOM_TYPE error"
                                "001000" = "BQ_DCU_WB_TYPE error"
                                "001010" = "BQ_DCU_WCEVICT_TYPE error"
                                "001011" = "BQ_DCU_WCLINE_TYPE error"
                                "001100" = "BQ_DCU_BTM_TYPE error"
                                "001101" = "BQ_DCU_INTACK_TYPE error"
                                "001110" = "BQ_DCU_INVALL2_TYPE error"
                                "001111" = "BQ_DCU_FLUSHL2_TYPE error"
                                "010000" = "BQ_DCU_PART_RD_TYPE error"
                                "010010" = "BQ_DCU_PART_WR_TYPE error"
                                "010100" = "BQ_DCU_SPEC_CYC_TYPE error"
                                "011000" = "BQ_DCU_IO_RD_TYPE error"
                                "011001" = "BQ_DCU_IO_WR_TYPE error"
                                "011100" = "BQ_DCU_LOCK_RD_TYPE error"
                                "011110" = "BQ_DCU_SPLOCK_RD_TYPE error"
                                "011101" = "BQ_DCU_LOCK_WR_TYPE error"
                                "100100" = "BQ_L2_WI_RFO_TYPE error"
                                "100110" = "BQ_L2_WI_ITOM_TYPE error"
                            }
                            $bus_queue_error_type = @{
                                "001" = "Address Parity Error"
                                "010" = "Response Hard Error"
                                "011" = "Response Parity Error"
                            }
                            $IA32_MCi_STATUS.model_specific_errors.Add("Bus_queue_request_type", $bus_queue_request_type.(Read-Register $IA32_MCi_STATUS_MSR 24 19))
                            if (! $IA32_MCi_STATUS.model_specific_errors.Bus_queue_request_type) {
                                Write-Warning "Bus queue request type not found."
                            }
                            $IA32_MCi_STATUS.model_specific_errors.Add("Bus_queue_error_type", $bus_queue_error_type.(Read-Register $IA32_MCi_STATUS_MSR 27 25))
                            if (! $IA32_MCi_STATUS.model_specific_errors.Bus_queue_error_type) {
                                Write-Warning "Bus queue error type not found."
                            }
                            $IA32_MCi_STATUS.model_specific_errors.Add("MCE_Driven", (Read-Register $IA32_MCi_STATUS_MSR 28))
                            $IA32_MCi_STATUS.model_specific_errors.Add("MCE_Observed", (Read-Register $IA32_MCi_STATUS_MSR 29))
                            $IA32_MCi_STATUS.model_specific_errors.Add("Internal_BINIT", (Read-Register $IA32_MCi_STATUS_MSR 30))
                            $IA32_MCi_STATUS.model_specific_errors.Add("BINIT_Observed", (Read-Register $IA32_MCi_STATUS_MSR 31))

                            # Other information
                            $IA32_MCi_STATUS.reserved_error_status_other_information.Add("PIC_and_FSB_data_parity", (Read-Register $IA32_MCi_STATUS_MSR 34))
                            $IA32_MCi_STATUS.reserved_error_status_other_information.Add("Response_parity_error", (Read-Register $IA32_MCi_STATUS_MSR 36))
                            $IA32_MCi_STATUS.reserved_error_status_other_information.Add("FSB_address_parity", (Read-Register $IA32_MCi_STATUS_MSR 37))
                            $IA32_MCi_STATUS.reserved_error_status_other_information.Add("Timeout_BINIT", (Read-Register $IA32_MCi_STATUS_MSR 38))
                            $IA32_MCi_STATUS.reserved_error_status_other_information.Add("Hard_error", (Read-Register $IA32_MCi_STATUS_MSR 42))
                            $IA32_MCi_STATUS.reserved_error_status_other_information.Add("IERR", (Read-Register $IA32_MCi_STATUS_MSR 43))
                        }

                        # Intel Xeon Processor 7400 series
                        if ($ProcessorSignature -eq "06_1DH") {
                            if ($parsed_data.bank -eq "6") {
                                $incremental_decoding_information = "Yes"

                                # Reset "MCA (machine-check architecture) error code field" and "Model specific errors"
                                $IA32_MCi_STATUS.mca_error_codes.Error_Code = $null
                                $IA32_MCi_STATUS.mca_error_codes.Meaning = $null
                                $IA32_MCi_STATUS.model_specific_errors = @{}

                                # MCA Error Codes
                                Switch -Regex ($IA32_MCi_STATUS.mca_error_codes.Binary_Encoding) {
                                    # Internal Error (Cache Bus Controller Error)
                                    "0000010000000000" { 
                                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Internal Error"
                                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "Internal Error Type Code"
                                        break
                                    }
                                    # Bus and Interconnect Error 
                                    "0000100.00001111" {
                                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Bus and Interconnect Error"
                                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "Not used but this encoding is reserved for compatibility with other MCA implementations"
                                        break
                                    }
                                    "0000101.00001111" {
                                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Bus and Interconnect Error"
                                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "Not used but this encoding is reserved for compatibility with other MCA implementations"
                                        break
                                    }
                                    "0000110.00001111" {
                                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Bus and Interconnect Error"
                                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "Not used but this encoding is reserved for compatibility with other MCA implementations"
                                        break
                                    }
                                    "0000111000001111" {
                                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Bus and Interconnect Error"
                                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "Bus and Interconnection Error Type Code"
                                        break
                                    }
                                    "0000111100001111" {
                                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Bus and Interconnect Error"
                                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "Not used but this encoding is reserved for compatibility with other MCA implementations"
                                        break
                                    }
                                    Default {
                                        Write-Warning "MCA Error Code could not be identified during incremental decoding MCA information"
                                    }
                                }

                                # Model specific errors
                                Switch ($IA32_MCi_STATUS.mca_error_codes.Error_Code) {
                                    "Bus and Interconnect Error" {
                                        $IA32_MCi_STATUS.model_specific_errors.Add("FSB_Request_Parity", (Read-Register $IA32_MCi_STATUS_MSR 16))
                                        $IA32_MCi_STATUS.model_specific_errors.Add("FSB_Hard_Fail_Response", (Read-Register $IA32_MCi_STATUS_MSR 20))
                                        $IA32_MCi_STATUS.model_specific_errors.Add("FSB_Response_Parity", (Read-Register $IA32_MCi_STATUS_MSR 21))
                                        $IA32_MCi_STATUS.model_specific_errors.Add("FSB_Data_Parity", (Read-Register $IA32_MCi_STATUS_MSR 22))
                                        break
                                    }
                                    "Internal Error" {
                                        $model_specific_error_codes = @{
                                            "0000000000000001" = "Inclusion Error from Core 0"
                                            "0000000000000010" = "Inclusion Error from Core 1"
                                            "0000000000000011" = "Write Exclusive Error from Core 0"
                                            "0000000000000100" = "Write Exclusive Error from Core 1"
                                            "0000000000000101" = "Inclusion Error from FSB"
                                            "0000000000000110" = "SNP Stall Error from FSB"
                                            "0000000000000111" = "Write Stall Error from FSB"
                                            "0000000000001000" = "FSB Arb Timeout Error"
                                            "0000000000001010" = "Inclusion Error from Core 2"
                                            "0000000000001011" = "Write Exclusive Error from Core 2"
                                            "0000001000000000" = "Internal Timeout error"
                                            "0000001100000000" = "Internal Timeout Error"
                                            "0000010000000000" = "Intel(R) Cache Safe Technology Queue Full Error or Disabled-ways-in-a-set overflow"
                                            "0000010100000000" = "Quiet cycle Timeout Error (correctable)"
                                            "1100000000000010" = "Correctable ECC event on outgoing Core 0 data"
                                            "1100000000000100" = "Correctable ECC event on outgoing Core 1 data"
                                            "1100000000001000" = "Correctable ECC event on outgoing Core 2 data"
                                            "1110000000000010" = "Uncorrectable ECC error on outgoing Core 0 data"
                                            "1110000000000100" = "Uncorrectable ECC error on outgoing Core 1 data"
                                            "1110000000001000" = "Uncorrectable ECC error on outgoing Core 2 data"
                                        }
                                        $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error", $model_specific_error_codes.(Read-Register $IA32_MCi_STATUS_MSR 31 16))
                                        if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error) {
                                            $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "Reserved"
                                        }
                                        break
                                    }
                                }
                            }
                        }

                        break
                    }

                    # Processor Signature 06_1AH (Nehalem)
                    { $ProcessorSignature -in @("06_1AH") } {
                        Switch ($parsed_data.bank) {
                            # Intel QPI Machine Check Errors
                            { $parsed_data.bank -in @("0", "1") } {
                                $incremental_decoding_information = "Yes"

                                # Reset "Model specific errors" and "Reserved, Error Status, and Other information"
                                $IA32_MCi_STATUS.model_specific_errors = @{}
                                $IA32_MCi_STATUS.reserved_error_status_other_information = @{}

                                if ($IA32_MCi_STATUS.mca_error_codes.Error_Code -eq "Bus and Interconnect Errors") { # 000F 1PPT RRRR IILL
                                    # Model specific errors
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Header_Parity", (Read-Register $IA32_MCi_STATUS_MSR 16))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Data_Parity", (Read-Register $IA32_MCi_STATUS_MSR 17))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Retries_Exceeded", (Read-Register $IA32_MCi_STATUS_MSR 18))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Received_Poison", (Read-Register $IA32_MCi_STATUS_MSR 19))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Unsupported_Message", (Read-Register $IA32_MCi_STATUS_MSR 22))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Unsupported_Credit", (Read-Register $IA32_MCi_STATUS_MSR 23))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Receive_Flit_Overrun", (Read-Register $IA32_MCi_STATUS_MSR 24))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Received_Failed_Response", (Read-Register $IA32_MCi_STATUS_MSR 25))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Receiver_Clock_Jitter", (Read-Register $IA32_MCi_STATUS_MSR 26))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("QPI_Opcode", ("{0:X2}h" -f [System.Convert]::ToInt16((Read-Register $IA32_MCi_MISC_MSR 7 0), 2)))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("RTId", [System.Convert]::ToInt16((Read-Register $IA32_MCi_MISC_MSR 13 8), 2))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("RHNID", [System.Convert]::ToInt16((Read-Register $IA32_MCi_MISC_MSR 18 16), 2))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("IIB", (Read-Register $IA32_MCi_MISC_MSR 24))
                                }
                                break
                            }

                            # Internal Machine Check Errors
                            { $parsed_data.bank -eq "7" } {
                                $incremental_decoding_information = "Yes"

                                # Reset "Model specific errors" and "Reserved, Error Status, and Other information"
                                $IA32_MCi_STATUS.model_specific_errors = @{}
                                $IA32_MCi_STATUS.reserved_error_status_other_information = @{}

                                # Model specific errors
                                $machine_check_error_codes = @{
                                    "00h" = "No Error"
                                    "03h" = "Reset firmware did not complete"
                                    "08h" = "Received an invalid CMPD"
                                    "0Ah" = "Invalid Power Management Request"
                                    "0Dh" = "Invalid S-state transition"
                                    "11h" = "VID controller does not match POC controller selected"
                                    "1Ah" = "MSID from POC does not match CPU MSID"
                                }
                                $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error", $machine_check_error_codes.("{0:X2}h" -f [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 31 24), 2)))
                                if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error) {
                                    $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "Reserved"
                                }
                                break
                            }

                            # Memory Controller Errors
                            { ($parsed_data.bank -eq "8") } {
                                $incremental_decoding_information = "Yes"

                                # Reset "Model specific errors" and "Reserved, Error Status, and Other information"
                                $IA32_MCi_STATUS.model_specific_errors = @{}
                                $IA32_MCi_STATUS.reserved_error_status_other_information = @{}

                                if ($IA32_MCi_STATUS.mca_error_codes.Error_Code -eq "Memory Controller Errors") { # 000F 0000 1MMM CCCC
                                    # Model specific errors
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Read_ECC_error", (Read-Register $IA32_MCi_STATUS_MSR 16))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("RAS_ECC_error", (Read-Register $IA32_MCi_STATUS_MSR 17))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Write_parity_error", (Read-Register $IA32_MCi_STATUS_MSR 18))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Redundancy_loss", (Read-Register $IA32_MCi_STATUS_MSR 19))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Memory_range_error", (Read-Register $IA32_MCi_STATUS_MSR 21))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("RTID_out_of_range", (Read-Register $IA32_MCi_STATUS_MSR 22))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Address_parity_error", (Read-Register $IA32_MCi_STATUS_MSR 23))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Byte_enable_parity_error", (Read-Register $IA32_MCi_STATUS_MSR 24))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("RTId", [System.Convert]::ToInt16((Read-Register $IA32_MCi_MISC_MSR 7 0), 2))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("DIMM", [System.Convert]::ToInt16((Read-Register $IA32_MCi_MISC_MSR 17 16), 2))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Channel", [System.Convert]::ToInt16((Read-Register $IA32_MCi_MISC_MSR 19 18), 2))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Syndrome", (Read-Register $IA32_MCi_MISC_MSR 63 32))

                                    # Other information
                                    $IA32_MCi_STATUS.reserved_error_status_other_information.Add("CORE_ERR_CNT", [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 52 38), 2))
                                }
                                break
                            }
                        }

                        break
                    }

                    # Processor Signature 06_2DH (Sandy Bridge)
                    { $ProcessorSignature -in @("06_2DH") } {
                        Switch ($parsed_data.bank) {
                            # Internal Machine Check Errors
                            { $parsed_data.bank -eq "4" } {
                                $incremental_decoding_information = "Yes"

                                # Reset "Model specific errors" and "Reserved, Error Status, and Other information"
                                $IA32_MCi_STATUS.model_specific_errors = @{}
                                $IA32_MCi_STATUS.reserved_error_status_other_information = @{}

                                # Model specific errors
                                $model_specific_error_codes1 = @{
                                    "0000" = "No Error"
                                    "0001" = "Non_IMem_Sel"
                                    "0010" = "I_Parity_Error"
                                    "0011" = "Bad_OpCode"
                                    "0100" = "I_Stack_Underflow"
                                    "0101" = "I_Stack_Overflow"
                                    "0110" = "D_Stack_Underflow"
                                    "0111" = "D_Stack_Overflow"
                                    "1000" = "Non-DMem_Sel"
                                    "1001" = "D_Parity_Error"
                                }
                                $model_specific_error_codes2 = @{
                                    "00h" = "No Error"
                                    "0Dh" = "MC_IMC_FORCE_SR_S3_TIMEOUT"
                                    "0Eh" = "MC_CPD_UNCPD_ST_TIMEOUT"
                                    "0Fh" = "MC_PKGS_SAFE_WP_TIMEOUT"
                                    "43h" = "MC_PECI_MAILBOX_QUIESCE_TIMEOUT"
                                    "5Ch" = "MC_MORE_THAN_ONE_LT_AGENT"
                                    "60h" = "MC_INVALID_PKGS_REQ_PCH"
                                    "61h" = "MC_INVALID_PKGS_REQ_QPI"
                                    "62h" = "MC_INVALID_PKGS_RES_QPI"
                                    "63h" = "MC_INVALID_PKGC_RES_PCH"
                                    "64h" = "MC_INVALID_PKG_STATE_CONFIG"
                                    "70h" = "MC_WATCHDG_TIMEOUT_PKGC_SLAVE"
                                    "71h" = "MC_WATCHDG_TIMEOUT_PKGC_MASTER"
                                    "72h" = "MC_WATCHDG_TIMEOUT_PKGS_MASTER"
                                    "7Ah" = "MC_HA_FAILSTS_CHANGE_DETECTED"
                                    "81h" = "MC_RECOVERABLE_DIE_THERMAL_TOO_HOT"
                                }
                                $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error1", $model_specific_error_codes1.(Read-Register $IA32_MCi_STATUS_MSR 19 16))
                                if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error1) {
                                    $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error1 = "Reserved"
                                }
                                $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error2", $model_specific_error_codes2.("{0:X2}h" -f [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 31 24), 2)))
                                if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error2) {
                                    $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error2 = "Reserved"
                                }
                                break
                            }

                            # Intel QPI Machine Check Errors
                            { $parsed_data.bank -in @("6", "7") } {
                                if ($IA32_MCi_STATUS.mca_error_codes.Error_Code -eq "Bus and Interconnect Errors") { # 000F 1PPT RRRR IILL
                                    $incremental_decoding_information = "Yes"

                                    # Reset "Model specific errors" and "Reserved, Error Status, and Other information"
                                    $IA32_MCi_STATUS.model_specific_errors = @{}
                                    $IA32_MCi_STATUS.reserved_error_status_other_information = @{}
                                }
                                break
                            }

                            # Integrated Memory Controller Machine Check Errors
                            { $parsed_data.bank -in @("8", "11") } {
                                if ($IA32_MCi_STATUS.mca_error_codes.Error_Code -eq "Memory Controller Errors") { # 000F 0000 1MMM CCCC
                                    $incremental_decoding_information = "Yes"

                                    # Reset "Model specific errors" and (parts of) "Reserved, Error Status, and Other information"
                                    $IA32_MCi_STATUS.model_specific_errors = @{}
                                    $IA32_MCi_STATUS.reserved_error_status_other_information.Remove("Firmware_updated_error_status_indicator")

                                    # Model specific errors
                                    $model_specific_error_codes = @{
                                        "001H" = "Address parity error"
                                        "002H" = "HA Wrt buffer Data parity error"
                                        "004H" = "HA Wrt byte enable parity error"
                                        "008H" = "Corrected patrol scrub error"
                                        "010H" = "Uncorrected patrol scrub error"
                                        "020H" = "Corrected spare error"
                                        "040H" = "Uncorrected spare error"
                                    }
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error", $model_specific_error_codes.("{0:X3}H" -f [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 31 16), 2)))
                                    if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error) {
                                        $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "Reserved"
                                    }
                                    # When MSR_ERROR_CONTROL.[1] is set (ESXi does not expose the MSR_ERROR_CONTROL register currently)
                                    if ($MSR_ERROR_CONTROL.1 -eq "1") {
                                        $IA32_MCi_STATUS.model_specific_errors.Add("ErrMask_1stErrDev", (Read-Register $IA32_MCi_MISC_MSR 29 14))
                                        $IA32_MCi_STATUS.model_specific_errors.Add("ErrMask_2ndErrDev", (Read-Register $IA32_MCi_MISC_MSR 45 30))
                                        $IA32_MCi_STATUS.model_specific_errors.Add("FailRank_1stErrDev", (Read-Register $IA32_MCi_MISC_MSR 50 46))
                                        $IA32_MCi_STATUS.model_specific_errors.Add("FailRank_2ndErrDev", (Read-Register $IA32_MCi_MISC_MSR 55 51))
                                        $IA32_MCi_STATUS.model_specific_errors.Add("Valid_1stErrDev", (Read-Register $IA32_MCi_MISC_MSR 62))
                                        if ($IA32_MCi_STATUS.model_specific_errors.Valid_1stErrDev -eq "1") {
                                            $IA32_MCi_STATUS.model_specific_errors.Add("Valid_2ndErrDev", (Read-Register $IA32_MCi_MISC_MSR 63))
                                        }
                                        # IA32_MCi_STATUS [36:32] allows the iMC to log first device error when corrected error is detected during normal read.
                                        if ($IA32_MCi_STATUS.model_specific_errors.Valid_1stErrDev -eq "1") {
                                            $IA32_MCi_STATUS.model_specific_errors.Add("1stErrDev", (Read-Register $IA32_MCi_STATUS_MSR 36 32))
                                        }
                                        # IA32_MCi_MISC [13:9] allows the iMC to log second device error when corrected error is detected during normal read.
                                        if ($IA32_MCi_STATUS.model_specific_errors.Valid_2ndErrDev -eq "1") {
                                            $IA32_MCi_STATUS.model_specific_errors.Add("2ndErrDev", (Read-Register $IA32_MCi_MISC_MSR 13 9))
                                        }
                                        # Otherwise IA32_MCi_MISC [13:9] contain parity error if MCi_Status indicates HA_WB_Data or HA_W_BE parity error.
                                        else {
                                            if ($IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error -in @("HA Wrt buffer Data parity error", "HA Wrt byte enable parity error")) {
                                                $IA32_MCi_STATUS.model_specific_errors.Add("Parity_Error", (Read-Register $IA32_MCi_MISC_MSR 13 9))
                                            }
                                        }
                                    }
                                }
                                break
                            }
                        }

                        break
                    }

                    # Processor Signature 06_3EH
                    # Intel Xeon processor E5 v2 family and Intel Xeon processor E7 v2 family are based on the Ivy Bridge-EP microarchitecture.
                    { $ProcessorSignature -in @("06_3EH") } {
                        Switch ($parsed_data.bank) {
                            # Internal Machine Check Errors
                            { $parsed_data.bank -eq "4" } {
                                $incremental_decoding_information = "Yes"

                                # Reset "Model specific errors" and "Reserved, Error Status, and Other information"
                                $IA32_MCi_STATUS.model_specific_errors = @{}
                                $IA32_MCi_STATUS.reserved_error_status_other_information = @{}

                                # Model specific errors
                                $model_specific_error_codes1 = @{
                                    "0000" = "No Error"
                                    "0001" = "Non_IMem_Sel"
                                    "0010" = "I_Parity_Error"
                                    "0011" = "Bad_OpCode"
                                    "0100" = "I_Stack_Underflow"
                                    "0101" = "I_Stack_Overflow"
                                    "0110" = "D_Stack_Underflow"
                                    "0111" = "D_Stack_Overflow"
                                    "1000" = "Non-DMem_Sel"
                                    "1001" = "D_Parity_Error"
                                }
                                $model_specific_error_codes2 = @{
                                    "00h" = "No Error"
                                    "0Dh" = "MC_IMC_FORCE_SR_S3_TIMEOUT"
                                    "0Eh" = "MC_CPD_UNCPD_ST_TIMEOUT"
                                    "0Fh" = "MC_PKGS_SAFE_WP_TIMEOUT"
                                    "43h" = "MC_PECI_MAILBOX_QUIESCE_TIMEOUT"
                                    "44h" = "MC_CRITICAL_VR_FAILED"
                                    "45h" = "MC_ICC_MAX-NOTSUPPORTED"
                                    "5Ch" = "MC_MORE_THAN_ONE_LT_AGENT"
                                    "60h" = "MC_INVALID_PKGS_REQ_PCH"
                                    "61h" = "MC_INVALID_PKGS_REQ_QPI"
                                    "62h" = "MC_INVALID_PKGS_RES_QPI"
                                    "63h" = "MC_INVALID_PKGC_RES_PCH"
                                    "64h" = "MC_INVALID_PKG_STATE_CONFIG"
                                    "70h" = "MC_WATCHDG_TIMEOUT_PKGC_SLAVE"
                                    "71h" = "MC_WATCHDG_TIMEOUT_PKGC_MASTER"
                                    "72h" = "MC_WATCHDG_TIMEOUT_PKGS_MASTER"
                                    "7Ah" = "MC_HA_FAILSTS_CHANGE_DETECTED"
                                    "7Bh" = "MC_PCIE_R2PCIE-RW_BLOCK_ACK_TIMEOUT"
                                    "81h" = "MC_RECOVERABLE_DIE_THERMAL_TOO_HOT"
                                }
                                $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error1", $model_specific_error_codes1.(Read-Register $IA32_MCi_STATUS_MSR 19 16))
                                if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error1) {
                                    $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error1 = "Reserved"
                                }
                                $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error2", $model_specific_error_codes2.("{0:X2}h" -f [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 31 24), 2)))
                                if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error2) {
                                    $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error2 = "Reserved"
                                }
                                break
                            }

                            # Integrated Memory Controller Machine Check Errors
                            { $parsed_data.bank -in @("9", "10", "11", "12", "13", "14", "15", "16") } {
                                if ($IA32_MCi_STATUS.mca_error_codes.Error_Code -eq "Memory Controller Errors") { # 000F 0000 1MMM CCCC
                                    $incremental_decoding_information = "Yes"

                                    # Reset "Model specific errors" and (parts of) "Reserved, Error Status, and Other information"
                                    $IA32_MCi_STATUS.model_specific_errors = @{}
                                    $IA32_MCi_STATUS.reserved_error_status_other_information.Remove("Firmware_updated_error_status_indicator")

                                    # Model specific errors
                                    $model_specific_error_codes = @{
                                        "001H" = "Address parity error"
                                        "002H" = "HA Wrt buffer Data parity error"
                                        "004H" = "HA Wrt byte enable parity error"
                                        "008H" = "Corrected patrol scrub error"
                                        "010H" = "Uncorrected patrol scrub error"
                                        "020H" = "Corrected spare error"
                                        "040H" = "Uncorrected spare error"
                                        "080H" = "Corrected memory read error." # Only applicable with iMC’s “Additional Error logging” Mode-1 enabled.
                                        "100H" = "iMC, WDB, parity errors"
                                    }
                                    # When MSR_ERROR_CONTROL.[1] is set (ESXi does not expose the MSR_ERROR_CONTROL register currently)
                                    if ($MSR_ERROR_CONTROL.1 -eq "1") {
                                        $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error", $model_specific_error_codes.("{0:X3}H" -f [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 31 16), 2)))
                                        if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error) {
                                            $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "Reserved"
                                        }
                                        $IA32_MCi_STATUS.model_specific_errors.Add("ErrMask_1stErrDev", (Read-Register $IA32_MCi_MISC_MSR 29 14))
                                        $IA32_MCi_STATUS.model_specific_errors.Add("ErrMask_2ndErrDev", (Read-Register $IA32_MCi_MISC_MSR 45 30))
                                        $IA32_MCi_STATUS.model_specific_errors.Add("FailRank_1stErrDev", (Read-Register $IA32_MCi_MISC_MSR 50 46))
                                        $IA32_MCi_STATUS.model_specific_errors.Add("FailRank_2ndErrDev", (Read-Register $IA32_MCi_MISC_MSR 55 51))
                                        $IA32_MCi_STATUS.model_specific_errors.Add("Valid_1stErrDev", (Read-Register $IA32_MCi_MISC_MSR 62))
                                        if ($IA32_MCi_STATUS.model_specific_errors.Valid_1stErrDev -eq "1") {
                                            $IA32_MCi_STATUS.model_specific_errors.Add("Valid_2ndErrDev", (Read-Register $IA32_MCi_MISC_MSR 63))
                                        }
                                        # IA32_MCi_STATUS [36:32] logs an encoded value from the first error device.
                                        if ($IA32_MCi_STATUS.model_specific_errors.Valid_1stErrDev -eq "1") {
                                            $IA32_MCi_STATUS.model_specific_errors.Add("1stErrDev", (Read-Register $IA32_MCi_STATUS_MSR 36 32))
                                        }
                                        # IA32_MCi_MISC [13:9] if the second error logged is a correctable read error, MC logs the second error device in this field.
                                        if ($IA32_MCi_STATUS.model_specific_errors.Valid_2ndErrDev -eq "1") {
                                            $IA32_MCi_STATUS.model_specific_errors.Add("2ndErrDev", (Read-Register $IA32_MCi_MISC_MSR 13 9))
                                        }
                                        # IA32_MCi_MISC [13:9] If the error logged is MCWrDataPar error or MCWrBEPar error, this field is the WDB ID that has the parity error.
                                        else {
                                            if ($IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error -in @("HA Wrt buffer Data parity error", "HA Wrt byte enable parity error")) {
                                                $IA32_MCi_STATUS.model_specific_errors.Add("WDB_ID", (Read-Register $IA32_MCi_MISC_MSR 13 9))
                                            }
                                        }
                                    }
                                    else {
                                        # iMC’s Additional Error logging Mode-1 was not enabled.
                                        $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error += " (not applicable)"
                                    }
                                }
                                break
                            }
                        }

                        break
                    }

                    # Processor Signature 06_3FH
                    # Intel Xeon processor E5 v3 family is based on the Haswell-E microarchitecture.
                    { $ProcessorSignature -in @("06_3FH") } {
                        Switch ($parsed_data.bank) {
                            # Internal Machine Check Errors
                            { $parsed_data.bank -eq "4" } {
                                $incremental_decoding_information = "Yes"

                                # Reset "MCA (machine-check architecture) error code field", "Model specific errors" and "Reserved, Error Status, and Other information"
                                $IA32_MCi_STATUS.mca_error_codes.Type = $null
                                $IA32_MCi_STATUS.mca_error_codes.Error_Code = $null
                                $IA32_MCi_STATUS.mca_error_codes.Meaning = $null
                                $IA32_MCi_STATUS.model_specific_errors = @{}
                                $IA32_MCi_STATUS.reserved_error_status_other_information = @{}

                                # MCA Error Codes
                                $internal_errors = @{
                                    "0402h" = "PCU internal Errors"
                                    "0403h" = "PCU internal Errors"
                                    "0406h" = "Intel TXT Errors"
                                    "0407h" = "Other UBOX internal Errors"
                                }
                                $IA32_MCi_STATUS.mca_error_codes.Error_Code = $internal_errors.("{0:X4}h" -f [System.Convert]::ToInt16($IA32_MCi_STATUS.mca_error_codes.Binary_Encoding, 2))
                                if ($IA32_MCi_STATUS.mca_error_codes.Error_Code) {
                                    $IA32_MCi_STATUS.mca_error_codes.Type = "Simple"
                                }
                                else {
                                    Write-Warning "MCA Error Code could not be identified during incremental decoding MCA information, stop decoding."
                                    return
                                }

                                # Model specific errors
                                $model_specific_error_codes1 = @{
                                    "0000" = "No Error"
                                    "0001" = "PCU internal error"
                                    "0010" = "PCU internal error"
                                    "0011" = "PCU internal error"
                                }
                                $model_specific_error_codes2 = @{
                                    "00h" = "No Error"
                                    "09h" = "MC_MESSAGE_CHANNEL_TIMEOUT"
                                    "13h" = "MC_DMI_TRAINING_TIMEOUT"
                                    "15h" = "MC_DMI_CPU_RESET_ACK_TIMEOUT"
                                    "1Eh" = "MC_VR_ICC_MAX_LT_FUSED_ICC_MAX"
                                    "25h" = "MC_SVID_COMMAND_TIMEOUT"
                                    "29h" = "MC_VR_VOUT_MAC_LT_FUSED_SVID"
                                    "2Bh" = "MC_PKGC_WATCHDOG_HANG_CBZ_DOWN"
                                    "2Ch" = "MC_PKGC_WATCHDOG_HANG_CBZ_UP"
                                    "44h" = "MC_CRITICAL_VR_FAILED"
                                    "46h" = "MC_VID_RAMP_DOWN_FAILED"
                                    "49h" = "MC_SVID_WRITE_REG_VOUT_MAX_FAILED"
                                    "4Bh" = "MC_BOOT_VID_TIMEOUT. Timeout setting boot VID for DRAM 0."
                                    "4Fh" = "MC_SVID_COMMAND_ERROR."
                                    "52h" = "MC_FIVR_CATAS_OVERVOL_FAULT."
                                    "53h" = "MC_FIVR_CATAS_OVERCUR_FAULT."
                                    "57h" = "MC_SVID_PKGC_REQUEST_FAILED"
                                    "58h" = "MC_SVID_IMON_REQUEST_FAILED"
                                    "59h" = "MC_SVID_ALERT_REQUEST_FAILED"
                                    "62h" = "MC_INVALID_PKGS_RSP_QPI"
                                    "64h" = "MC_INVALID_PKG_STATE_CONFIG"
                                    "67h" = "MC_HA_IMC_RW_BLOCK_ACK_TIMEOUT"
                                    "6Ah" = "MC_MSGCH_PMREQ_CMP_TIMEOUT"
                                    "72h" = "MC_WATCHDG_TIMEOUT_PKGS_MASTER"
                                    "81h" = "MC_RECOVERABLE_DIE_THERMAL_TOO_HOT"
                                }
                                $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error1", $model_specific_error_codes1.(Read-Register $IA32_MCi_STATUS_MSR 19 16))
                                if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error1) {
                                    $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error1 = "Reserved"
                                }
                                $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error2", $model_specific_error_codes2.("{0:X2}h" -f [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 31 24), 2)))
                                if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error2) {
                                    $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error2 = "Reserved"
                                }
                                break
                            }

                            # Intel QPI Machine Check Errors
                            { $parsed_data.bank -in @("5", "20", "21") } {
                                if ($IA32_MCi_STATUS.mca_error_codes.Error_Code -eq "Bus and Interconnect Errors") { # 000F 1PPT RRRR IILL
                                    $incremental_decoding_information = "Yes"

                                    # Reset "Model specific errors" and "Reserved, Error Status, and Other information"
                                    $IA32_MCi_STATUS.model_specific_errors = @{}
                                    $IA32_MCi_STATUS.reserved_error_status_other_information = @{}

                                    # Model specific errors
                                    $model_specific_error_codes = @{
                                        "02h" = "Intel QPI physical layer detected drift buffer alarm."
                                        "03h" = "Intel QPI physical layer detected latency buffer rollover."
                                        "10h" = "Intel QPI link layer detected control error from R3QPI."
                                        "11h" = "Rx entered LLR abort state on CRC error."
                                        "12h" = "Unsupported or undefined packet."
                                        "13h" = "Intel QPI link layer control error."
                                        "15h" = "RBT used un-initialized value."
                                        "20h" = "Intel QPI physical layer detected a QPI in-band reset but aborted initialization"
                                        "21h" = "Link failover data self-healing"
                                        "22h" = "Phy detected in-band reset (no width change)."
                                        "23h" = "Link failover clock failover"
                                        "30h" = "Rx detected CRC error - successful LLR after Phy re-init."
                                        "31h" = "Rx detected CRC error - successful LLR without Phy re-init."
                                    }
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error", $model_specific_error_codes.("{0:X2}h" -f [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 31 16), 2)))
                                    if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error) {
                                        $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "Reserved"
                                    }
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Corrected_Error_Cnt", [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 52 38), 2))
                                }
                                break
                            }

                            # Integrated Memory Controller Machine Check Errors
                            { $parsed_data.bank -in @("9", "10", "11", "12", "13", "14", "15", "16") } {
                                if ($IA32_MCi_STATUS.mca_error_codes.Error_Code -eq "Memory Controller Errors") { # 000F 0000 1MMM CCCC
                                    $incremental_decoding_information = "Yes"

                                    # Reset "Model specific errors" and (parts of) "Reserved, Error Status, and Other information"
                                    $IA32_MCi_STATUS.model_specific_errors = @{}
                                    $IA32_MCi_STATUS.reserved_error_status_other_information.Remove("Firmware_updated_error_status_indicator")

                                    # Model specific errors
                                    $model_specific_error_codes = @{
                                        "0001H" = "DDR3 address parity error"
                                        "0002H" = "Uncorrected HA write data error"
                                        "0004H" = "Uncorrected HA data byte enable error"
                                        "0008H" = "Corrected patrol scrub error"
                                        "0010H" = "Uncorrected patrol scrub error"
                                        "0020H" = "Corrected spare error"
                                        "0040H" = "Uncorrected spare error"
                                        "0080H" = "Corrected memory read error." # Only applicable with iMC’s "Additional Error logging" Mode-1 enabled.
                                        "0100H" = "iMC, write data buffer parity errors"
                                        "0200H" = "DDR4 command address parity error"
                                    }
                                    # When MSR_ERROR_CONTROL.[1] is set (ESXi does not expose the MSR_ERROR_CONTROL register currently)
                                    if ($MSR_ERROR_CONTROL.1 -eq "1") {
                                        $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error", $model_specific_error_codes.("{0:X4}H" -f [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 31 16), 2)))
                                        if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error) {
                                            $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "Reserved"
                                        }
                                        $IA32_MCi_STATUS.model_specific_errors.Add("ErrMask_1stErrDev", (Read-Register $IA32_MCi_MISC_MSR 29 14))
                                        $IA32_MCi_STATUS.model_specific_errors.Add("ErrMask_2ndErrDev", (Read-Register $IA32_MCi_MISC_MSR 45 30))
                                        $IA32_MCi_STATUS.model_specific_errors.Add("FailRank_1stErrDev", (Read-Register $IA32_MCi_MISC_MSR 50 46))
                                        $IA32_MCi_STATUS.model_specific_errors.Add("FailRank_2ndErrDev", (Read-Register $IA32_MCi_MISC_MSR 55 51))
                                        $IA32_MCi_STATUS.model_specific_errors.Add("Valid_1stErrDev", (Read-Register $IA32_MCi_MISC_MSR 62))
                                        if ($IA32_MCi_STATUS.model_specific_errors.Valid_1stErrDev -eq "1") {
                                            $IA32_MCi_STATUS.model_specific_errors.Add("Valid_2ndErrDev", (Read-Register $IA32_MCi_MISC_MSR 63))
                                        }
                                        # IA32_MCi_STATUS [36:32] logs an encoded value from the first error device.
                                        if ($IA32_MCi_STATUS.model_specific_errors.Valid_1stErrDev -eq "1") {
                                            $IA32_MCi_STATUS.model_specific_errors.Add("1stErrDev", (Read-Register $IA32_MCi_STATUS_MSR 36 32))
                                        }
                                        # IA32_MCi_MISC [13:9] if the second error logged is a correctable read error, MC logs the second error device in this field.
                                        if ($IA32_MCi_STATUS.model_specific_errors.Valid_2ndErrDev -eq "1") {
                                            $IA32_MCi_STATUS.model_specific_errors.Add("2ndErrDev", (Read-Register $IA32_MCi_MISC_MSR 13 9))
                                        }
                                        # IA32_MCi_MISC [13:9] If the error logged is MCWrDataPar error or MCWrBEPar error, this field is the WDB ID that has the parity error.
                                        else {
                                            if ($IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error -in @("Uncorrected HA write data error", "Uncorrected HA data byte enable error")) {
                                                $IA32_MCi_STATUS.model_specific_errors.Add("WDB_ID", (Read-Register $IA32_MCi_MISC_MSR 13 9))
                                            }
                                        }
                                    }
                                    else {
                                        # iMC’s Additional Error logging Mode-1 was not enabled.
                                        $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error += " (not applicable)"
                                    }
                                }
                                break
                            }
                        }

                        break
                    }

                    # Processor Signature 06_56H
                    # Intel Xeon processor D family is based on the Broadwell microarchitecture.
                    { $ProcessorSignature -in @("06_56H") } {
                        Switch ($parsed_data.bank) {
                            # Internal Machine Check Errors
                            { $parsed_data.bank -eq "4" } {
                                $incremental_decoding_information = "Yes"

                                # Reset "MCA (machine-check architecture) error code field", "Model specific errors" and "Reserved, Error Status, and Other information"
                                $IA32_MCi_STATUS.mca_error_codes.Type = $null
                                $IA32_MCi_STATUS.mca_error_codes.Error_Code = $null
                                $IA32_MCi_STATUS.mca_error_codes.Meaning = $null
                                $IA32_MCi_STATUS.model_specific_errors = @{}
                                $IA32_MCi_STATUS.reserved_error_status_other_information = @{}

                                # MCA Error Codes
                                $internal_errors = @{
                                    "0402h" = "PCU internal Errors"
                                    "0403h" = "internal Errors"
                                    "0406h" = "Intel TXT Errors"
                                    "0407h" = "Other UBOX internal Errors"
                                }
                                $IA32_MCi_STATUS.mca_error_codes.Error_Code = $internal_errors.("{0:X4}h" -f [System.Convert]::ToInt16($IA32_MCi_STATUS.mca_error_codes.Binary_Encoding, 2))
                                if ($IA32_MCi_STATUS.mca_error_codes.Error_Code) {
                                    $IA32_MCi_STATUS.mca_error_codes.Type = "Simple"
                                }
                                else {
                                    Write-Warning "MCA Error Code could not be identified during incremental decoding MCA information, stop decoding."
                                    return
                                }

                                # Model specific errors
                                $model_specific_error_codes1 = @{
                                    "0000" = "No Error"
                                    "0001" = "PCU internal error"
                                    "0010" = "PCU internal error"
                                    "0011" = "PCU internal error"
                                }
                                $model_specific_error_codes2 = @{
                                    "00h" = "No Error"
                                    "09h" = "MC_MESSAGE_CHANNEL_TIMEOUT"
                                    "13h" = "MC_DMI_TRAINING_TIMEOUT"
                                    "15h" = "MC_DMI_CPU_RESET_ACK_TIMEOUT"
                                    "1Eh" = "MC_VR_ICC_MAX_LT_FUSED_ICC_MAX"
                                    "25h" = "MC_SVID_COMMAND_TIMEOUT"
                                    "26h" = "MCA_PKGC_DIRECT_WAKE_RING_TIMEOUT"
                                    "29h" = "MC_VR_VOUT_MAC_LT_FUSED_SVID"
                                    "2Bh" = "MC_PKGC_WATCHDOG_HANG_CBZ_DOWN"
                                    "2Ch" = "MC_PKGC_WATCHDOG_HANG_CBZ_UP"
                                    "44h" = "MC_CRITICAL_VR_FAILED"
                                    "46h" = "MC_VID_RAMP_DOWN_FAILED"
                                    "49h" = "MC_SVID_WRITE_REG_VOUT_MAX_FAILED"
                                    "4Bh" = "MC_PP1_BOOT_VID_TIMEOUT. Timeout setting boot VID for DRAM 0."
                                    "4Fh" = "MC_SVID_COMMAND_ERROR."
                                    "52h" = "MC_FIVR_CATAS_OVERVOL_FAULT."
                                    "53h" = "MC_FIVR_CATAS_OVERCUR_FAULT."
                                    "57h" = "MC_SVID_PKGC_REQUEST_FAILED"
                                    "58h" = "MC_SVID_IMON_REQUEST_FAILED"
                                    "59h" = "MC_SVID_ALERT_REQUEST_FAILED"
                                    "62h" = "MC_INVALID_PKGS_RSP_QPI"
                                    "64h" = "MC_INVALID_PKG_STATE_CONFIG"
                                    "67h" = "MC_HA_IMC_RW_BLOCK_ACK_TIMEOUT"
                                    "6Ah" = "MC_MSGCH_PMREQ_CMP_TIMEOUT"
                                    "72h" = "MC_WATCHDG_TIMEOUT_PKGS_MASTER"
                                    "81h" = "MC_RECOVERABLE_DIE_THERMAL_TOO_HOT"
                                }
                                $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error1", $model_specific_error_codes1.(Read-Register $IA32_MCi_STATUS_MSR 19 16))
                                if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error1) {
                                    $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error1 = "Reserved"
                                }
                                $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error2", $model_specific_error_codes2.("{0:X2}h" -f [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 31 24), 2)))
                                if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error2) {
                                    $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error2 = "Reserved"
                                }
                                break
                            }

                            # Integrated Memory Controller Machine Check Errors
                            { $parsed_data.bank -in @("9", "10") } {
                                if ($IA32_MCi_STATUS.mca_error_codes.Error_Code -eq "Memory Controller Errors") { # 000F 0000 1MMM CCCC
                                    $incremental_decoding_information = "Yes"

                                    # Reset "Model specific errors" and (parts of) "Reserved, Error Status, and Other information"
                                    $IA32_MCi_STATUS.model_specific_errors = @{}
                                    $IA32_MCi_STATUS.reserved_error_status_other_information.Remove("Firmware_updated_error_status_indicator")

                                    # Model specific errors
                                    $model_specific_error_codes = @{
                                        "0001H" = "DDR3 address parity error"
                                        "0002H" = "Uncorrected HA write data error"
                                        "0004H" = "Uncorrected HA data byte enable error"
                                        "0008H" = "Corrected patrol scrub error"
                                        "0010H" = "Uncorrected patrol scrub error"
                                        "0100H" = "iMC, write data buffer parity errors"
                                        "0200H" = "DDR4 command address parity error"
                                    }
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error", $model_specific_error_codes.("{0:X4}H" -f [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 31 16), 2)))
                                    if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error) {
                                        $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "Reserved"
                                    }
                                }
                                break
                            }
                        }

                        break
                    }

                    # Processor Signature 06_4FH
                    # Next Generation Intel Xeon processor E5 family is based on the Broadwell microarchitecture.
                    { $ProcessorSignature -in @("06_4FH") } {
                        Switch ($parsed_data.bank) {
                            # Integrated Memory Controller Machine Check Errors
                            { $parsed_data.bank -in @("9", "10", "11", "12", "13", "14", "15", "16") } {
                                if ($IA32_MCi_STATUS.mca_error_codes.Error_Code -eq "Memory Controller Errors") { # 000F 0000 1MMM CCCC
                                    $incremental_decoding_information = "Yes"

                                    # Reset "Model specific errors" and (parts of) "Reserved, Error Status, and Other information"
                                    $IA32_MCi_STATUS.model_specific_errors = @{}
                                    $IA32_MCi_STATUS.reserved_error_status_other_information.Remove("Firmware_updated_error_status_indicator")

                                    # Model specific errors
                                    $model_specific_error_codes = @{
                                        "0001H" = "DDR3 address parity error"
                                        "0002H" = "Uncorrected HA write data error"
                                        "0004H" = "Uncorrected HA data byte enable error"
                                        "0008H" = "Corrected patrol scrub error"
                                        "0010H" = "Uncorrected patrol scrub error"
                                        "0020H" = "Corrected spare error"
                                        "0040H" = "Uncorrected spare error"
                                        "0100H" = "iMC, write data buffer parity errors"
                                        "0200H" = "DDR4 command address parity error"
                                    }
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error", $model_specific_error_codes.("{0:X4}H" -f [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 31 16), 2)))
                                    if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error) {
                                        $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "Reserved"
                                    }
                                }
                                break
                            }

                            # Home Agent Machine Check Errors
                            { $parsed_data.bank -in @("7", "8") } {
                                $incremental_decoding_information = "Yes"

                                # Model specific errors
                                $IA32_MCi_STATUS.model_specific_errors.Add("Failover", (Read-Register $IA32_MCi_MISC_MSR 41))
                                $IA32_MCi_STATUS.model_specific_errors.Add("Mirrorcorr", (Read-Register $IA32_MCi_MISC_MSR 42))
                                break
                            }
                        }

                        break
                    }

                    # Processor Signature 06_55H
                    # In future Intel Xeon processors
                    { $ProcessorSignature -in @("06_55H") } {
                        Switch ($parsed_data.bank) {
                            # Internal Machine Check Errors
                            { $parsed_data.bank -eq "4" } {
                                $incremental_decoding_information = "Yes"

                                # Reset "MCA (machine-check architecture) error code field", "Model specific errors" and "Reserved, Error Status, and Other information"
                                $IA32_MCi_STATUS.mca_error_codes.Type = $null
                                $IA32_MCi_STATUS.mca_error_codes.Error_Code = $null
                                $IA32_MCi_STATUS.mca_error_codes.Meaning = $null
                                $IA32_MCi_STATUS.model_specific_errors = @{}
                                $IA32_MCi_STATUS.reserved_error_status_other_information = @{}

                                # MCA Error Codes
                                $internal_errors = @{
                                    "0402h" = "PCU internal Errors"
                                    "0403h" = "PCU internal Errors"
                                    "0406h" = "Intel TXT Errors"
                                    "0407h" = "Other UBOX internal Errors"
                                }
                                $IA32_MCi_STATUS.mca_error_codes.Error_Code = $internal_errors.("{0:X4}h" -f [System.Convert]::ToInt16($IA32_MCi_STATUS.mca_error_codes.Binary_Encoding, 2))
                                if ($IA32_MCi_STATUS.mca_error_codes.Error_Code) {
                                    $IA32_MCi_STATUS.mca_error_codes.Type = "Simple"
                                }
                                else {
                                    Write-Warning "MCA Error Code could not be identified during incremental decoding MCA information, stop decoding."
                                    return
                                }

                                # Model specific errors
                                $model_specific_error_codes1 = @{
                                    "0000" = "No Error"
                                    "0001" = "PCU internal error"
                                    "0010" = "PCU internal error"
                                    "0011" = "PCU internal error"
                                }
                                $model_specific_error_codes2 = @{
                                    "00h" = "No Error"
                                    "0Dh" = "MCA_DMI_TRAINING_TIMEOUT"
                                    "0Fh" = "MCA_DMI_CPU_RESET_ACK_TIMEOUT"
                                    "10h" = "MCA_MORE_THAN_ONE_LT_AGENT"
                                    "1Eh" = "MCA_BIOS_RST_CPL_INVALID_SEQ"
                                    "1Fh" = "MCA_BIOS_INVALID_PKG_STATE_CONFIG"
                                    "25h" = "MCA_MESSAGE_CHANNEL_TIMEOUT"
                                    "27h" = "MCA_MSGCH_PMREQ_CMP_TIMEOUT"
                                    "30h" = "MCA_PKGC_DIRECT_WAKE_RING_TIMEOUT"
                                    "31h" = "MCA_PKGC_INVALID_RSP_PCH"
                                    "33h" = "MCA_PKGC_WATCHDOG_HANG_CBZ_DOWN"
                                    "34h" = "MCA_PKGC_WATCHDOG_HANG_CBZ_UP"
                                    "38h" = "MCA_PKGC_WATCHDOG_HANG_C3_UP_SF"
                                    "40h" = "MCA_SVID_VCCIN_VR_ICC_MAX_FAILURE"
                                    "41h" = "MCA_SVID_COMMAND_TIMEOUT"
                                    "42h" = "MCA_SVID_VCCIN_VR_VOUT_MAX_FAILURE"
                                    "43h" = "MCA_SVID_CPU_VR_CAPABILITY_ERROR"
                                    "44h" = "MCA_SVID_CRITICAL_VR_FAILED"
                                    "45h" = "MCA_SVID_SA_ITD_ERROR"
                                    "46h" = "MCA_SVID_READ_REG_FAILED"
                                    "47h" = "MCA_SVID_WRITE_REG_FAILED"
                                    "48h" = "MCA_SVID_PKGC_INIT_FAILED"
                                    "49h" = "MCA_SVID_PKGC_CONFIG_FAILED"
                                    "4Ah" = "MCA_SVID_PKGC_REQUEST_FAILED"
                                    "4Bh" = "MCA_SVID_IMON_REQUEST_FAILED"
                                    "4Ch" = "MCA_SVID_ALERT_REQUEST_FAILED"
                                    "4Dh" = "MCA_SVID_MCP_VP_ABSENT_OR_RAMP_ERROR"
                                    "4Eh" = "MCA_SVID_UNEXPECTED_MCP_VP_DETECTED"
                                    "51h" = "MCA_FIVR_CATAS_OVERVOL_FAULT"
                                    "52h" = "MCA_FIVR_CATAS_OVERCUR_FAULT"
                                    "58h" = "MCA_WATCHDG_TIMEOUT_PKGC_SLAVE"
                                    "59h" = "MCA_WATCHDG_TIMEOUT_PKGC_MASTER"
                                    "5Ah" = "MCA_WATCHDG_TIMEOUT_PKGS_MASTER"
                                    "61h" = "MCA_PKGS_CPD_UNPCD_TIMEOUT"
                                    "63h" = "MCA_PKGS_INVALID_REQ_PCH"
                                    "64h" = "MCA_PKGS_INVALID_REQ_INTERNAL"
                                    "65h" = "MCA_PKGS_INVALID_RSP_INTERNAL"
                                    "6Bh" = "MCA_PKGS_SMBUS_VPP_PAUSE_TIMEOUT"
                                    "81h" = "MC_RECOVERABLE_DIE_THERMAL_TOO_HOT"
                                }
                                $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error1", $model_specific_error_codes1.(Read-Register $IA32_MCi_STATUS_MSR 19 16))
                                if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error1) {
                                    $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error1 = "Reserved"
                                }
                                $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error2", $model_specific_error_codes2.("{0:X2}h" -f [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 31 24), 2)))
                                if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error2) {
                                    $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error2 = "Reserved"
                                }
                                $IA32_MCi_STATUS.model_specific_errors.Add("CORR_ERR_STATUS", (Read-Register $IA32_MCi_STATUS_MSR 54 53))
                                break
                            }

                            # Interconnect Machine Check Errors
                            { $parsed_data.bank -in @("5", "12", "19") } {
                                # The two supported compound error codes: 0x0C0F (Unsupported/Undefined Packet) or 0x0E0F (For all other corrected and uncorrected errors)
                                if (($IA32_MCi_STATUS.mca_error_codes.Error_Code -eq "Bus and Interconnect Errors") -and ($IA32_MCi_STATUS.Binary_Encoding -in @("0000110000001111", "0000111000001111"))) {
                                    $incremental_decoding_information = "Yes"

                                    # Reset "Model specific errors" and "Reserved, Error Status, and Other information"
                                    $IA32_MCi_STATUS.model_specific_errors = @{}
                                    $IA32_MCi_STATUS.reserved_error_status_other_information = @{}

                                    # Model specific errors
                                    $model_specific_error_codes = @{
                                        "00h" = "UC Phy Initialization Failure."
                                        "01h" = "UC Phy detected drift buffer alarm."
                                        "02h" = "UC Phy detected latency buffer rollover."
                                        "10h" = "UC link layer Rx detected CRC error: unsuccessful LLR entered abort state"
                                        "11h" = "UC LL Rx unsupported or undefined packet."
                                        "12h" = "UC LL or Phy control error."
                                        "13h" = "UC LL Rx parameter exchange exception."
                                        "1fh" = "UC LL detected control error from the link-mesh interface"
                                        "20h" = "COR Phy initialization abort"
                                        "21h" = "COR Phy reset"
                                        "22h" = "COR Phy lane failure, recovery in x8 width."
                                        "23h" = "COR Phy L0c error corrected without Phy reset"
                                        "24h" = "COR Phy L0c error triggering Phy reset"
                                        "25h" = "COR Phy L0p exit error corrected with Phy reset"
                                        "30h" = "COR LL Rx detected CRC error - successful LLR without Phy re-init."
                                        "31h" = "COR LL Rx detected CRC error - successful LLR with Phy re-init."
                                    }
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error", $model_specific_error_codes.("{0:x2}h" -f [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 21 16), 2)))
                                    if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error) {
                                        $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "Reserved"
                                    }
                                    if ($IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error -eq "UC LL or Phy control error.") {
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 22) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error =+ " / Phy Control Error" }
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 23) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error += " / Unexpected Retry.Ack flit" }
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 24) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error += " / Unexpected Retry.Req flit" }
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 25) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error += " / RF parity error" }
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 26) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error += " / Routeback Table error" }
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 27) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error += " / unexpected Tx Protocol flit (EOP, Header or Data)" }
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 28) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error += " / Rx Header-or-Credit BGF credit overflow/underflow" }
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 29) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error += " / Link Layer Reset still in progress when Phy enters L0" }
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 30) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error += " / Link Layer reset initiated while protocol traffic not idle" }
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 31) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error += " / Link Layer Tx Parity Error" }
                                    }
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Corrected_Error_Cnt", [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 52 38), 2))
                                }
                                break
                            }

                            # Integrated Memory Controller Machine Check Errors
                            { $parsed_data.bank -in @("13", "14", "15", "16") } {
                                if ($IA32_MCi_STATUS.mca_error_codes.Error_Code -eq "Memory Controller Errors") { # 000F 0000 1MMM CCCC
                                    $incremental_decoding_information = "Yes"

                                    # Reset "Model specific errors" and (parts of) "Reserved, Error Status, and Other information"
                                    $IA32_MCi_STATUS.model_specific_errors = @{}
                                    $IA32_MCi_STATUS.reserved_error_status_other_information.Remove("Firmware_updated_error_status_indicator")

                                    # Model specific errors
                                    $model_specific_error_codes = @{
                                        "0001H" = "Address parity error"
                                        "0002H" = "HA write data parity error"
                                        "0004H" = "HA write byte enable parity error"
                                        "0008H" = "Corrected patrol scrub error"
                                        "0010H" = "Uncorrected patrol scrub error"
                                        "0020H" = "Corrected spare error"
                                        "0040H" = "Uncorrected spare error"
                                        "0080H" = "Any HA read error"
                                        "0100H" = "WDB read parity error"
                                        "0200H" = "DDR4 command address parity error"
                                        "0400H" = "Uncorrected address parity error"
                                        "0800H" = "Unrecognized request type"
                                        "0801H" = "Read response to an invalid scoreboard entry"
                                        "0802H" = "Unexpected read response"
                                        "0803H" = "DDR4 completion to an invalid scoreboard entry"
                                        "0804H" = "Completion to an invalid scoreboard entry"
                                        "0805H" = "Completion FIFO overflow"
                                        "0806H" = "Correctable parity error"
                                        "0807H" = "Uncorrectable error"
                                        "0808H" = "Interrupt received while outstanding interrupt was not ACKed"
                                        "0809H" = "ERID FIFO overflow"
                                        "080aH" = "Error on Write credits"
                                        "080bH" = "Error on Read credits"
                                        "080cH" = "Scheduler error"
                                        "080dH" = "Error event"
                                    }
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error", $model_specific_error_codes.("{0:x4}H" -f [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 31 16), 2)))
                                    if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error) {
                                        $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "Reserved"
                                    }
                                    $IA32_MCi_STATUS.model_specific_errors.Add("1stErrDev", (Read-Register $IA32_MCi_STATUS_MSR 36 32))
                                }
                                break
                            }

                            # M2M Machine Check Errors and Home Agent Machine Check Errors
                            { $parsed_data.bank -in @("7", "8") } {
                                if ($IA32_MCi_STATUS.mca_error_codes.Error_Code -eq "Memory Controller Errors") { # 000F 0000 1MMM CCCC
                                    $incremental_decoding_information = "Yes"

                                    # Reset "Model specific errors" and (parts of) "Reserved, Error Status, and Other information"
                                    $IA32_MCi_STATUS.model_specific_errors = @{}
                                    $IA32_MCi_STATUS.reserved_error_status_other_information.Remove("Firmware_updated_error_status_indicator")

                                    # Model specific errors
                                    $IA32_MCi_STATUS.model_specific_errors.Add("MscodDataRdErr", (Read-Register $IA32_MCi_STATUS_MSR 16))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("MscodPtlWrErr", (Read-Register $IA32_MCi_STATUS_MSR 18))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("MscodFullWrErr", (Read-Register $IA32_MCi_STATUS_MSR 19))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("MscodBgfErr", (Read-Register $IA32_MCi_STATUS_MSR 20))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("MscodTimeOut", (Read-Register $IA32_MCi_STATUS_MSR 21))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("MscodParErr", (Read-Register $IA32_MCi_STATUS_MSR 22))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("MscodBucket1Err", (Read-Register $IA32_MCi_STATUS_MSR 23))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("1stErrDev", (Read-Register $IA32_MCi_STATUS_MSR 36 32))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Mirrorcorr", (Read-Register $IA32_MCi_MISC_MSR 62))
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Failover", (Read-Register $IA32_MCi_MISC_MSR 63))
                                }
                                break
                            }
                        }

                        break
                    }

                    # Processor Signature 06_5FH
                    # In future Intel(R) Atom(TM) processors based on Goldmont Microarchitecture
                    { $ProcessorSignature -in @("06_5FH") } {
                        if ($parsed_data.bank -in @("6", "7")) {
                            # Integrated Memory Controller Machine Check Errors
                            if ($IA32_MCi_STATUS.mca_error_codes.Error_Code -eq "Memory Controller Errors") { # 000F 0000 1MMM CCCC
                                $incremental_decoding_information = "Yes"

                                # Reset "Model specific errors" and (parts of) "Reserved, Error Status, and Other information"
                                $IA32_MCi_STATUS.model_specific_errors = @{}
                                $IA32_MCi_STATUS.reserved_error_status_other_information.Remove("Firmware_updated_error_status_indicator")

                                # Model specific errors
                                $model_specific_error_codes = @{
                                    "01h" = "Cmd/Addr parity"
                                    "02h" = "Corrected Demand/Patrol Scrub Error"
                                    "04h" = "Uncorrected patrol scrub error"
                                    "08h" = "Uncorrected demand read error"
                                    "10h" = "WDB read ECC"
                                }
                                $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error", $model_specific_error_codes.("{0:x2}h" -f [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 31 16), 2)))
                                if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error) {
                                    $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "Reserved"
                                }
                            }
                        }

                        break
                    }

                    # Processor Family 0FH (Pentium IV)
                    { $ProcessorSignature -like "0F_??H" } {
                        Switch ($IA32_MCi_STATUS.mca_error_codes.Error_Code) {
                            "Bus and Interconnect Errors" { # 000F 1PPT RRRR IILL
                                $incremental_decoding_information = "Yes"

                                # Reset "Model specific errors" and "Reserved, Error Status, and Other information"
                                $IA32_MCi_STATUS.model_specific_errors = @{}
                                $IA32_MCi_STATUS.reserved_error_status_other_information = @{}

                                # Model specific errors
                                $IA32_MCi_STATUS.model_specific_errors.Add("FSB_address_parity", (Read-Register $IA32_MCi_STATUS_MSR 16))
                                $IA32_MCi_STATUS.model_specific_errors.Add("Response_hard_fail", (Read-Register $IA32_MCi_STATUS_MSR 17))
                                $IA32_MCi_STATUS.model_specific_errors.Add("Response_parity", (Read-Register $IA32_MCi_STATUS_MSR 18))
                                $IA32_MCi_STATUS.model_specific_errors.Add("PIC_and_FSB_data_parity", (Read-Register $IA32_MCi_STATUS_MSR 19))
                                if ($ProcessorSignature -eq "0F_04H") {
                                    $IA32_MCi_STATUS.model_specific_errors.Add("Invalid_PIC_request", (Read-Register $IA32_MCi_STATUS_MSR 20))
                                }
                                $IA32_MCi_STATUS.model_specific_errors.Add("Pad_state_machine", (Read-Register $IA32_MCi_STATUS_MSR 21))
                                $IA32_MCi_STATUS.model_specific_errors.Add("Pad_strobe_glitch", (Read-Register $IA32_MCi_STATUS_MSR 22))
                                $IA32_MCi_STATUS.model_specific_errors.Add("Pad_address_glitch", (Read-Register $IA32_MCi_STATUS_MSR 23))
                                break
                            }

                            "Cache Hierarchy Errors" { # 000F 0001 RRRR TTLL
                                $incremental_decoding_information = "Yes"

                                # Reset "Model specific errors" and "Reserved, Error Status, and Other information"
                                $IA32_MCi_STATUS.model_specific_errors = @{}
                                $IA32_MCi_STATUS.reserved_error_status_other_information = @{}

                                # Model specific errors (Table 16-10)
                                # $machine_check_error_codes = @{
                                #     "00h" = "No Error"
                                #     "03h" = "Reset firmware did not complete"
                                #     "08h" = "Received an invalid CMPD"
                                #     "0Ah" = "Invalid Power Management Request"
                                #     "0Dh" = "Invalid S-state transition"
                                #     "11h" = "VID controller does not match POC controller selected"
                                #     "1Ah" = "MSID from POC does not match CPU MSID"
                                # }
                                # $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error", $machine_check_error_codes.("{0:X2}h" -f [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 31 24), 2)))

                                # Model specific errors (Table 16-41)
                                $tag_error_code = @{
                                    "00" = "No error detected"
                                    "01" = "Parity error on tag miss with a clean line"
                                    "10" = "Parity error/multiple tag match on tag hit"
                                    "11" = "Parity error/multiple tag match on tag miss"
                                }
                                $data_error_code = @{
                                    "00" = "No error detected"
                                    "01" = "Single bit error"
                                    "10" = "Double bit error on a clean line"
                                    "11" = "Double bit error on a modified line"
                                }
                                $l3_error = @{
                                    "0" = "L2 error"
                                    "1" = "L3 error"
                                }
                                $invalid_pic_request = @{
                                    "1" = "Invalid PIC request error"
                                    "0" = "No invalid PIC request error"
                                }
                                $IA32_MCi_STATUS.model_specific_errors.Add("Tag_Error_Code", $tag_error_code.(Read-Register $IA32_MCi_STATUS_MSR 17 16))
                                $IA32_MCi_STATUS.model_specific_errors.Add("Data_Error_Code", $data_error_code.(Read-Register $IA32_MCi_STATUS_MSR 19 18))
                                $IA32_MCi_STATUS.model_specific_errors.Add("L3_Error", $l3_error.(Read-Register $IA32_MCi_STATUS_MSR 20))
                                $IA32_MCi_STATUS.model_specific_errors.Add("Invalid_PIC_Request", $invalid_pic_request.(Read-Register $IA32_MCi_STATUS_MSR 21))

                                # Other information
                                $IA32_MCi_STATUS.reserved_error_status_other_information.Add("8-bit_Error_Count", [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 39 32), 2))
                                break
                            }
                        }

                        # Intel Xeon Processor MP 7100 Series
                        if ($ProcessorSignature -eq "0F_06H") {
                            if ($parsed_data.bank -eq "4") {
                                $incremental_decoding_information = "Yes"

                                # Reset "MCA (machine-check architecture) error code field" and "Model specific errors"
                                $IA32_MCi_STATUS.mca_error_codes.Error_Code = $null
                                $IA32_MCi_STATUS.mca_error_codes.Meaning = $null
                                $IA32_MCi_STATUS.model_specific_errors = @{}
                                $IA32_MCi_STATUS.reserved_error_status_other_information = @{}

                                # MCA Error Codes
                                Switch -Regex ($IA32_MCi_STATUS.mca_error_codes.Binary_Encoding) {
                                    # Internal Error (Cache Bus Controller Error)
                                    "0000010000000000" { 
                                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Internal Error"
                                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "Internal Error Type Code"
                                        break
                                    }
                                    # L3 Tag Error
                                    "0000000100001011" { 
                                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "L3 Tag Error"
                                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "L3 Tag Error Type Code"
                                        break
                                    }
                                    # Bus and Interconnect Error 
                                    "0000100.00001111" {
                                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Bus and Interconnect Error"
                                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "Not used but this encoding is reserved for compatibility with other MCA implementations"
                                        break
                                    }
                                    "0000101.00001111" {
                                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Bus and Interconnect Error"
                                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "Not used but this encoding is reserved for compatibility with other MCA implementations"
                                        break
                                    }
                                    "0000110.00001111" {
                                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Bus and Interconnect Error"
                                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "Not used but this encoding is reserved for compatibility with other MCA implementations"
                                        break
                                    }
                                    "0000111000001111" {
                                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Bus and Interconnect Error"
                                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "Bus and Interconnection Error Type Code"
                                        break
                                    }
                                    "0000111100001111" {
                                        $IA32_MCi_STATUS.mca_error_codes.Error_Code = "Bus and Interconnect Error"
                                        $IA32_MCi_STATUS.mca_error_codes.Meaning = "Not used but this encoding is reserved for compatibility with other MCA implementations"
                                        break
                                    }
                                    Default {
                                        Write-Warning "MCA Error Code could not be identified during incremental decoding MCA information, stop decoding."
                                        return
                                    }
                                }

                                # Model specific errors
                                $IA32_MCi_STATUS.model_specific_errors.Add("FSB_Request_Parity", (Read-Register $IA32_MCi_STATUS_MSR 16))
                                $IA32_MCi_STATUS.model_specific_errors.Add("FSB_Hard_Fail_Response", (Read-Register $IA32_MCi_STATUS_MSR 20))
                                $IA32_MCi_STATUS.model_specific_errors.Add("FSB_Response_Parity", (Read-Register $IA32_MCi_STATUS_MSR 21))
                                $IA32_MCi_STATUS.model_specific_errors.Add("FSB_Data_Parity", (Read-Register $IA32_MCi_STATUS_MSR 22))
                                Switch ($IA32_MCi_STATUS.mca_error_codes.Error_Code) {
                                    "L3 Tag Error" {
                                        $model_specific_error_codes = @{
                                            "000" = "No error"
                                            "001" = "More than one way reporting a correctable event"
                                            "010" = "More than one way reporting an uncorrectable error"
                                            "011" = "More than one way reporting a tag hit"
                                            "100" = "No error"
                                            "101" = "One way reporting a correctable event"
                                            "110" = "One way reporting an uncorrectable error"
                                            "111" = "One or more ways reporting a correctable event while one or more ways are reporting an uncorrectable error"
                                        }
                                        $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error", $model_specific_error_codes.(Read-Register $IA32_MCi_STATUS_MSR 18 16))
                                        break
                                    }

                                    "Bus and Interconnect Error" {
                                        $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error", $null)
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 16) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "FSB Request Parity" }
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 17) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "Core0 Addr Parity" }
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 18) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "Core1 Addr Parity" }
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 20) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "FSB Response Parity" }
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 21) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "FSB Data Parity" }
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 22) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "Core0 Data Parity" }
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 23) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "Core1 Data Parity" }
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 24) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "IDS Parity" }
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 25) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "FSB Inbound Data ECC" }
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 26) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "FSB Data Glitch" }
                                        if ((Read-Register $IA32_MCi_STATUS_MSR 27) -eq "1") { $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "FSB Address Glitch" }
                                        break
                                    }

                                    "Internal Error" {
                                        $model_specific_error_codes = @{
                                            "0000000000000001" = "Inclusion Error from Core 0"
                                            "0000000000000010" = "Inclusion Error from Core 1"
                                            "0000000000000011" = "Write Exclusive Error from Core 0"
                                            "0000000000000100" = "Write Exclusive Error from Core 1"
                                            "0000000000000101" = "Inclusion Error from FSB"
                                            "0000000000000110" = "SNP Stall Error from FSB"
                                            "0000000000000111" = "Write Stall Error from FSB"
                                            "0000000000001000" = "FSB Arb Timeout Error"
                                            "0000000000001001" = "CBC OOD Queue Underflow/overflow"
                                            "0000000100000000" = "Enhanced Intel SpeedStep Technology TM1-TM2 Error"
                                            "0000001000000000" = "Internal Timeout error"
                                            "0000001100000000" = "Internal Timeout Error"
                                            "0000010000000000" = "Intel® Cache Safe Technology Queue Full Error or Disabled-ways-in-a-set overflow"
                                            "1100000000000001" = "Correctable ECC event on outgoing FSB data"
                                            "1100000000000010" = "Correctable ECC event on outgoing Core 0 data"
                                            "1100000000000100" = "Correctable ECC event on outgoing Core 1 data"
                                            "1110000000000001" = "Uncorrectable ECC error on outgoing FSB data"
                                            "1110000000000010" = "Uncorrectable ECC error on outgoing Core 0 data"
                                            "1110000000000100" = "Uncorrectable ECC error on outgoing Core 1 data"
                                        }
                                        $IA32_MCi_STATUS.model_specific_errors.Add("Model_Specific_Error", $model_specific_error_codes.(Read-Register $IA32_MCi_STATUS_MSR 31 16))
                                        if (! $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error) {
                                            $IA32_MCi_STATUS.model_specific_errors.Model_Specific_Error = "Reserved"
                                        }
                                        break
                                    }
                                }

                                # Other Information 
                                $IA32_MCi_STATUS.reserved_error_status_other_information.Add("8-bit_Correctable_Event_Count", [System.Convert]::ToInt16((Read-Register $IA32_MCi_STATUS_MSR 39 32), 2))
                                if ($IA32_MCi_STATUS.reserved_error_status_other_information.MISCV -eq "1") {
                                    $IA32_MCi_STATUS.reserved_error_status_other_information.Add("MC4_MISC_format_type", (Read-Register $IA32_MCi_STATUS_MSR 41 40))
                                }
                                $IA32_MCi_STATUS.reserved_error_status_other_information.Add("Valid_ECC_syndrome", (Read-Register $IA32_MCi_STATUS_MSR 52))
                                if ($IA32_MCi_STATUS.reserved_error_status_other_information.Valid_ECC_syndrome -eq "1") {
                                    $IA32_MCi_STATUS.reserved_error_status_other_information.Add("ECC_syndrome", (Read-Register $IA32_MCi_STATUS_MSR 51 44))
                                }
                                if ($IA32_MCi_STATUS.status_register_validity_indicators.UC -eq "0") {
                                    $IA32_MCi_STATUS.reserved_error_status_other_information.Add("Threshold-Based_Error_Status", $IA32_MCi_STATUS_Sub_Fields.threshold_based_error.(Read-Register $IA32_MCi_STATUS_MSR 54 53))
                                }
                            }
                        }

                        break
                    }
                }

                # In case of Memory Controller Errors, convert IA32_MCi_ADDR.Address value to GiB to find DIMM in question (Experimental)
                if (($IA32_MCi_STATUS.mca_error_codes.Error_Code -eq "Memory Controller Errors") -and ($IA32_MCi_STATUS.status_register_validity_indicators.ADDRV -eq "1")) {
                    if ($IA32_MCi_ADDR.Address_Valid -ne $null) {
                        $IA32_MCi_ADDR.Add("Address_GiB", ("{0:n2}" -f ($IA32_MCi_ADDR.Address_Valid / 1GB)))
                    }
                    else {
                        $IA32_MCi_ADDR.Add("Address_GiB", ("{0:n2}" -f ($IA32_MCi_ADDR.Address / 1GB)))
                    }
                }

                # Prepare output
                $row = "" | Select-Object `
                    "Id", "Timestamp", "cpu", "bank", "IA32_MCi_STATUS", "IA32_MCi_MISC", "IA32_MCi_ADDR", 
                    "VAL", "OVER", "UC", "EN", "MISCV", "ADDRV", "PCC"

                $row.Id = $id++
                $row.Timestamp = $parsed_data.timestamp
                $row.cpu = $parsed_data.cpu
                $row.bank = $parsed_data.bank
                $row.IA32_MCi_STATUS = $parsed_data.status
                $row.IA32_MCi_MISC = $parsed_data.misc
                $row.IA32_MCi_ADDR = $parsed_data.addr

                # Status register validity indicators
                $row.VAL = $IA32_MCi_STATUS.status_register_validity_indicators.VAL
                $row.OVER = $IA32_MCi_STATUS.status_register_validity_indicators.OVER
                $row.UC = $IA32_MCi_STATUS.status_register_validity_indicators.UC
                $row.EN = $IA32_MCi_STATUS.status_register_validity_indicators.EN
                $row.MISCV = $IA32_MCi_STATUS.status_register_validity_indicators.MISCV
                $row.ADDRV = $IA32_MCi_STATUS.status_register_validity_indicators.ADDRV
                $row.PCC = $IA32_MCi_STATUS.status_register_validity_indicators.PCC

                # MCA (machine-check architecture) error code field
                $row | Add-Member "MCA Error Type" $IA32_MCi_STATUS.mca_error_codes.Type
                $row | Add-Member "MCA Error Code" $IA32_MCi_STATUS.mca_error_codes.Error_Code
                $row | Add-Member "MCA Error Interpretation" $IA32_MCi_STATUS.mca_error_codes.Interpretation
                $row | Add-Member "MCA Error Meaning" $IA32_MCi_STATUS.mca_error_codes.Meaning
                $row | Add-Member "Correction Report Filtering" $IA32_MCi_STATUS.mca_error_codes.Correction_Report_Filtering

                # Model-specific error code field, bits
                $row | Add-Member "Model Specific Errors" $null
                if ($IA32_MCi_STATUS.model_specific_errors.Count) {
                    $row."Model Specific Errors" = $IA32_MCi_STATUS.model_specific_errors
                }

                # Reserved, Error Status and Other Information fields
                $row | Add-Member "Reserved, Error Status and Other Information" $null
                if ($IA32_MCi_STATUS.reserved_error_status_other_information.Count) {
                    $row."Reserved, Error Status and Other Information" = $IA32_MCi_STATUS.reserved_error_status_other_information
                }
                $row | Add-Member "UCR Error Classification" $MC_Error_Type

                # IA32_MCi_MISC MSR
                $row | Add-Member "Address Mode" $IA32_MCi_MISC.Address_Mode
                $row | Add-Member "Recoverable Address LSB" $IA32_MCi_MISC.Recoverable_Address_LSB

                # IA32_MCi_ADDR MSR
                $row | Add-Member "Address Valid" $IA32_MCi_ADDR.Address_Valid
                $row | Add-Member "Address GiB" $IA32_MCi_ADDR.Address_GiB

                $row | Add-Member "Incremental Decoding Information" $incremental_decoding_information
            }
            else {
                Write-Warning "Information within the IA32_MCi_TATUS register is not valid, stop decoding."
                return
            }
            $result += $row
        }
    }

    End {
        return $result
    }
}
