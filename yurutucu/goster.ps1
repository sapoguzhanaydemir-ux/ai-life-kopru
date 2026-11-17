<#
  Yürütücünün gizlediği VS Code penceresini tekrar gösterir (örn. SAP'a yeniden giriş gerekirse).
  Kullanım: powershell -ExecutionPolicy Bypass -File .\yurutucu\goster.ps1 [-Baslik S4H_100_XOAYDEMIR_TR]
#>
param([string]$Baslik = 'Visual Studio Code')
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices;
public static class AiLifeGoster {
  delegate bool EnumProc(IntPtr h, IntPtr p);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr p);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int c);
  public static int Show(string titlePart) {
    int n = 0;
    EnumWindows((h, p) => {
      if (IsWindowVisible(h)) return true;
      var sb = new StringBuilder(512); GetWindowText(h, sb, 512);
      var t = sb.ToString();
      if (t.Contains(titlePart) && t.Contains("Visual Studio Code")) { ShowWindow(h, 9); n++; }
      return true;
    }, IntPtr.Zero);
    return n;
  }
}
"@
$n = [AiLifeGoster]::Show($Baslik)
Write-Host "$n pencere gösterildi."
