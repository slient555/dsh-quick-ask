param(
  [switch]$SelfTest,
  [switch]$UITest,
  [string]$Snapshot = '',
  [switch]$SnapshotTr,
  [switch]$CallTest,
  [string]$DemoShot = '',
  [switch]$DemoTr,
  [string]$Theme = 'flat'
)

$ErrorActionPreference = 'Stop'

# ============================================================ 依赖与原生辅助
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[System.Windows.Forms.Application]::EnableVisualStyles()

Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace QaUi
{
    public static class Native
    {
        [DllImport("user32.dll")] public static extern bool ReleaseCapture();
        [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);
        [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
        [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    }

    public static class Round
    {
        public static GraphicsPath Path(Rectangle r, int radius)
        {
            var p = new GraphicsPath();
            if (radius <= 0) { p.AddRectangle(r); return p; }
            int d = Math.Max(1, radius * 2);
            p.AddArc(r.X, r.Y, d, d, 180, 90);
            p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }
    }

    public class RoundForm : Form
    {
        public int Radius = 22;
        public Color EdgeColor = Color.FromArgb(96, 255, 255, 255);
        public bool ShowEdge = true;
        public RoundForm()
        {
            SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
        }
        protected override CreateParams CreateParams
        {
            get { var cp = base.CreateParams; cp.ClassStyle |= 0x20000; return cp; }
        }
        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);
            if (Width > 0 && Height > 0)
            {
                using (var p = Round.Path(new Rectangle(0, 0, Width, Height), Radius)) Region = new Region(p);
            }
        }
        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            if (!ShowEdge) return;
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            var rect = new Rectangle(0, 0, Width - 1, Height - 1);
            using (var path = Round.Path(rect, Radius))
            using (var pen = new Pen(EdgeColor, 1.7f)) e.Graphics.DrawPath(pen, path);
        }
        public void DragWindow()
        {
            Native.ReleaseCapture();
            Native.SendMessage(Handle, 0xA1, (IntPtr)0x2, IntPtr.Zero);
        }
    }

    public class CardPanel : Panel
    {
        public int Radius = 12;
        public Color FillColor = Color.FromArgb(240, 20, 25, 46);
        public Color BorderColor = Color.FromArgb(30, 255, 255, 255);
        public bool ShowBorder = true;
        public CardPanel()
        {
            SetStyle(ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
        }
        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            var rect = new Rectangle(0, 0, Math.Max(1, Width - 1), Math.Max(1, Height - 1));
            using (var path = Round.Path(rect, Radius))
            {
                using (var b = new SolidBrush(FillColor)) e.Graphics.FillPath(b, path);
                if (ShowBorder) using (var pen = new Pen(BorderColor)) e.Graphics.DrawPath(pen, path);
            }
        }
    }

    public class FlatButton : Button
    {
        public int Radius = 10;
        public Color Accent = Color.FromArgb(91, 124, 255);
        public Color Hover = Color.FromArgb(74, 106, 235);
        public Color GradientEnd = Color.FromArgb(138, 107, 255);
        public Color TextColor = Color.White;
        public Color GhostFill = Color.FromArgb(255, 32, 38, 62);
        public Color GhostHover = Color.FromArgb(255, 46, 54, 86);
        public Color GhostBorder = Color.FromArgb(96, 255, 255, 255);
        public Color GhostText = Color.FromArgb(228, 235, 250);
        public bool Filled = true;
        public FlatButton()
        {
            FlatStyle = FlatStyle.Flat;
            FlatAppearance.BorderSize = 0;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
            Cursor = Cursors.Hand;
        }
        private bool IsHover()
        {
            try { return ClientRectangle.Contains(PointToClient(Cursor.Position)); } catch { return false; }
        }
        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            var rect = new Rectangle(0, 0, Math.Max(1, Width - 1), Math.Max(1, Height - 1));
            bool hover = Enabled && IsHover();

            if (Filled)
            {
                using (var path = Round.Path(rect, Radius))
                using (var b = new LinearGradientBrush(new Rectangle(0, 0, Math.Max(2, Width), Math.Max(2, Height)), Accent, GradientEnd, 18f))
                    e.Graphics.FillPath(b, path);
                if (hover)
                {
                    using (var path = Round.Path(rect, Radius))
                    using (var b = new SolidBrush(Color.FromArgb(28, 255, 255, 255)))
                        e.Graphics.FillPath(b, path);
                }
            }
            else
            {
                using (var path = Round.Path(rect, Radius))
                using (var b = new SolidBrush(hover ? GhostHover : GhostFill))
                    e.Graphics.FillPath(b, path);
                using (var path = Round.Path(rect, Radius))
                using (var pen = new Pen(GhostBorder)) e.Graphics.DrawPath(pen, path);
            }

            Color fg = !Enabled ? Color.FromArgb(150, 158, 180) : (Filled ? TextColor : GhostText);
            e.Graphics.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
            using (var brush = new SolidBrush(fg))
            using (var fmt = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center, Trimming = StringTrimming.EllipsisCharacter })
            {
                e.Graphics.DrawString(Text, Font, brush, new RectangleF(0, 0, Width, Height), fmt);
            }
        }
        protected override void OnMouseEnter(EventArgs e) { base.OnMouseEnter(e); Invalidate(); }
        protected override void OnMouseLeave(EventArgs e) { base.OnMouseLeave(e); Invalidate(); }
        protected override void OnEnabledChanged(EventArgs e) { base.OnEnabledChanged(e); Invalidate(); }
    }

    public class HintTextBox : TextBox
    {
        public string Hint = "";
        public HintTextBox() { BorderStyle = BorderStyle.None; }
        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            if (!Focused && Text.Length == 0 && Hint.Length > 0)
            {
                TextRenderer.DrawText(e.Graphics, Hint, Font, ClientRectangle,
                    Color.FromArgb(118, 128, 155), TextFormatFlags.Left | TextFormatFlags.Top);
            }
        }
        protected override void OnGotFocus(EventArgs e) { base.OnGotFocus(e); Invalidate(); }
        protected override void OnLostFocus(EventArgs e) { base.OnLostFocus(e); Invalidate(); }
        protected override void OnTextChanged(EventArgs e) { base.OnTextChanged(e); Invalidate(); }
    }
}
'@ | Out-Null

try { [void][QaUi.Native]::SetProcessDPIAware() } catch { }

# ============================================================ 主题
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:HeaderPath = Join-Path $PSScriptRoot 'assets\header.png'
if ($Theme -eq 'flat') { $script:HeaderPath = Join-Path $PSScriptRoot 'assets\header-flat.png' }

$script:T = @{
  Text      = [System.Drawing.Color]::FromArgb(233, 238, 255)
  Muted     = [System.Drawing.Color]::FromArgb(152, 163, 194)
  Accent    = [System.Drawing.Color]::FromArgb(91, 124, 255)
  Accent2   = [System.Drawing.Color]::FromArgb(138, 107, 255)
  SheetFill = [System.Drawing.Color]::FromArgb(255, 12, 16, 32)
  SheetEdge = [System.Drawing.Color]::FromArgb(24, 255, 255, 255)
  CardFill  = [System.Drawing.Color]::FromArgb(236, 22, 28, 52)
  CardEdge  = [System.Drawing.Color]::FromArgb(26, 255, 255, 255)
  InputBg   = [System.Drawing.Color]::FromArgb(20, 26, 48)
  AnswerBg  = [System.Drawing.Color]::FromArgb(16, 21, 40)
}

$script:CjkFont = 'Microsoft YaHei'

$script:UiTheme = 'glass'
if ($Theme -eq 'flat') {
  $script:UiTheme = 'flat'
  $script:T.SheetFill = [System.Drawing.Color]::FromArgb(255, 16, 20, 34)
  $script:T.CardFill  = [System.Drawing.Color]::FromArgb(255, 25, 30, 48)
  $script:T.CardEdge  = [System.Drawing.Color]::FromArgb(34, 255, 255, 255)
  $script:T.InputBg   = [System.Drawing.Color]::FromArgb(25, 30, 48)
  $script:T.AnswerBg  = [System.Drawing.Color]::FromArgb(21, 26, 42)
}

$script:F = @{
  Title = New-Object System.Drawing.Font $script:CjkFont, 15.5, ([System.Drawing.FontStyle]::Bold)
  Body  = New-Object System.Drawing.Font $script:CjkFont, 10.5
  Small = New-Object System.Drawing.Font $script:CjkFont, 9
  Btn   = New-Object System.Drawing.Font $script:CjkFont, 10.5, ([System.Drawing.FontStyle]::Bold)
}

$script:Mode = 'auto'
$script:DefaultQuestion = '这道题怎么做？请给出答案和关键步骤。'
$script:QSolve = '这道题怎么做？先直接给答案，再给关键步骤，最后点出容易错的地方。'
$script:QExplain = '讲解这段内容：先给结论，再拆解原理和关键步骤，指出容易出错的地方，必要时举一个例子。'
$script:QTranslate = '把这段内容翻译成中文；如果原文本身是中文，就翻译成英文。术语要准确，只给译文，必要时在最后加一行简短译注。'
$script:KnowledgeQuestion = '请解释这段内容涉及的知识点：给出定义、关键要点，并举一个例子。'
$script:SummaryQuestion = '请总结这段内容，指出关键结论。'
$script:autoQuestion = ''
$script:DemoTexts = $null

# 去掉模型爱带的 Markdown 标记，纯文本展示更适合小窗
function Format-Answer([string]$Text) {
  if ([string]::IsNullOrEmpty($Text)) { return $Text }
  $t = $Text -replace '\*\*', '' -replace '`', ''
  $t = $t -replace '(?m)^#{1,6}\s*', ''
  return $t.Trim()
}

# 把常见的纯文本公式写法换成更像公式的字符
function Format-Math([string]$Text) {
  if ([string]::IsNullOrEmpty($Text)) { return $Text }
  $sup = @{ '0' = '⁰'; '1' = '¹'; '2' = '²'; '3' = '³'; '4' = '⁴'; '5' = '⁵'; '6' = '⁶'; '7' = '⁷'; '8' = '⁸'; '9' = '⁹'; 'n' = 'ⁿ' }
  $t = [regex]::Replace($Text, '\^([0-9n]+)', { param($m) $v = $m.Groups[1].Value; $o = ''; foreach ($c in $v.ToCharArray()) { if ($sup.ContainsKey([string]$c)) { $o += $sup[[string]$c] } else { $o += '^' + $c } }; $o })
  $t = $t -replace 'sqrt\s*\(', '√('
  $t = $t -replace '<=', '≤' -replace '>=', '≥' -replace '!=', '≠'
  $t = $t -replace '->', '→' -replace '=>', '⇒'
  $t = $t -replace '(?<=\d)\s*\*\s*(?=[\dA-Za-z(])', ' × '
  return $t
}

# 判断识别出来的内容该怎么自动问：
# 疑问句/题目 → 直接解；短知识条目 → 解释知识点；长段落 → 总结。
function Get-AutoQuestion([string]$Text) {
  $t = $Text.Trim()
  if ($t.Length -lt 4) { return '' }

  # 只有"几乎没有汉字、且拉丁字母够多"才当成外语去翻译；
  # 数学题里汉字少但符号多，不能误判成外语。
  $cjk = ([regex]::Matches($t, '[\u4e00-\u9fff]')).Count
  $latin = ([regex]::Matches($t, '[A-Za-z]')).Count
  if ($cjk -le 1 -and $latin -ge 8 -and $latin / [Math]::Max(1, $t.Length) -gt 0.3) { return $script:QTranslate }

  $isQuestion = $t -match '[？?]' -or
    $t -match '(什么|为什么|怎么|如何|是否|多少|哪个|哪些|吗|呢|求|计算|证明|化简|解方程|下列|已知|判断|选择)'

  if ($isQuestion) { return $script:QSolve }
  if ($t.Length -lt 80) { return $script:QExplain }
  return $script:QExplain
}

# 按当前模式（自动/翻译/解题/讲解）决定要发出去的问题
function Get-QuestionForMode([string]$Mode, [string]$Text) {
  switch ($Mode) {
    'translate' { return $script:QTranslate }
    'solve' { return $script:QSolve }
    'explain' { return $script:QExplain }
    default {
      $auto = Get-AutoQuestion $Text
      if ($auto -ne '') { return $auto }
      return $script:QExplain
    }
  }
}
$script:DshPortFile = Join-Path $env:LOCALAPPDATA 'dsh-quick-ask\port.txt'

# ============================================================ DSH 连接

function Test-DshPort([int]$Port) {
  try {
    $req = [System.Net.WebRequest]::Create("http://127.0.0.1:$Port/dsh-quick-ask/state")
    $req.Timeout = 700
    $req.Proxy = $null
    $resp = $req.GetResponse()
    $reader = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
    $text = $reader.ReadToEnd()
    $reader.Close(); $resp.Close()
    return ($text -match '"ok"\s*:\s*true') -and ($text -match 'dsh-quick-ask')
  } catch { return $false }
}

function Save-DshPort([int]$Port) {
  try {
    $dir = Split-Path $script:DshPortFile -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $script:DshPortFile -Value $Port -Encoding ASCII
  } catch { }
}

function Get-DshPort {
  try {
    if (Test-Path $script:DshPortFile) {
      $cached = [int](Get-Content $script:DshPortFile -ErrorAction Stop | Select-Object -First 1)
      if ($cached -gt 0 -and (Test-DshPort $cached)) { return $cached }
    }
  } catch { }

  $candidates = New-Object System.Collections.Generic.List[int]
  try {
    $pids = @()
    foreach ($name in @('DeepSeek Harness', 'node', 'dsh')) {
      $p = Get-Process -Name $name -ErrorAction SilentlyContinue
      if ($p) { $pids += $p.Id }
    }
    $pids = $pids | Select-Object -Unique
    if ($pids.Count -gt 0) {
      $conns = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Where-Object { $pids -contains $_.OwningProcess -and $_.LocalAddress -in @('127.0.0.1', '0.0.0.0', '::1', '::') }
      foreach ($c in $conns) { if ($c.LocalPort -gt 1024) { $candidates.Add([int]$c.LocalPort) } }
    }
  } catch { }

  foreach ($port in ($candidates | Select-Object -Unique)) {
    if (Test-DshPort $port) { Save-DshPort $port; return $port }
  }
  return 0
}

function Invoke-DshAsk {
  param([int]$Port, [string]$Question, [string]$Quote, [int]$TimeoutMs = 90000)
  $payload = @{ question = $Question; quote = $Quote; stream = $false } | ConvertTo-Json -Compress -Depth 4
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)

  $req = [System.Net.WebRequest]::Create("http://127.0.0.1:$Port/dsh-quick-ask/ask")
  $req.Method = 'POST'
  $req.ContentType = 'application/json; charset=utf-8'
  $req.Accept = 'application/json'
  $req.Timeout = $TimeoutMs
  $req.ReadWriteTimeout = $TimeoutMs
  $req.Proxy = $null
  $req.ContentLength = $bytes.Length

  $stream = $req.GetRequestStream()
  $stream.Write($bytes, 0, $bytes.Length)
  $stream.Close()

  $async = $req.BeginGetResponse($null, $null)
  $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMs)
  while (-not $async.IsCompleted) {
    if ([DateTime]::UtcNow -gt $deadline) { try { $req.Abort() } catch { }; throw '请求超时（DSH 没响应）' }
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 40
  }

  $resp = $req.EndGetResponse($async)
  $reader = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
  $text = $reader.ReadToEnd()
  $reader.Close(); $resp.Close()

  $data = $text | ConvertFrom-Json
  if ($data.error) {
    if ($data.message) { throw [string]$data.message }
    throw [string]$data.error
  }
  return [string]$data.answer
}

# ============================================================ OCR

$script:AsTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
  })[0]

function Await-WinRt($Operation, [Type]$ResultType) {
  $task = $script:AsTask.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
  $task.Wait(-1) | Out-Null
  return $task.Result
}

[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null

$script:OcrEngine = $null
try { $script:OcrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages() } catch { }
if ($null -eq $script:OcrEngine) {
  try {
    $lang = New-Object Windows.Globalization.Language 'zh-Hans-CN'
    $script:OcrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($lang)
  } catch { }
}

function Invoke-Ocr([System.Drawing.Bitmap]$Bitmap) {
  if ($null -eq $script:OcrEngine) { throw '这台机器没有可用的 Windows OCR 语言包' }
  if ($null -eq $Bitmap) { throw '图像为空' }

  $scale = 2
  $big = New-Object System.Drawing.Bitmap ([int]($Bitmap.Width * $scale)), ([int]($Bitmap.Height * $scale))
  $g = [System.Drawing.Graphics]::FromImage($big)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.DrawImage($Bitmap, 0, 0, $big.Width, $big.Height)
  $g.Dispose()

  $tmp = Join-Path $env:TEMP ('dsh-quick-ask-' + [Guid]::NewGuid().ToString('N') + '.png')
  $big.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
  $big.Dispose()

  try {
    $file = Await-WinRt ([Windows.Storage.StorageFile]::GetFileFromPathAsync($tmp)) ([Windows.Storage.StorageFile])
    $stream = Await-WinRt ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
    $decoder = Await-WinRt ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $software = Await-WinRt ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $result = Await-WinRt ($script:OcrEngine.RecognizeAsync($software)) ([Windows.Media.Ocr.OcrResult])

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($line in $result.Lines) { $lines.Add($line.Text) }
    $stream.Dispose()
    return ($lines -join "`r`n")
  } finally {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  }
}

# ============================================================ 选区遮罩

function Select-ScreenRegion {
  $vs = [System.Windows.Forms.SystemInformation]::VirtualScreen

  $overlay = New-Object System.Windows.Forms.Form
  $overlay.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
  $overlay.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
  $overlay.Bounds = $vs
  $overlay.TopMost = $true
  $overlay.BackColor = $T.SheetFill
  $overlay.Opacity = 0.42
  $overlay.Cursor = [System.Windows.Forms.Cursors]::Cross
  $overlay.ShowInTaskbar = $false
  $overlay.KeyPreview = $true

  $script:dragging = $false
  $script:startPt = $null
  $script:endPt = $null
  $script:rect = $null
  $script:result = $null

  $script:scanPhase = 0
  $scanTimer = New-Object System.Windows.Forms.Timer
  $scanTimer.Interval = 18
  $scanTimer.Add_Tick({
    if ($script:dragging -and $null -ne $script:rect -and $script:rect.Height -gt 10) {
      $script:scanPhase = ($script:scanPhase + 7) % [Math]::Max(1, $script:rect.Height)
      $overlay.Invalidate()
    }
  })
  $scanTimer.Start()
  $overlay.Add_FormClosed({ $scanTimer.Stop(); $scanTimer.Dispose() })

  $overlay.Add_Paint({
    param($sender, $e)
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias

    $w = $overlay.ClientSize.Width
    $hint = '拖动框选题目  ·  点一下抓全屏  ·  Esc 取消'
    $hintFont = New-Object System.Drawing.Font 'Microsoft YaHei UI', 12
    $size = $g.MeasureString($hint, $hintFont)
    $hx = [int](($w - $size.Width) / 2)
    $box = New-Object System.Drawing.RectangleF ($hx - 20), 28, ($size.Width + 40), ($size.Height + 16)
    $bgBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(205, 18, 23, 42))
    $g.FillRectangle($bgBrush, $box)
    $bgBrush.Dispose()
    $hintBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(230, 235, 250))
    $g.DrawString($hint, $hintFont, $hintBrush, $hx, 36)
    $hintBrush.Dispose()
    $hintFont.Dispose()

    if ($null -ne $script:rect -and $script:rect.Width -gt 0) {
      $r = $script:rect
      $accent = [System.Drawing.Color]::FromArgb(255, 0, 229, 255)
      $fill = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(48, 0, 200, 255))
      $g.FillRectangle($fill, $r)
      $fill.Dispose()
      $pen = New-Object System.Drawing.Pen $accent, 3
      $g.DrawRectangle($pen, $r)
      $pen.Dispose()

      # 四角加粗标记，边界一眼能看出来
      $corner = [Math]::Max(10, [Math]::Min(26, [int]($r.Width / 6)))
      $pen2 = New-Object System.Drawing.Pen $accent, 6
      $pen2.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
      $pen2.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
      $g.DrawLine($pen2, $r.Left, $r.Top, $r.Left + $corner, $r.Top)
      $g.DrawLine($pen2, $r.Left, $r.Top, $r.Left, $r.Top + $corner)
      $g.DrawLine($pen2, $r.Right, $r.Top, $r.Right - $corner, $r.Top)
      $g.DrawLine($pen2, $r.Right, $r.Top, $r.Right, $r.Top + $corner)
      $g.DrawLine($pen2, $r.Left, $r.Bottom, $r.Left + $corner, $r.Bottom)
      $g.DrawLine($pen2, $r.Left, $r.Bottom, $r.Left, $r.Bottom - $corner)
      $g.DrawLine($pen2, $r.Right, $r.Bottom, $r.Right - $corner, $r.Bottom)
      $g.DrawLine($pen2, $r.Right, $r.Bottom, $r.Right, $r.Bottom - $corner)
      $pen2.Dispose()

      # 扫描线：框选时一条青色光带自上而下扫过
      if ($script:dragging -and $r.Height -gt 12) {
        $sy = $r.Y + ($script:scanPhase % [Math]::Max(1, $r.Height))
        $band = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(90, 0, 229, 255))
        $g.FillRectangle($band, $r.X + 2, $sy, [Math]::Max(1, $r.Width - 4), 2)
        $band.Dispose()
        $band2 = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(32, 0, 229, 255))
        $g.FillRectangle($band2, $r.X + 2, [Math]::Max($r.Y + 1, $sy - 14), [Math]::Max(1, $r.Width - 4), 16)
        $band2.Dispose()
      }

      $label = "$($r.Width) × $($r.Height)"
      $lf = New-Object System.Drawing.Font 'Consolas', 10
      $ls = $g.MeasureString($label, $lf)
      $lx = [int]($r.X + 6)
      $ly = [int]($r.Y + $r.Height + 6)
      if ($ly + $ls.Height -gt $overlay.ClientSize.Height - 4) { $ly = [int]($r.Y - $ls.Height - 8) }
      $tagBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(200, 12, 16, 30))
      $g.FillRectangle($tagBrush, $lx, $ly, ($ls.Width + 12), ($ls.Height + 4))
      $tagBrush.Dispose()
      $g.DrawString($label, $lf, [System.Drawing.Brushes]::White, $lx + 6, $ly + 1)
      $lf.Dispose()
    }
  })

  $overlay.Add_MouseDown({
    param($sender, $e)
    if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
    $script:dragging = $true
    $script:startPt = $e.Location
    $script:endPt = $e.Location
    $script:rect = New-Object System.Drawing.Rectangle $script:startPt.X, $script:startPt.Y, 0, 0
  })

  $overlay.Add_MouseMove({
    param($sender, $e)
    if (-not $script:dragging) { return }
    $script:endPt = $e.Location
    $x = [Math]::Min($script:startPt.X, $script:endPt.X)
    $y = [Math]::Min($script:startPt.Y, $script:endPt.Y)
    $w = [Math]::Abs($script:endPt.X - $script:startPt.X)
    $h = [Math]::Abs($script:endPt.Y - $script:startPt.Y)
    $script:rect = New-Object System.Drawing.Rectangle $x, $y, $w, $h
    $overlay.Invalidate()
  })

  $overlay.Add_MouseUp({
    param($sender, $e)
    if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
    $script:dragging = $false
    if ($null -eq $script:rect) { return }
    $r = $script:rect
    if ($r.Width -lt 30 -or $r.Height -lt 30) {
      $script:result = New-Object System.Drawing.Rectangle $vs.X, $vs.Y, $vs.Width, $vs.Height
    } else {
      $script:result = New-Object System.Drawing.Rectangle ($vs.X + $r.X), ($vs.Y + $r.Y), $r.Width, $r.Height
    }
    $overlay.Close()
  })

  $overlay.Add_KeyDown({
    param($sender, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $overlay.Close() }
  })

  [void]$overlay.ShowDialog()

  if ($null -eq $script:result) { return $null }
  $rect = $script:result

  Start-Sleep -Milliseconds 160
  [System.Windows.Forms.Application]::DoEvents()

  $bmp = New-Object System.Drawing.Bitmap $rect.Width, $rect.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($rect.X, $rect.Y, 0, 0, $bmp.Size)
  $g.Dispose()
  return $bmp
}

# ============================================================ 结果窗口

function New-Card([int]$x, [int]$y, [int]$w, [int]$h, [int]$radius = 12) {
  $card = New-Object QaUi.CardPanel
  $card.SetBounds($x, $y, $w, $h)
  $card.Radius = $radius
  $card.FillColor = $script:T.CardFill
  $card.BorderColor = $script:T.CardEdge
  return $card
}

function Show-QuickAskWindow([System.Drawing.Bitmap]$Bitmap, [switch]$NoShow, [string]$SnapshotPath = '') {
  $T = $script:T
  $F = $script:F

  $form = New-Object QaUi.RoundForm
  $form.Text = '快速问答'
  $form.ClientSize = New-Object System.Drawing.Size 640, 740
  $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
  $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
  $form.TopMost = $true
  $form.KeyPreview = $true
  $form.Font = $F.Body
  $form.BackColor = [System.Drawing.Color]::FromArgb(10, 13, 26)
  $form.ShowInTaskbar = $true
  $form.Radius = 20
  $uiCfg = Get-UiConfig
  try { ("cfg=" + $uiCfg.opacity + " wall=" + $uiCfg.wallpaper + " exists=" + (Test-Path $uiCfg.wallpaper)) | Out-File "$env:TEMP\qa-cfg.txt" -Encoding UTF8 } catch { }
  $form.Opacity = $uiCfg.opacity

  # ---- 顶部条（头像 + 标题已画进图里）
  $head = New-Object System.Windows.Forms.PictureBox
  $head.SetBounds(0, 0, 640, 84)
  $head.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage
  $head.BackColor = [System.Drawing.Color]::FromArgb(10, 13, 26)
  if (Test-Path $script:HeaderPath) {
    $head.Image = [System.Drawing.Image]::FromFile($script:HeaderPath)
  }
  $form.Controls.Add($head)

  $btnClose = New-Object QaUi.FlatButton
  $btnClose.Text = '✕'
  $btnClose.Font = New-Object System.Drawing.Font 'Microsoft YaHei UI', 10
  $btnClose.SetBounds(580, 22, 36, 36)
  $btnClose.Radius = 18
  $btnClose.Filled = $false
  $btnClose.GhostFill = [System.Drawing.Color]::FromArgb(235, 18, 23, 42)
  $btnClose.GhostHover = [System.Drawing.Color]::FromArgb(245, 34, 42, 72)
  $form.Controls.Add($btnClose)

  $btnGear = New-Object QaUi.FlatButton
  $btnGear.Text = '⚙'
  $btnGear.Font = New-Object System.Drawing.Font 'Microsoft YaHei UI', 11
  $btnGear.SetBounds(524, 22, 36, 36)
  $btnGear.Radius = 18
  $btnGear.Filled = $false
  $btnGear.GhostFill = [System.Drawing.Color]::FromArgb(235, 18, 23, 42)
  $btnGear.GhostHover = [System.Drawing.Color]::FromArgb(245, 34, 42, 72)
  $btnGear.Add_Click({ Show-SettingsWindow })
  $form.Controls.Add($btnGear)
  $head.SendToBack()

  $form.Add_MouseDown({ param($sender, $e) if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left -and $e.Y -lt 84) { $form.DragWindow() } })

  # ---- 主体面板
  $sheet = New-Object QaUi.CardPanel
  $sheet.SetBounds(0, 84, 640, 656)
  $sheet.Radius = 22
  $sheet.FillColor = $T.SheetFill
  $sheet.BorderColor = $T.SheetEdge
  $form.Controls.Add($sheet)

  # ---- 识别区
  $lblOcr = New-Object System.Windows.Forms.Label
  $lblOcr.Text = '识别到的内容'
  $lblOcr.Font = $F.Small
  $lblOcr.ForeColor = $T.Muted
  $lblOcr.BackColor = $T.SheetFill
  $lblOcr.SetBounds(32, 104, 220, 18)
  $form.Controls.Add($lblOcr)

  $btnSaveShot = New-Object QaUi.FlatButton
  $btnSaveShot.Text = '存图'
  $btnSaveShot.Font = $F.Small
  $btnSaveShot.SetBounds(340, 99, 64, 28)
  $btnSaveShot.Radius = 14
  $btnSaveShot.Filled = $false
  $form.Controls.Add($btnSaveShot)

  $btnPasteShot = New-Object QaUi.FlatButton
  $btnPasteShot.Text = '贴图'
  $btnPasteShot.Font = $F.Small
  $btnPasteShot.SetBounds(412, 99, 64, 28)
  $btnPasteShot.Radius = 14
  $btnPasteShot.Filled = $false
  $form.Controls.Add($btnPasteShot)

  $btnRecap = New-Object QaUi.FlatButton
  $btnRecap.Text = '重新框选'
  $btnRecap.Font = $F.Small
  $btnRecap.SetBounds(484, 99, 132, 28)
  $btnRecap.Radius = 14
  $btnRecap.Filled = $false
  $form.Controls.Add($btnRecap)

  $ocrCard = New-Card 24 128 592 116 14
  $form.Controls.Add($ocrCard)

  $txtOcr = New-Object System.Windows.Forms.TextBox
  $txtOcr.Multiline = $true
  $txtOcr.BorderStyle = [System.Windows.Forms.BorderStyle]::None
  $txtOcr.ScrollBars = 'None'
  $txtOcr.BackColor = $T.InputBg
  $txtOcr.ForeColor = $T.Text
  $txtOcr.Font = New-Object System.Drawing.Font $script:CjkFont, 9.5
  $txtOcr.SetBounds(16, 12, 560, 96)
  $ocrCard.Controls.Add($txtOcr)

  # ---- 问题区
  $lblQ = New-Object System.Windows.Forms.Label
  $lblQ.Text = '你的问题'
  $lblQ.Font = $F.Small
  $lblQ.ForeColor = $T.Muted
  $lblQ.BackColor = $T.SheetFill
  $lblQ.SetBounds(32, 262, 220, 18)
  $form.Controls.Add($lblQ)

  $qCard = New-Card 24 282 460 44 14
  $form.Controls.Add($qCard)

  $txtQ = New-Object QaUi.HintTextBox
  $txtQ.Hint = '留空就按解题来答；也可以自己写问题'
  $txtQ.Font = $F.Body
  $txtQ.BackColor = $T.InputBg
  $txtQ.ForeColor = $T.Text
  $txtQ.SetBounds(16, 13, 428, 20)
  $qCard.Controls.Add($txtQ)

  $btnTrans = New-Object QaUi.FlatButton
  $btnTrans.Text = '翻译'
  $btnTrans.Font = $F.Small
  $btnTrans.SetBounds(492, 282, 124, 44)
  $btnTrans.Radius = 12
  $btnTrans.Filled = $false
  $form.Controls.Add($btnTrans)

  $btnAsk = New-Object QaUi.FlatButton
  $btnAsk.Text = '问 DSH'
  $btnAsk.Font = $F.Btn
  $btnAsk.SetBounds(24, 338, 460, 44)
  $btnAsk.Radius = 14
  $btnAsk.Accent = $T.Accent
  $btnAsk.GradientEnd = $T.Accent2
  $form.Controls.Add($btnAsk)

  $btnExplain = New-Object QaUi.FlatButton
  $btnExplain.Text = '讲解'
  $btnExplain.Font = $F.Small
  $btnExplain.SetBounds(492, 338, 124, 44)
  $btnExplain.Radius = 12
  $btnExplain.Filled = $false
  $form.Controls.Add($btnExplain)

  $lblStatus = New-Object System.Windows.Forms.Label
  $lblStatus.Text = ''
  $lblStatus.Font = $F.Small
  $lblStatus.ForeColor = $T.Muted
  $lblStatus.BackColor = $T.SheetFill
  $lblStatus.SetBounds(32, 392, 580, 18)
  $form.Controls.Add($lblStatus)

  # ---- 答案区（横向长条）
  $lblA = New-Object System.Windows.Forms.Label
  $lblA.Text = '答案'
  $lblA.Font = $F.Small
  $lblA.ForeColor = $T.Muted
  $lblA.BackColor = $T.SheetFill
  $lblA.SetBounds(28, 420, 220, 18)
  $form.Controls.Add($lblA)

  $btnCopy = New-Object QaUi.FlatButton
  $btnCopy.Text = '复制'
  $btnCopy.Font = $F.Small
  $btnCopy.SetBounds(540, 415, 76, 28)
  $btnCopy.Radius = 14
  $btnCopy.Filled = $false
  $form.Controls.Add($btnCopy)

  $aCard = New-Card 24 442 592 244 14
  $aCard.FillColor = $T.AnswerBg
  $form.Controls.Add($aCard)

  $txtAnswer = New-Object QaUi.HintTextBox
  $txtAnswer.Hint = '答案会出现在这里…'
  $txtAnswer.Multiline = $true
  $txtAnswer.ReadOnly = $true
  $txtAnswer.BorderStyle = [System.Windows.Forms.BorderStyle]::None
  $txtAnswer.ScrollBars = 'None'
  $txtAnswer.BackColor = $T.AnswerBg
  $txtAnswer.ForeColor = $T.Text
  $txtAnswer.Font = $F.Body
  $txtAnswer.SetBounds(16, 12, 560, 220)
  $aCard.Controls.Add($txtAnswer)

  $foot = New-Object System.Windows.Forms.Label
  $foot.Text = 'Ctrl+Enter 提问   ·   Esc 关闭   ·   Ctrl+Alt+A 随时唤出'
  $foot.Font = $F.Small
  $foot.ForeColor = [System.Drawing.Color]::FromArgb(120, 132, 162)
  $foot.BackColor = $T.SheetFill
  $foot.SetBounds(32, 700, 580, 18)
  $form.Controls.Add($foot)

  $sheet.SendToBack()

  # 壁纸：不是"跟随桌面/内置"时，把选中的壁纸铺满整窗，面板相应变透
  if ($uiCfg.wallpaper -ne 'desktop' -and $uiCfg.wallpaper -ne 'builtin' -and (Test-Path $uiCfg.wallpaper)) {
    try {
      $wallPath = $uiCfg.wallpaper
      # GIF 预览图直接当背景画不出来，先转成 PNG 再用
      if ([IO.Path]::GetExtension($wallPath).ToLower() -eq '.gif') {
        $src = [System.Drawing.Image]::FromFile($wallPath)
        $bmpWall = New-Object System.Drawing.Bitmap $src.Width, $src.Height
        $gWall = [System.Drawing.Graphics]::FromImage($bmpWall)
        $gWall.DrawImage($src, 0, 0, $src.Width, $src.Height)
        $gWall.Dispose()
        $src.Dispose()
        $wallPath = Join-Path $env:TEMP ('qa-wall-' + [Guid]::NewGuid().ToString('N') + '.png')
        $bmpWall.Save($wallPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmpWall.Dispose()
      }
      $form.BackgroundImage = [System.Drawing.Image]::FromFile($wallPath)
      $form.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Stretch
      $sheet.FillColor = [System.Drawing.Color]::FromArgb(206, 10, 14, 29)
      $ocrCard.FillColor = [System.Drawing.Color]::FromArgb(232, 22, 28, 52)
      $qCard.FillColor = [System.Drawing.Color]::FromArgb(232, 22, 28, 52)
      $aCard.FillColor = [System.Drawing.Color]::FromArgb(228, 16, 21, 40)
    } catch { }
  }


  # ---- 交互
  $btnClose.Add_Click({ $form.Close() })

  $btnSaveShot.Add_Click({
    try {
      $dir = Join-Path ([Environment]::GetFolderPath('MyPictures')) 'DSH快速问答'
      if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
      $file = Join-Path $dir ((Get-Date -Format 'yyyyMMdd-HHmmss') + '.png')
      $Bitmap.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
      $lblStatus.Text = '截图已保存：' + $file
    } catch {
      $lblStatus.Text = '保存失败：' + $_.Exception.Message
    }
  })

  $btnPasteShot.Add_Click({
    try {
      [System.Windows.Forms.Clipboard]::SetImage($Bitmap)
      $lblStatus.Text = '截图已复制，可以直接粘到对话里'
    } catch {
      $lblStatus.Text = '复制失败：' + $_.Exception.Message
    }
  })

  $lblStatus.Text = '正在识别…'
  $form.Refresh()
  try {
    $ocrText = Invoke-Ocr $Bitmap
    $txtOcr.Text = Format-Math $ocrText
    if ([string]::IsNullOrWhiteSpace($ocrText)) {
      $script:autoQuestion = ''
      $lblStatus.Text = '没识别到文字，框大一点或换个区域再试'
    } else {
      if ($ocrText.Length -lt 12 -and $Bitmap.Width * $Bitmap.Height -gt 120000) {
        $lblStatus.Text = '文字很少，可能是图形题 · 可点「贴图」发原图'
      } else {
        $lblStatus.Text = '识别完成 · ' + $ocrText.Length + ' 字 · 选「翻译 / 讲解 / 问 DSH」'
      }
    }
  } catch {
    $lblStatus.Text = '识别失败：' + $_.Exception.Message
  }

  $ask = {
    $question = $txtQ.Text.Trim()
    $quote = $txtOcr.Text.Trim()
    if ($question -eq '') { $question = $script:QSolve }
    if ($quote -eq '') { $lblStatus.Text = '先框选一段有文字的内容'; return }

    $btnAsk.Enabled = $false
    $btnRecap.Enabled = $false
    $btnAsk.Text = '思考中…'
    $txtAnswer.Text = ''
    $started = [DateTime]::Now
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 400
    $timer.Add_Tick({ $lblStatus.Text = ('思考中… ' + [int]([DateTime]::Now - $started).TotalSeconds + 's') })
    $timer.Start()
    try {
      $port = Get-DshPort
      if ($port -eq 0) { $lblStatus.Text = '没找到 DSH：先把 DeepSeek Harness 打开再试'; return }
      $answer = Invoke-DshAsk -Port $port -Question $question -Quote $quote
      $txtAnswer.Text = Format-Math (Format-Answer $answer)
      $lblStatus.Text = ('完成 · 用时 ' + [int]([DateTime]::Now - $started).TotalSeconds + 's')
    } catch {
      $txtAnswer.Text = '出错了：' + $_.Exception.Message
      $lblStatus.Text = '调用失败'
    } finally {
      $timer.Stop(); $timer.Dispose()
      $btnAsk.Text = '问 DSH'
      $btnAsk.Enabled = $true
      $btnRecap.Enabled = $true
    }
  }

  $runWith = {
    param($prompt)
    $txtQ.Text = $prompt
    & $ask
  }
  $btnTrans.Add_Click({ & $runWith $script:QTranslate })
  $btnExplain.Add_Click({ & $runWith $script:QExplain })

  $btnAsk.Add_Click({ & $ask })
  $form.Add_KeyDown({
    param($sender, $e)
    if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) { & $ask }
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $form.Close() }
  })

  $btnCopy.Add_Click({
    if ($txtAnswer.Text.Length -gt 0) { [System.Windows.Forms.Clipboard]::SetText($txtAnswer.Text) }
  })

  $btnRecap.Add_Click({
    $form.Hide()
    $bmp = Select-ScreenRegion
    if ($null -ne $bmp) {
      try {
        $txtOcr.Text = Format-Math (Invoke-Ocr $bmp)
        $script:autoQuestion = ''
        $lblStatus.Text = '重新识别完成'
      } catch {
        $lblStatus.Text = '识别失败：' + $_.Exception.Message
      } finally { $bmp.Dispose() }
    }
    $form.Show(); $form.Activate()
  })

  $form.Add_Shown({
    $form.Activate()
    $txtQ.Focus()
  })

  if ($null -ne $script:DemoTexts) {
    $txtOcr.Text = $script:DemoTexts.ocr
    $txtAnswer.Text = $script:DemoTexts.answer
    $lblStatus.Text = $script:DemoTexts.status
  }

  if (-not $NoShow) { [void]$form.ShowDialog() }
  else {
    $form.CreateControl()
    $null = $form.Handle
    $form.PerformLayout()
    if ($SnapshotPath -ne '') {
      $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
      $form.Location = New-Object System.Drawing.Point 120, 60
      $form.ShowInTaskbar = $false
      $form.Show()
      [System.Windows.Forms.Application]::DoEvents()
      Start-Sleep -Milliseconds 520
      [System.Windows.Forms.Application]::DoEvents()
      $form.Refresh()
      [System.Windows.Forms.Application]::DoEvents()
      Start-Sleep -Milliseconds 120
      $origin = $form.PointToScreen([System.Drawing.Point]::Empty)
      $bmp = New-Object System.Drawing.Bitmap $form.ClientSize.Width, $form.ClientSize.Height
      $g = [System.Drawing.Graphics]::FromImage($bmp)
      $g.CopyFromScreen($origin.X, $origin.Y, 0, 0, $bmp.Size)
      $g.Dispose()
      $bmp.Save($SnapshotPath, [System.Drawing.Imaging.ImageFormat]::Png)
      $bmp.Dispose()
      $form.Hide()
      Write-Output ('snapshot: ' + $SnapshotPath)
    }
  }
  $form.Dispose()
}

function Show-TranslateWindow([System.Drawing.Bitmap]$Bitmap, [switch]$NoShow, [string]$SnapshotPath = '') {
  $T = $script:T
  $F = $script:F
  if ([string]::IsNullOrEmpty($script:TrDirection)) { $script:TrDirection = 'auto' }

  $form = New-Object QaUi.RoundForm
  $form.Text = '快速翻译'
  $form.ClientSize = New-Object System.Drawing.Size 760, 560
  $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
  $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
  $form.TopMost = $true
  $form.KeyPreview = $true
  $form.Font = $F.Body
  $form.BackColor = [System.Drawing.Color]::FromArgb(10, 13, 26)
  $form.ShowInTaskbar = $true
  $form.Radius = 20
  $form.Opacity = 0.93

  $head = New-Object System.Windows.Forms.PictureBox
  $head.SetBounds(0, 0, 760, 84)
  $head.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage
  $head.BackColor = [System.Drawing.Color]::FromArgb(10, 13, 26)
  $trHeader = Join-Path $PSScriptRoot 'assets\header-tr.png'
  if (Test-Path $trHeader) { $head.Image = [System.Drawing.Image]::FromFile($trHeader) }
  $form.Controls.Add($head)

  $btnClose = New-Object QaUi.FlatButton
  $btnClose.Text = '✕'
  $btnClose.Font = New-Object System.Drawing.Font 'Microsoft YaHei UI', 10
  $btnClose.SetBounds(708, 22, 36, 36)
  $btnClose.Radius = 18
  $btnClose.Filled = $false
  $btnClose.GhostFill = [System.Drawing.Color]::FromArgb(235, 18, 23, 42)
  $btnClose.GhostHover = [System.Drawing.Color]::FromArgb(245, 34, 42, 72)
  $form.Controls.Add($btnClose)
  $head.SendToBack()

  $form.Add_MouseDown({ param($sender, $e) if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left -and $e.Y -lt 84) { $form.DragWindow() } })

  $sheet = New-Object QaUi.CardPanel
  $sheet.SetBounds(0, 84, 760, 476)
  $sheet.Radius = 22
  $sheet.FillColor = $T.SheetFill
  $sheet.BorderColor = $T.SheetEdge
  $form.Controls.Add($sheet)

  $lblSrc = New-Object System.Windows.Forms.Label
  $lblSrc.Text = '原文（可改）'
  $lblSrc.Font = $F.Small
  $lblSrc.ForeColor = $T.Muted
  $lblSrc.BackColor = $T.SheetFill
  $lblSrc.SetBounds(28, 100, 220, 18)
  $form.Controls.Add($lblSrc)

  $lblDst = New-Object System.Windows.Forms.Label
  $lblDst.Text = '译文'
  $lblDst.Font = $F.Small
  $lblDst.ForeColor = $T.Muted
  $lblDst.BackColor = $T.SheetFill
  $lblDst.SetBounds(396, 100, 220, 18)
  $form.Controls.Add($lblDst)

  $srcCard = New-Card 24 122 344 336 14
  $form.Controls.Add($srcCard)

  $txtSrc = New-Object System.Windows.Forms.TextBox
  $txtSrc.Multiline = $true
  $txtSrc.BorderStyle = [System.Windows.Forms.BorderStyle]::None
  $txtSrc.ScrollBars = 'Vertical'
  $txtSrc.BackColor = $T.InputBg
  $txtSrc.ForeColor = $T.Text
  $txtSrc.Font = $F.Body
  $txtSrc.SetBounds(14, 12, 316, 312)
  $srcCard.Controls.Add($txtSrc)

  $dstCard = New-Card 392 122 344 336 14
  $dstCard.FillColor = $T.AnswerBg
  $form.Controls.Add($dstCard)

  $txtDst = New-Object System.Windows.Forms.TextBox
  $txtDst.Multiline = $true
  $txtDst.ReadOnly = $true
  $txtDst.BorderStyle = [System.Windows.Forms.BorderStyle]::None
  $txtDst.ScrollBars = 'Vertical'
  $txtDst.BackColor = $T.AnswerBg
  $txtDst.ForeColor = $T.Text
  $txtDst.Font = $F.Body
  $txtDst.SetBounds(14, 12, 316, 312)
  $dstCard.Controls.Add($txtDst)

  $btnDir = New-Object QaUi.FlatButton
  $btnDir.Text = '方向：自动'
  $btnDir.Font = $F.Small
  $btnDir.SetBounds(24, 472, 150, 42)
  $btnDir.Radius = 12
  $btnDir.Filled = $false
  $form.Controls.Add($btnDir)

  $btnRecap = New-Object QaUi.FlatButton
  $btnRecap.Text = '重新框选'
  $btnRecap.Font = $F.Small
  $btnRecap.SetBounds(186, 472, 150, 42)
  $btnRecap.Radius = 12
  $btnRecap.Filled = $false
  $form.Controls.Add($btnRecap)

  $btnCopy = New-Object QaUi.FlatButton
  $btnCopy.Text = '复制译文'
  $btnCopy.Font = $F.Small
  $btnCopy.SetBounds(392, 472, 160, 42)
  $btnCopy.Radius = 12
  $btnCopy.Filled = $false
  $form.Controls.Add($btnCopy)

  $btnGo = New-Object QaUi.FlatButton
  $btnGo.Text = '翻译'
  $btnGo.Font = $F.Btn
  $btnGo.SetBounds(564, 472, 172, 42)
  $btnGo.Radius = 12
  $btnGo.Accent = $T.Accent
  $btnGo.GradientEnd = $T.Accent2
  $form.Controls.Add($btnGo)

  $lblStatus = New-Object System.Windows.Forms.Label
  $lblStatus.Text = ''
  $lblStatus.Font = $F.Small
  $lblStatus.ForeColor = $T.Muted
  $lblStatus.BackColor = $T.SheetFill
  $lblStatus.SetBounds(28, 524, 700, 18)
  $form.Controls.Add($lblStatus)

  $foot = New-Object System.Windows.Forms.Label
  $foot.Text = 'Ctrl+Enter 翻译   ·   Esc 关闭   ·   Ctrl+Alt+T 重新调用'
  $foot.Font = $F.Small
  $foot.ForeColor = [System.Drawing.Color]::FromArgb(120, 132, 162)
  $foot.BackColor = $T.SheetFill
  $foot.SetBounds(28, 540, 700, 16)
  $form.Controls.Add($foot)

  $sheet.SendToBack()
  $btnClose.Add_Click({ $form.Close() })

  $dirMap = @{ 'auto' = '方向：自动'; 'zh2en' = '方向：中 → 英'; 'en2zh' = '方向：英 → 中' }
  $btnDir.Text = $dirMap[$script:TrDirection]

  $translate = {
    $text = $txtSrc.Text.Trim()
    if ($text -eq '') { $lblStatus.Text = '先框选一段要翻译的文字'; return }
    $question = switch ($script:TrDirection) {
      'zh2en' { '把这段内容翻译成英文，术语准确、语句自然，只给译文。' }
      'en2zh' { '把这段内容翻译成中文，术语准确、语句通顺，只给译文。' }
      default { '把这段内容翻译成中文；如果原文本身是中文，就翻译成英文。只给译文，必要时在最后加一行简短译注。' }
    }
    $btnGo.Enabled = $false
    $btnRecap.Enabled = $false
    $btnGo.Text = '翻译中…'
    $txtDst.Text = ''
    $started = [DateTime]::Now
    try {
      $port = Get-DshPort
      if ($port -eq 0) { $lblStatus.Text = '没找到 DSH：先把 DeepSeek Harness 打开再试'; return }
      $answer = Invoke-DshAsk -Port $port -Question $question -Quote $text
      $txtDst.Text = Format-Math (Format-Answer $answer)
      $lblStatus.Text = ('完成 · 用时 ' + [int]([DateTime]::Now - $started).TotalSeconds + 's')
    } catch {
      $txtDst.Text = '出错了：' + $_.Exception.Message
      $lblStatus.Text = '翻译失败'
    } finally {
      $btnGo.Text = '翻译'
      $btnGo.Enabled = $true
      $btnRecap.Enabled = $true
    }
  }

  $btnGo.Add_Click({ & $translate })
  $form.Add_KeyDown({
    param($sender, $e)
    if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) { & $translate }
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $form.Close() }
  })

  $btnDir.Add_Click({
    $script:TrDirection = switch ($script:TrDirection) {
      'auto' { 'zh2en' }
      'zh2en' { 'en2zh' }
      default { 'auto' }
    }
    $btnDir.Text = $dirMap[$script:TrDirection]
  })

  $btnCopy.Add_Click({
    if ($txtDst.Text.Length -gt 0) { [System.Windows.Forms.Clipboard]::SetText($txtDst.Text) }
  })

  $btnRecap.Add_Click({
    $form.Hide()
    $bmp = Select-ScreenRegion
    if ($null -ne $bmp) {
      try { $txtSrc.Text = Invoke-Ocr $bmp; & $translate }
      catch { $lblStatus.Text = '识别失败：' + $_.Exception.Message }
      finally { $bmp.Dispose() }
    }
    $form.Show(); $form.Activate()
  })

  $lblStatus.Text = '正在识别…'
  $form.Refresh()
  try {
    $txtSrc.Text = Invoke-Ocr $Bitmap
    if ([string]::IsNullOrWhiteSpace($txtSrc.Text)) {
      $lblStatus.Text = '没识别到文字，框大一点或换个区域'
    } else {
      $lblStatus.Text = '识别完成，正在翻译…'
    }
  } catch {
    $lblStatus.Text = '识别失败：' + $_.Exception.Message
  }

  $autoTimer = New-Object System.Windows.Forms.Timer
  $autoTimer.Interval = 380
  $autoTimer.Add_Tick({
    $autoTimer.Stop()
    $autoTimer.Dispose()
    if ($txtSrc.Text.Trim() -ne '' -and $txtDst.Text -eq '') { & $translate }
  })

  $form.Add_Shown({
    $form.Activate()
    if ($txtSrc.Text.Trim() -ne '') { $autoTimer.Start() }
  })

  if (-not $NoShow) { [void]$form.ShowDialog() }
  else {
    $form.CreateControl()
    $null = $form.Handle
    $form.PerformLayout()
    if ($SnapshotPath -ne '') {
      $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
      $form.Location = New-Object System.Drawing.Point 120, 60
      $form.ShowInTaskbar = $false
      $form.Show()
      [System.Windows.Forms.Application]::DoEvents()
      Start-Sleep -Milliseconds 1400
      [System.Windows.Forms.Application]::DoEvents()
      $form.Refresh()
      [System.Windows.Forms.Application]::DoEvents()
      Start-Sleep -Milliseconds 150
      $origin = $form.PointToScreen([System.Drawing.Point]::Empty)
      $bmp = New-Object System.Drawing.Bitmap $form.ClientSize.Width, $form.ClientSize.Height
      $g = [System.Drawing.Graphics]::FromImage($bmp)
      $g.CopyFromScreen($origin.X, $origin.Y, 0, 0, $bmp.Size)
      $g.Dispose()
      $bmp.Save($SnapshotPath, [System.Drawing.Imaging.ImageFormat]::Png)
      $bmp.Dispose()
      $form.Hide()
      Write-Output ('snapshot: ' + $SnapshotPath)
    }
  }
  $form.Dispose()
}

# ---------------------------------------------------------------- 外观设置

$script:ConfigPath = Join-Path $env:LOCALAPPDATA 'dsh-quick-ask\config.json'

function Get-UiConfig {
  $cfg = @{ opacity = 0.91; wallpaper = 'desktop' }
  try {
    if (Test-Path $script:ConfigPath) {
      $raw = Get-Content $script:ConfigPath -Raw -Encoding UTF8
      $data = $raw | ConvertFrom-Json
      if ($null -ne $data.opacity) { $cfg.opacity = [double]$data.opacity }
      if ($null -ne $data.wallpaper) { $cfg.wallpaper = [string]$data.wallpaper }
    }
  } catch { }
  if ($cfg.opacity -lt 0.5) { $cfg.opacity = 0.5 }
  if ($cfg.opacity -gt 1) { $cfg.opacity = 1 }
  return $cfg
}

function Save-UiConfig($cfg) {
  try {
    $dir = Split-Path $script:ConfigPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $cfg | ConvertTo-Json | Set-Content -Path $script:ConfigPath -Encoding UTF8
  } catch { }
}

function Get-WallpaperChoices {
  $list = New-Object System.Collections.Generic.List[object]
  $idx = Join-Path $env:USERPROFILE '.dsh-wallpaper-engine\cache\inventory-index.json'
  if (Test-Path $idx) {
    try {
      $data = Get-Content $idx -Raw -Encoding UTF8 | ConvertFrom-Json
      foreach ($w in $data.we) {
        if ($w.title -eq $null) { continue }
        $preview = [string]$w.previewAbs
        if ($preview -eq '' -or -not (Test-Path $preview)) { continue }
        $list.Add([pscustomobject]@{ title = [string]$w.title; path = $preview })
      }
    } catch { }
  }
  return $list
}

function Show-SettingsWindow {
  $T = $script:T
  $F = $script:F
  $cfg = Get-UiConfig
  $wallpapers = Get-WallpaperChoices

  $dlg = New-Object QaUi.RoundForm
  $dlg.Text = '外观设置'
  $dlg.ClientSize = New-Object System.Drawing.Size 520, 470
  $dlg.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
  $dlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
  $dlg.TopMost = $true
  $dlg.BackColor = $T.SheetFill
  $dlg.Radius = 18

  $title = New-Object System.Windows.Forms.Label
  $title.Text = '外观设置'
  $title.Font = $F.Title
  $title.ForeColor = $T.Text
  $title.BackColor = $T.SheetFill
  $title.SetBounds(26, 20, 300, 32)
  $dlg.Controls.Add($title)

  $btnX = New-Object QaUi.FlatButton
  $btnX.Text = '✕'
  $btnX.Font = $F.Small
  $btnX.SetBounds(464, 20, 32, 32)
  $btnX.Radius = 16
  $btnX.Filled = $false
  $dlg.Controls.Add($btnX)
  $btnX.Add_Click({ $dlg.Close() })
  $dlg.Add_MouseDown({ param($s, $e) if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { $dlg.DragWindow() } })

  $lblOpacity = New-Object System.Windows.Forms.Label
  $lblOpacity.Text = '虚幻程度（越低越透，能看到后面的桌面）'
  $lblOpacity.Font = $F.Small
  $lblOpacity.ForeColor = $T.Muted
  $lblOpacity.BackColor = $T.SheetFill
  $lblOpacity.SetBounds(28, 68, 400, 18)
  $dlg.Controls.Add($lblOpacity)

  $slider = New-Object System.Windows.Forms.TrackBar
  $slider.Minimum = 50
  $slider.Maximum = 100
  $slider.TickFrequency = 5
  $slider.Value = [int]($cfg.opacity * 100)
  $slider.SetBounds(24, 90, 380, 45)
  $slider.BackColor = $T.SheetFill
  $dlg.Controls.Add($slider)

  $lblValue = New-Object System.Windows.Forms.Label
  $lblValue.Text = $slider.Value.ToString() + '%'
  $lblValue.Font = $F.Small
  $lblValue.ForeColor = $T.Text
  $lblValue.BackColor = $T.SheetFill
  $lblValue.SetBounds(414, 96, 80, 20)
  $dlg.Controls.Add($lblValue)
  $slider.Add_Scroll({ $lblValue.Text = $slider.Value.ToString() + '%' })

  $lblWall = New-Object System.Windows.Forms.Label
  $lblWall.Text = '壁纸（选一条就用作小窗背景，配合上面的透明度）'
  $lblWall.Font = $F.Small
  $lblWall.ForeColor = $T.Muted
  $lblWall.BackColor = $T.SheetFill
  $lblWall.SetBounds(28, 142, 460, 18)
  $dlg.Controls.Add($lblWall)

  $list = New-Object System.Windows.Forms.ListBox
  $list.Font = $F.Small
  $list.SetBounds(24, 164, 472, 210)
  $list.BackColor = [System.Drawing.Color]::FromArgb(18, 23, 42)
  $list.ForeColor = $T.Text
  $list.BorderStyle = [System.Windows.Forms.BorderStyle]::None
  $list.IntegralHeight = $false
  $dlg.Controls.Add($list)

  $items = New-Object System.Collections.Generic.List[object]
  $items.Add([pscustomobject]@{ label = '① 跟随桌面（完全透明，壁纸引擎的画面直接透出来）'; path = 'desktop' })
  $items.Add([pscustomobject]@{ label = '② 内置鲸鱼娘立绘'; path = 'builtin' })
  foreach ($w in $wallpapers) { $items.Add([pscustomobject]@{ label = '· ' + $w.title; path = $w.path }) }
  foreach ($it in $items) { [void]$list.Items.Add($it.label) }

  $selectedIndex = 0
  for ($i = 0; $i -lt $items.Count; $i++) { if ($items[$i].path -eq $cfg.wallpaper) { $selectedIndex = $i } }
  $list.SelectedIndex = $selectedIndex

  $btnSave = New-Object QaUi.FlatButton
  $btnSave.Text = '保存'
  $btnSave.Font = $F.Btn
  $btnSave.SetBounds(300, 396, 190, 44)
  $btnSave.Radius = 12
  $btnSave.Accent = $T.Accent
  $btnSave.GradientEnd = $T.Accent2
  $dlg.Controls.Add($btnSave)

  $btnCancel = New-Object QaUi.FlatButton
  $btnCancel.Text = '取消'
  $btnCancel.Font = $F.Small
  $btnCancel.SetBounds(180, 396, 110, 44)
  $btnCancel.Radius = 12
  $btnCancel.Filled = $false
  $dlg.Controls.Add($btnCancel)
  $btnCancel.Add_Click({ $dlg.Close() })

  $btnSave.Add_Click({
    $cfg.opacity = $slider.Value / 100.0
    if ($list.SelectedIndex -ge 0) { $cfg.wallpaper = $items[$list.SelectedIndex].path }
    Save-UiConfig $cfg
    $dlg.Close()
  })

  $dlg.Add_KeyDown({
    param($s, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $dlg.Close() }
  })

  [void]$dlg.ShowDialog()
  $dlg.Dispose()
}

function Show-CallWindow([switch]$NoShow) {
  $T = $script:T
  $F = $script:F

  $form = New-Object QaUi.RoundForm
  $form.Text = '通话记录'
  $form.ClientSize = New-Object System.Drawing.Size 760, 560
  $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
  $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
  $form.TopMost = $true
  $form.Font = $F.Body
  $form.BackColor = [System.Drawing.Color]::FromArgb(10, 13, 26)
  $form.ShowInTaskbar = $true
  $form.Radius = 20
  $form.Opacity = 0.95

  $head = New-Object System.Windows.Forms.PictureBox
  $head.SetBounds(0, 0, 760, 84)
  $head.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage
  $callHeader = Join-Path $PSScriptRoot 'assets\header-call.png'
  if (Test-Path $callHeader) { $head.Image = [System.Drawing.Image]::FromFile($callHeader) }
  $form.Controls.Add($head)

  $btnClose = New-Object QaUi.FlatButton
  $btnClose.Text = '✕'
  $btnClose.Font = $F.Small
  $btnClose.SetBounds(708, 22, 36, 36)
  $btnClose.Radius = 18
  $btnClose.Filled = $false
  $btnClose.GhostFill = [System.Drawing.Color]::FromArgb(235, 18, 23, 42)
  $btnClose.GhostHover = [System.Drawing.Color]::FromArgb(245, 34, 42, 72)
  $form.Controls.Add($btnClose)
  $btnClose.Add_Click({ $form.Close() })

  $form.Add_MouseDown({ param($s, $e) if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left -and $e.Y -lt 84) { $form.DragWindow() } })
  $head.SendToBack()

  $sheet = New-Object QaUi.CardPanel
  $sheet.SetBounds(0, 84, 760, 476)
  $sheet.Radius = 22
  $sheet.FillColor = $T.SheetFill
  $sheet.BorderColor = $T.SheetEdge
  $form.Controls.Add($sheet)

  $lblA = New-Object System.Windows.Forms.Label
  $lblA.Text = '实时听写'
  $lblA.Font = $F.Small
  $lblA.ForeColor = $T.Muted
  $lblA.BackColor = $T.SheetFill
  $lblA.SetBounds(28, 100, 200, 18)
  $form.Controls.Add($lblA)

  $lblB = New-Object System.Windows.Forms.Label
  $lblB.Text = '答案'
  $lblB.Font = $F.Small
  $lblB.ForeColor = $T.Muted
  $lblB.BackColor = $T.SheetFill
  $lblB.SetBounds(396, 100, 200, 18)
  $form.Controls.Add($lblB)

  $cardA = New-Card 24 122 344 336 14
  $form.Controls.Add($cardA)

  $txtLog = New-Object System.Windows.Forms.TextBox
  $txtLog.Multiline = $true
  $txtLog.ReadOnly = $true
  $txtLog.BorderStyle = [System.Windows.Forms.BorderStyle]::None
  $txtLog.ScrollBars = 'Vertical'
  $txtLog.BackColor = $T.InputBg
  $txtLog.ForeColor = $T.Text
  $txtLog.Font = $F.Body
  $txtLog.SetBounds(14, 12, 316, 312)
  $cardA.Controls.Add($txtLog)

  $cardB = New-Card 392 122 344 336 14
  $cardB.FillColor = $T.AnswerBg
  $form.Controls.Add($cardB)

  $txtAns = New-Object System.Windows.Forms.TextBox
  $txtAns.Multiline = $true
  $txtAns.ReadOnly = $true
  $txtAns.BorderStyle = [System.Windows.Forms.BorderStyle]::None
  $txtAns.ScrollBars = 'Vertical'
  $txtAns.BackColor = $T.AnswerBg
  $txtAns.ForeColor = $T.Text
  $txtAns.Font = $F.Body
  $txtAns.SetBounds(14, 12, 316, 312)
  $cardB.Controls.Add($txtAns)

  $btnToggle = New-Object QaUi.FlatButton
  $btnToggle.Text = '开始听写'
  $btnToggle.Font = $F.Btn
  $btnToggle.SetBounds(24, 472, 200, 44)
  $btnToggle.Radius = 12
  $btnToggle.Accent = $T.Accent
  $btnToggle.GradientEnd = $T.Accent2
  $form.Controls.Add($btnToggle)

  $btnSave = New-Object QaUi.FlatButton
  $btnSave.Text = '保存记录'
  $btnSave.Font = $F.Small
  $btnSave.SetBounds(236, 472, 130, 44)
  $btnSave.Radius = 12
  $btnSave.Filled = $false
  $form.Controls.Add($btnSave)

  $btnClear = New-Object QaUi.FlatButton
  $btnClear.Text = '清空'
  $btnClear.Font = $F.Small
  $btnClear.SetBounds(378, 472, 90, 44)
  $btnClear.Radius = 12
  $btnClear.Filled = $false
  $form.Controls.Add($btnClear)

  $lblStatus = New-Object System.Windows.Forms.Label
  $lblStatus.Text = '准备就绪 · Ctrl+Alt+R 开关'
  $lblStatus.Font = $F.Small
  $lblStatus.ForeColor = $T.Muted
  $lblStatus.BackColor = $T.SheetFill
  $lblStatus.SetBounds(28, 526, 700, 18)
  $form.Controls.Add($lblStatus)

  $sheet.SendToBack()

  # ---- 听写引擎
  $script:callRec = $null
  $script:callLines = New-Object System.Collections.Generic.List[string]
  $script:callRecording = $false
  $lastAnswerAt = [DateTime]::MinValue

  $appendLog = {
    param($text)
    $txtLog.AppendText($text + "`r`n")
    $txtLog.SelectionStart = $txtLog.TextLength
    $txtLog.ScrollToCaret()
  }

  $askAsync = {
    param($question)
    if ((([DateTime]::Now) - $lastAnswerAt).TotalSeconds -lt 8) { return }
    $lastAnswerAt = [DateTime]::Now
    try {
      $port = Get-DshPort
      if ($port -eq 0) { return }
      $payload = @{ question = '这句话是在问我什么？直接回答：' + $question; quote = $question; stream = $false } | ConvertTo-Json -Compress
      $body = [System.Text.Encoding]::UTF8.GetBytes($payload)
      $req = [System.Net.WebRequest]::Create("http://127.0.0.1:$port/dsh-quick-ask/ask")
      $req.Method = 'POST'
      $req.ContentType = 'application/json; charset=utf-8'
      $req.Accept = 'application/json'
      $req.Timeout = 60000
      $req.Proxy = $null
      $req.ContentLength = $body.Length
      $s = $req.GetRequestStream(); $s.Write($body, 0, $body.Length); $s.Close()
      $async = $req.BeginGetResponse($null, $null)
      while (-not $async.IsCompleted) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 40 }
      $resp = $req.EndGetResponse($async)
      $rd = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
      $json = $rd.ReadToEnd(); $rd.Close(); $resp.Close()
      $data = $json | ConvertFrom-Json
      if ($data.answer) {
        $txtAns.AppendText(('[' + (Get-Date -Format 'HH:mm:ss') + '] ' + $question + "`r`n" + [string]$data.answer + "`r`n`r`n"))
        $txtAns.SelectionStart = $txtAns.TextLength
        $txtAns.ScrollToCaret()
        $lblStatus.Text = '已自动作答'
      }
    } catch { }
  }

  $startEngine = {
    try {
      Add-Type -AssemblyName System.Speech
      $rec = New-Object System.Speech.Recognition.SpeechRecognitionEngine([System.Globalization.CultureInfo]'zh-CN')
      $rec.LoadGrammar((New-Object System.Speech.Recognition.DictationGrammar))
      $rec.SetInputToDefaultAudioDevice()
      $rec.Add_SpeechRecognized({
        param($sender, $e)
        $text = $e.Result.Text
        if ([string]::IsNullOrWhiteSpace($text)) { return }
        $stamp = '[' + (Get-Date -Format 'HH:mm:ss') + '] '
        $form.BeginInvoke([Action]{
          & $appendLog ($stamp + $text)
        }) | Out-Null
        if ($text -match '[？?]' -or $text -match '(什么|怎么|为什么|是不是|能不能|多少|哪)') {
          $form.BeginInvoke([Action]{
            & $askAsync $text
          }) | Out-Null
        }
      })
      $rec.RecognizeAsync([System.Speech.Recognition.RecognizeMode]::Multiple)
      $script:callRec = $rec
      $script:callRecording = $true
      $lblStatus.Text = '正在听写（默认麦克风）… 再按 Ctrl+Alt+R 或点按钮停止'
      $btnToggle.Text = '停止听写'
    } catch {
      $lblStatus.Text = '听写启动失败：' + $_.Exception.Message
      $script:callRecording = $false
    }
  }

  $stopEngine = {
    try {
      if ($null -ne $script:callRec) {
        $script:callRec.RecognizeAsyncStop()
        $script:callRec.Dispose()
      }
    } catch { }
    $script:callRec = $null
    $script:callRecording = $false
    $lblStatus.Text = '已停止'
    $btnToggle.Text = '开始听写'
  }

  $btnToggle.Add_Click({
    if ($script:callRecording) { & $stopEngine } else { & $startEngine }
  })

  $btnClear.Add_Click({
    $txtLog.Text = ''
    $txtAns.Text = ''
  })

  $btnSave.Add_Click({
    try {
      $dir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'DSH通话记录'
      if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
      $file = Join-Path $dir ((Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt')
      $txtLog.Text | Set-Content -Path $file -Encoding UTF8
      $lblStatus.Text = '已保存：' + $file
    } catch { $lblStatus.Text = '保存失败：' + $_.Exception.Message }
  })

  $form.Add_KeyDown({
    param($s, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $form.Close() }
  })

  $form.Add_FormClosed({ & $stopEngine })
  $form.Add_Shown({ $form.Activate() })

  if (-not $NoShow) { [void]$form.ShowDialog() }
  else { $form.CreateControl(); $null = $form.Handle; $form.PerformLayout() }
  $form.Dispose()
}


# ============================================================ 主循环

function Start-OverlayApp {
  $script:pressed = $false
  $script:pressedT = $false
  $script:pressedR = $false
  $timer = New-Object System.Windows.Forms.Timer
  $timer.Interval = 80
  $timer.Add_Tick({
    $ctrl = ([QaUi.Native]::GetAsyncKeyState(0x11) -band 0x8000) -ne 0
    $alt = ([QaUi.Native]::GetAsyncKeyState(0x12) -band 0x8000) -ne 0
    $a = ([QaUi.Native]::GetAsyncKeyState(0x41) -band 0x8000) -ne 0
    $down = $ctrl -and $alt -and $a
    if ($down -and -not $script:pressed) {
      $script:pressed = $true
      $timer.Stop()
      try {
        $bmp = Select-ScreenRegion
        if ($null -ne $bmp) {
          try { Show-QuickAskWindow $bmp } finally { $bmp.Dispose() }
        }
      } finally {
        $timer.Start()
        $script:pressed = $false
      }
    } elseif (-not $down) {
      $script:pressed = $false
    }

    $t = ([QaUi.Native]::GetAsyncKeyState(0x54) -band 0x8000) -ne 0
    $downT = $ctrl -and $alt -and $t
    if ($downT -and -not $script:pressedT) {
      $script:pressedT = $true
      $timer.Stop()
      try {
        $bmp = Select-ScreenRegion
        if ($null -ne $bmp) {
          try { Show-TranslateWindow $bmp } finally { $bmp.Dispose() }
        }
      } finally {
        $timer.Start()
        $script:pressedT = $false
      }
    } elseif (-not $downT) {
      $script:pressedT = $false
    }

    $r = ([QaUi.Native]::GetAsyncKeyState(0x52) -band 0x8000) -ne 0
    $downR = $ctrl -and $alt -and $r
    if ($downR -and -not $script:pressedR) {
      $script:pressedR = $true
      $timer.Stop()
      try {
        if ($null -eq $script:callForm -or $script:callForm.IsDisposed) {
          $script:callForm = New-Object System.Windows.Forms.Form
        }
        Show-CallWindow
      } finally {
        $timer.Start()
        $script:pressedR = $false
      }
    } elseif (-not $downR) {
      $script:pressedR = $false
    }
  })
  $timer.Start()

  $ctx = New-Object System.Windows.Forms.ApplicationContext
  try { [System.Windows.Forms.Application]::Run($ctx) } finally { $timer.Dispose() }
}

# ============================================================ 自检

if ($DemoShot -ne '') {
  $script:DemoTexts = @{
    ocr = "已知函数 f(x)=x²-4x+3，求它在区间 [0,3] 上的最小值。`r`nA. -1    B. 0    C. 3    D. 4"
    answer = "答案：A（-1）`r`n`r`n关键步骤：`r`n1. f(x)=x²-4x+3=(x-2)²-1，顶点在 x=2。`r`n2. 区间 [0,3] 包含顶点，所以最小值取 f(2)=-1。`r`n3. 端点值 f(0)=3、f(3)=0，都大于 -1，区间最小值确认是 -1。"
    status = "识别完成 · 38 字 · 选「翻译 / 讲解 / 问 DSH」"
  }
  $bmp = New-Object System.Drawing.Bitmap 640, 120
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear([System.Drawing.Color]::White)
  $g.Dispose()
  if ($DemoTr) {
    Show-TranslateWindow -Bitmap $bmp -NoShow -SnapshotPath $DemoShot
  } else {
    Show-QuickAskWindow -Bitmap $bmp -NoShow -SnapshotPath $DemoShot
  }
  $bmp.Dispose()
  exit 0
}

if ($CallTest) {
  Show-CallWindow -NoShow
  Write-Output 'call ui: ok'
  exit 0
}

if ($Snapshot -ne '') {
  $bmp = New-Object System.Drawing.Bitmap 300, 120
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear([System.Drawing.Color]::White)
  $font = New-Object System.Drawing.Font 'Microsoft YaHei', 16
  $g.DrawString('已知函数 f(x)=x^2-4x+3，求区间 [0,3] 上的最小值。', $font, [System.Drawing.Brushes]::Black, 10, 30)
  $g.DrawString('A. -1    B. 0    C. 3', $font, [System.Drawing.Brushes]::Black, 10, 70)
  $g.Dispose()
  try {
    if ($SnapshotTr) {
      Show-TranslateWindow -Bitmap $bmp -NoShow -SnapshotPath $Snapshot
    } else {
      Show-QuickAskWindow -Bitmap $bmp -NoShow -SnapshotPath $Snapshot
    }
  } finally { $bmp.Dispose() }
  exit 0
}

if ($UITest) {
  $bmp = New-Object System.Drawing.Bitmap 300, 120
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear([System.Drawing.Color]::White)
  $font = New-Object System.Drawing.Font 'Microsoft YaHei', 16
  $g.DrawString('测试 1+1=2', $font, [System.Drawing.Brushes]::Black, 10, 40)
  $g.Dispose()
  try {
    Show-QuickAskWindow -Bitmap $bmp -NoShow
    Write-Output 'UI 构建: ok'
  } catch {
    Write-Output ('UI 构建失败: ' + $_.Exception.Message)
    Write-Output $_.ScriptStackTrace
    exit 1
  } finally { $bmp.Dispose() }
  exit 0
}

if ($SelfTest) {
  Write-Output ('OCR 引擎: ' + $(if ($null -ne $script:OcrEngine) { $script:OcrEngine.RecognizerLanguage.LanguageTag } else { '不可用' }))
  $port = Get-DshPort
  Write-Output ('DSH 端口: ' + $port)
  if ($port -gt 0) {
    try {
      $answer = Invoke-DshAsk -Port $port -Question '用一句话说明什么是勾股定理' -Quote ''
      Write-Output '--- 答案 ---'
      Write-Output $answer
    } catch { Write-Output ('调用失败: ' + $_.Exception.Message) }
  }
  exit 0
}

Start-OverlayApp
