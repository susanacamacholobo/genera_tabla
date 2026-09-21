param(
    [string]$BaseUrl = 'http://127.0.0.1:8081'
)

$ErrorActionPreference = 'Stop'
$root = $BaseUrl.TrimEnd('/')
$socio = $null
$libro = $null
$prestamo = $null

try {
    $socio = Invoke-RestMethod -Uri "$root/api/socios" -Method Post -ContentType 'application/json' -Body '{"nombre":"Demo Biblioteca"}'
    $isbn = [guid]::NewGuid().ToString('N')
    $libro = Invoke-RestMethod -Uri "$root/api/libros" -Method Post -ContentType 'application/json' -Body (@{ titulo = 'Libro de prueba'; isbn = $isbn } | ConvertTo-Json -Compress)
    $prestamo = Invoke-RestMethod -Uri "$root/api/prestamos" -Method Post -ContentType 'application/json' -Body (@{
        fechaInicio = '2026-09-21T10:00:00'
        libroId = $libro.id
        socioId = $socio.id
    } | ConvertTo-Json -Compress)

    $prestamos = @(Invoke-RestMethod -Uri "$root/api/prestamos" -Method Get)
    if (-not ($prestamos | Where-Object { $_.id -eq $prestamo.id })) {
        throw 'El préstamo no aparece en el listado.'
    }
    $updated = Invoke-RestMethod -Uri "$root/api/prestamos/$($prestamo.id)" -Method Put -ContentType 'application/json' -Body (@{
        fechaInicio = '2026-09-21T10:00:00'
        fechaDevolucion = '2026-09-22T12:00:00'
        libroId = $libro.id
        socioId = $socio.id
    } | ConvertTo-Json -Compress)
    if ($updated.libroId -ne $libro.id -or $updated.socioId -ne $socio.id -or -not $updated.fechaDevolucion) {
        throw 'La actualización o las relaciones del préstamo son incorrectas.'
    }
    Write-Output "CRUD Biblioteca OK: Socio $($socio.id), Libro $($libro.id), Préstamo $($prestamo.id)."
}
finally {
    if ($prestamo) { Invoke-RestMethod -Uri "$root/api/prestamos/$($prestamo.id)" -Method Delete | Out-Null }
    if ($libro) { Invoke-RestMethod -Uri "$root/api/libros/$($libro.id)" -Method Delete | Out-Null }
    if ($socio) { Invoke-RestMethod -Uri "$root/api/socios/$($socio.id)" -Method Delete | Out-Null }
}
