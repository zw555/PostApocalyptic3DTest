# Native schematic, not a Godot screenshot. No external drawing dependency.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$bitmap=[System.Drawing.Bitmap]::new(1600,690)
$g=[System.Drawing.Graphics]::FromImage($bitmap)
$g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint=[System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.ColorTranslator]::FromHtml('#f3f1e8'))
function Fill($x,$y,$w,$h,$color) {
    $b=[System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($color))
    $g.FillRectangle($b,[single]$x,[single]$y,[single]$w,[single]$h)
    $b.Dispose()
}
function Line($x1,$y1,$x2,$y2,$color='#565e59',$width=5) {
    $p=[System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml($color),[single]$width)
    $g.DrawLine($p,[single]$x1,[single]$y1,[single]$x2,[single]$y2)
    $p.Dispose()
}
function Text($s,$x,$y,$size=17,$color='#34413c') {
    $f=[System.Drawing.Font]::new('Microsoft YaHei',[single]$size,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
    $b=[System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($color))
    $g.DrawString($s,$f,$b,[single]$x,[single]$y)
    $f.Dispose(); $b.Dispose()
}
function Plan([single]$x,[bool]$after) {
    $y=210
    Text $(if($after){'C：西侧接楼道，北侧窗面向室外'}else{'B：门窗同在西墙，未来楼道位置尚未约定'}) $x 125 22
    Fill ($x-88) $y 70 252 '#ded5bb'
    Text "公共`n楼道`n预留" ($x-78) ($y+60) 19
    Fill $x ($y-53) 552 33 '#d6e3e0'
    Text '-Z：预定街道侧（本轮仅方向参照）' ($x+75) ($y-49) 18
    Text '9.20m' ($x+240) ($y-23) 16
    Fill $x $y 552 252 '#e6dfcc'
    Fill ($x+369) ($y+132) 174 111 '#c5d6d1'
    Fill ($x+68.4) ($y+103.2) 97.2 129.6 '#99aaa0'
    Text '床' ($x+101) ($y+151)
    Fill ($x+211.5) ($y+198.6) 129 40.8 '#8d9c8f'
    Text '沙发' ($x+250) ($y+207)
    Fill ($x+22.5) ($y+11.7) 129 39 '#b7b9ab'
    Text '工作台' ($x+55) ($y+20) 16
    Fill ($x+189) ($y+11.7) 66 39 '#b7b9ab'
    Text '低柜' ($x+202) ($y+22) 15
    Fill ($x+316.5) ($y+12) 39 39 '#d5d6ca'
    Text '冰箱' ($x+318) ($y+25) 13
    Fill ($x+372) ($y+11.7) 162 39 '#b7b9ab'
    Text '厨房台面' ($x+409) ($y+21) 16
    foreach($edge in @(@(4.5,4.5,547.5,4.5),@(547.5,4.5,547.5,247.5),@(4.5,247.5,547.5,247.5),@(4.5,4.5,4.5,159),@(4.5,226,4.5,247.5),@(369,132,369,247.5),@(369,132,423,132),@(477,132,547.5,132))) {
        Line ($x+$edge[0]) ($y+$edge[1]) ($x+$edge[2]) ($y+$edge[3])
    }
    Line ($x+4.5) ($y+226) ($x+63) ($y+220) '#aa793e' 6
    Line ($x-16) ($y+185) ($x+25) ($y+185) '#aa793e' 3
    Text '入户门' ($x+14) ($y+170) 16 '#875b28'
    Text '卫生间' ($x+420) ($y+173) 19
    Text '卫浴门' ($x+426) ($y+109) 14
    Text '+X →' ($x+565) ($y+50) 16
    Text '4.20m' ($x+560) ($y+132) 16
    Text '+Z ↓' ($x+240) ($y+269) 17
    if($after) {
        Line ($x+156) ($y+4.5) ($x+288) ($y+4.5) '#3c9caf' 8
        Text '新主窗 2.20m' ($x+160) ($y+58) 17 '#167488'
        Text '原窗洞已用实墙补齐' $x ($y+317) 18
        Text '窗边可站点：X=-0.02，Z=-1.40' $x ($y+346) 18
    } else {
        Line ($x+4.5) ($y+12) ($x+4.5) ($y+147) '#3c9caf' 8
        Text '原窗' ($x+14) ($y+72) 17 '#167488'
        Text '原窗：X=-4.525，朝 -X' $x ($y+317) 18
        Text '若西侧铺公共楼道，原主窗将朝楼道' $x ($y+346) 18
    }
}
Text 'Stage 6-A.1-C｜建筑朝向与窗户位置：修改前 / 后' 40 24 29
Text '世界 Y 向上；图中向右 +X、向下 +Z。北/西为本原型局部约定，不代表真实地理朝向。' 40 73 19
Plan 145 $false
Plan 900 $true
Text '示意图按世界坐标绘制，非运行截图。仅预留楼道与室外方向；未制作楼道、楼梯间或街道。' 40 635 19
$path=Join-Path $projectPath 'references/stage6a1c_orientation.png'
$bitmap.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bitmap.Dispose()
Write-Output $path
