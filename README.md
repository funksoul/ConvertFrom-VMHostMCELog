# ConvertFrom-VMHostMCELog

A PowerShell Module for decoding MCE(Machine Check Exception) log entry of the ESXi vmkernel.log.
This module reveals three Cmdlets:
  * ConvertFrom-VMHostMCELog
  * ConvertFrom-IA32\_MCG\_CAP - Decode IA32\_MCG\_CAP MSR. (Model Specific Register)
  * ConvertFrom-VMHostCPUID - Fetch CPUID information of given ESXi Host

The machine check architecture is a mechanism within a CPU to detect and report hardware issues. When a problem is detected, a Machine Check Exception (MCE) is thrown.
MCE consists of a set of model-specific registers (MSRs) that are used to set up machine checking and additional banks of MSRs used for recording errors that are detected.
This Cmdlet reads MSRs from the vmkernel.log and decodes its contents as much as possible.

\* Parameters are ***required*** - IA32MCG_CAP, ProcessorSignature
  (Cmdlets are provided separately / ConvertFrom-IA32\_MCG\_CAP and ConvertFrom-VMHostCPUID)
\* Only Intel(R) Processors are supported.

For more information, please consult the help page of each Cmdlet.



### Installation

1. Download repo as .zip file and extract it.
2. Change location to the extracted folder and run the installer (.\Install.ps1)
3. Check if the module loaded correctly

```powershell
PS C:\> Get-Module -ListAvailable ConvertFrom-VMHostMCELog

ModuleType Version    Name                                ExportedCommands
---------- -------    ----                                ----------------
Script     0.8        ConvertFrom-VMHostMCELog            {ConvertFrom-VMHostCPUID, ConvertFrom-IA32_MCG_CAP, ConvertFrom-VMHostMCELog}
```



### Usage

- Decode all MCE log entry from the vmkernel.log. Using Cmdlets for IA32_MCG_CAP MSR and Processor Signature.

  ```powershell
  PS C:\> Get-Content vmkernel.log | ConvertFrom-VMHostMCELog -IA32_MCG_CAP (ConvertFrom-IA32_MCG_CAP 0x1c09) -ProcessorSignature (ConvertFrom-VMHostCPUID vmhost.example.com -ProcessorSignature)
  ```


- Decode all MCE log entry from the vmkernel.log. You can specify IA32_MCG_CAP MSR and Processor Signature if you know them.

  ```powershell
  PS C:\> Get-Content vmkernel.log | ConvertFrom-VMHostMCELog -IA32_MCG_CAP 0x1c09 -ProcessorSignature 06_0FH
  ```


- You can copy & paste line(s) from vmkernel.log directly.

  ```powershell
  PS C:\> "2017-07-07T18:25:27.441Z cpu2:36681)MCE: 190: cpu1: bank3: status=0x9020000f0120100e: (VAL=1, OVFLW=0, UC=1, EN=1, PCC=1, S=0, AR=0), Addr:0x0 (invalid), Misc:0x0 (invalid)" | ConvertFrom-VMHostMCELog -IA32_MCG_CAP 0x1c09 -ProcessorSignature 06_0FH -Verbose
  ```
  ```
  === Sample Output ===
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
  ```



### Etc

- You can find ESXi host's IA32_MCG_CAP MSR from the boot log (ESXi 5.x, 6.x)
  ```shell
  [root@vmhost:~] zcat /var/log/boot.gz | grep MCG_CAP
  0:00:00:07.008 cpu0:32768)MCE: 1480: Detected 9 MCE banks. MCG_CAP MSR:0x1c09
  ```
