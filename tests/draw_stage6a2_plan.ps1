$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$bitmap=[System.Drawing.Bitmap]::new(1500,1080)
$g=[System.Drawing.Graphics]::FromImage($bitmap)
$g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint=[System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.ColorTranslator]::FromHtml('#f1efe6'))
function Fill($x,$y,$w,$h,$color) {
    $b=[System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($color)); $g.FillRectangle($b,[single]$x,[single]$y,[single]$w,[single]$h); $b.Dispose()
}
function Line($x1,$y1,$x2,$y2,$color='#5d6760',$width=4) {
    $p=[System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml($color),[single]$width); $g.DrawLine($p,[single]$x1,[single]$y1,[single]$x2,[single]$y2); $p.Dispose()
}
function Text($s,$x,$y,$size=18,$color='#34413c') {
    $f=[System.Drawing.Font]::new('Microsoft YaHei',[single]$size,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel); $b=[System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($color)); $g.DrawString($s,$f,$b,[single]$x,[single]$y); $f.Dispose(); $b.Dispose()
}
function PX([double]$x){return 120+($x+15.55)*45}
function PZ([double]$z){return 260+($z+2.10)*45}
function Room($id,[double]$x,[double]$z,$color) {
    $px=PX $x; $pz=PZ $z
    Fill $px $pz 414 189 $color
    Line $px $pz ($px+414) $pz
    Line $px ($pz+189) ($px+414) ($pz+189)
    Line $px $pz $px ($pz+189)
    Line ($px+414) $pz ($px+414) ($pz+189)
    Text "$id $(if($id -eq '501'){'玩家公寓'}else{'封闭预留体量'})" ($px+100) ($pz+55) 25
    Text "X[$('{0:F2}' -f $x), $('{0:F2}' -f ($x+9.2))]" ($px+90) ($pz+95) 19
    Text "Z[$('{0:F2}' -f $z), $('{0:F2}' -f ($z+4.2))]" ($px+90) ($pz+124) 19
}
Text 'Stage 6-A.2｜五楼实际世界坐标布局' 40 24 31
Text 'Y 向上；图中 +X 向右、+Z 向下。五楼当前局部地面 Y=0，与已验收 501 保持同标高。' 40 77 20
Text '-Z：北侧临街方向（本轮不制作街道）' 615 188 20 '#267f8b'
Room '502' -15.55 -2.10 '#e1dfd4'
Room '501' -4.60 -2.10 '#d5e0d4'
Room '504' -15.55 2.25 '#e1dfd4'
Room '503' -4.60 2.25 '#e1dfd4'
$left=PX -6.35; $right=PX -4.6; $top=PZ -1.95; $end=PZ 8.55
Fill $left $top ($right-$left) ($end-$top) '#d4c3a1'
Line (PX -6.5) (PZ -2.1) (PX -6.5) (PZ 8.7)
Line (PX -4.45) (PZ 6.45) (PX -4.45) (PZ 8.7)
Line (PX -6.5) (PZ -2.1) (PX -4.45) (PZ -2.1)
Text "公共`n楼道`n1.75m" ($left+7) (PZ 2.75) 18
foreach($d in @(@('501',-4.525,1.11),@('502',-6.425,1.11),@('503',-4.525,5.46),@('504',-6.425,5.46))) {
    $x=PX $d[1]; $y=PZ $d[2]
    Line $x ($y-24) $x ($y+24) '#a06f35' 9
    $tx=if($d[1] -lt -5){$x-65}else{$x+14}
    Text $d[0] $tx ($y-12) 19 '#835422'
}
Line (PX -2) (PZ -2.025) (PX 0.2) (PZ -2.025) '#3e9aac' 8
Text '501 北窗保持原位' 720 226 17 '#267f8b'
Line (PX -6.5) (PZ 8.625) (PX -6.035) (PZ 8.625)
Line (PX -4.915) (PZ 8.625) (PX -4.45) (PZ 8.625)
Line (PX -6.035) (PZ 8.625) (PX -4.915) (PZ 8.625) '#a06f35' 9
Fill (PX -7.1) (PZ 8.7) (3.25*45) (4*45) '#d8dddd'
Text "楼梯间预留`n本轮封闭入口`n不制作楼梯" (PX -7.0) (PZ 9.3) 18
Text "关键连接坐标`n`n501：(-4.525, 1.11)`n502：(-6.425, 1.11)`n503：(-4.525, 5.46)`n504：(-6.425, 5.46)`n`n楼梯入口：`n(-5.475, 8.625)" 1090 280 19
Text "楼道净空：`nX[-6.35, -4.60]`nZ[-1.95, 8.55]`n`n地板与 501 门洞连续。`n邻户向各自体量内部预留，`n不占用北窗外侧。" 1090 640 19
Text '实际坐标平面示意，非运行截图。502～504 只建封闭外壳；楼梯入口不通往未完成区域。' 40 1015 21
$path=Join-Path $projectPath 'references/stage6a2_floor5_plan.png'
$bitmap.Save($path,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bitmap.Dispose(); Write-Output $path
