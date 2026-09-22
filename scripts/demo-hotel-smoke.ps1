param([string]$BaseUrl = 'http://127.0.0.1:8082')

$ErrorActionPreference = 'Stop'
$root = $BaseUrl.TrimEnd('/')
$huesped = $null
$habitacion = $null
$reserva = $null
try {
    $huesped = Invoke-RestMethod -Uri "$root/api/huespedes" -Method Post -ContentType 'application/json' -Body '{"nombre":"Ana Perez"}'
    $numero = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $habitacion = Invoke-RestMethod -Uri "$root/api/habitaciones" -Method Post -ContentType 'application/json' -Body (@{
        numero = $numero
        precioNoche = 120.50
    } | ConvertTo-Json -Compress)
    $reserva = Invoke-RestMethod -Uri "$root/api/reservas" -Method Post -ContentType 'application/json' -Body (@{
        fechaEntrada = '2026-09-21'
        fechaSalida = '2026-09-23'
        huespedId = $huesped.id
        habitacionId = $habitacion.id
    } | ConvertTo-Json -Compress)
    $listado = @(Invoke-RestMethod -Uri "$root/api/reservas" -Method Get)
    if (-not ($listado | Where-Object { $_.id -eq $reserva.id })) { throw 'La reserva no aparece en el listado.' }
    $actualizada = Invoke-RestMethod -Uri "$root/api/reservas/$($reserva.id)" -Method Put -ContentType 'application/json' -Body (@{
        fechaEntrada = '2026-09-21'
        fechaSalida = '2026-09-24'
        huespedId = $huesped.id
        habitacionId = $habitacion.id
    } | ConvertTo-Json -Compress)
    if ($actualizada.huespedId -ne $huesped.id -or $actualizada.habitacionId -ne $habitacion.id -or $actualizada.fechaSalida -ne '2026-09-24') {
        throw 'La actualización de la reserva es incorrecta.'
    }
    Write-Output "CRUD Hotel OK: Huesped $($huesped.id), Habitacion $($habitacion.id), Reserva $($reserva.id)."
}
finally {
    if ($reserva) { Invoke-RestMethod -Uri "$root/api/reservas/$($reserva.id)" -Method Delete | Out-Null }
    if ($habitacion) { Invoke-RestMethod -Uri "$root/api/habitaciones/$($habitacion.id)" -Method Delete | Out-Null }
    if ($huesped) { Invoke-RestMethod -Uri "$root/api/huespedes/$($huesped.id)" -Method Delete | Out-Null }
}
