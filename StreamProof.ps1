Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class WinAffinity {
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool GetWindowDisplayAffinity(IntPtr hWnd, out uint pdwAffinity);

    [DllImport("user32.dll")]
    public static extern int GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
}
"@

$results = @()

$callback = {
    param($hWnd, $lParam)

    if ([WinAffinity]::IsWindowVisible($hWnd)) {
        [uint32]$affinity = 0
        if ([WinAffinity]::GetWindowDisplayAffinity($hWnd, [ref]$affinity)) {
            if ($affinity -ne 0) {
                [uint32]$procId = 0
                [WinAffinity]::GetWindowThreadProcessId($hWnd, [ref]$procId) | Out-Null

                $sb = New-Object System.Text.StringBuilder 256
                [WinAffinity]::GetWindowText($hWnd, $sb, 256) | Out-Null

                try { $procName = (Get-Process -Id $procId -ErrorAction Stop).ProcessName } catch { $procName = "N/A" }

                $affinityName = switch ($affinity) {
                    1  { "WDA_MONITOR" }
                    17 { "WDA_EXCLUDEFROMCAPTURE" }
                    default { "0x{0:X}" -f $affinity }
                }

                $script:results += [PSCustomObject]@{
                    PID           = $procId
                    ProcessName   = $procName
                    WindowTitle   = $sb.ToString()
                    Affinity      = $affinityName
                    AffinityValue = $affinity
                }
            }
        }
    }
    return $true
}

[WinAffinity]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null

if ($results.Count -eq 0) {
    Write-Host "Nessuna finestra con SetWindowDisplayAffinity attivo trovata." -ForegroundColor Green
} else {
    Write-Host "Finestre con display affinity impostata (possibile hide-from-capture):" -ForegroundColor Yellow
    $results | Format-Table -AutoSize
}
