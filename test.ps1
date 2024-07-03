$xyz = "This is\ a test. string!"
$array1 = $xyz.Split('\')
$array2 = $xyz.Split('.')

Write-Output $array1
Write-Output $array2