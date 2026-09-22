param([string]$BaseUrl = 'http://127.0.0.1:8083')

$ErrorActionPreference = 'Stop'
$root = $BaseUrl.TrimEnd('/')
$estudiante = $null
$curso = $null
$matricula = $null
try {
    $codigo = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $estudiante = Invoke-RestMethod -Uri "$root/api/estudiantes" -Method Post -ContentType 'application/json' -Body (@{
        nombre = 'Luis Flores'
        codigo = "E-$codigo"
    } | ConvertTo-Json -Compress)
    $curso = Invoke-RestMethod -Uri "$root/api/cursos" -Method Post -ContentType 'application/json' -Body (@{
        nombre = 'Programacion I'
        codigo = "C-$codigo"
    } | ConvertTo-Json -Compress)
    $matricula = Invoke-RestMethod -Uri "$root/api/matriculas" -Method Post -ContentType 'application/json' -Body (@{
        fechaRegistro = '2026-09-21'
        estudianteId = $estudiante.id
        cursoId = $curso.id
    } | ConvertTo-Json -Compress)
    $listado = @(Invoke-RestMethod -Uri "$root/api/matriculas" -Method Get)
    if (-not ($listado | Where-Object { $_.id -eq $matricula.id })) { throw 'La matricula no aparece en el listado.' }
    $actualizada = Invoke-RestMethod -Uri "$root/api/matriculas/$($matricula.id)" -Method Put -ContentType 'application/json' -Body (@{
        fechaRegistro = '2026-09-22'
        estudianteId = $estudiante.id
        cursoId = $curso.id
    } | ConvertTo-Json -Compress)
    if ($actualizada.estudianteId -ne $estudiante.id -or $actualizada.cursoId -ne $curso.id -or $actualizada.fechaRegistro -ne '2026-09-22') {
        throw 'La actualización de la matricula es incorrecta.'
    }
    Write-Output "CRUD Universidad OK: Estudiante $($estudiante.id), Curso $($curso.id), Matricula $($matricula.id)."
}
finally {
    if ($matricula) { Invoke-RestMethod -Uri "$root/api/matriculas/$($matricula.id)" -Method Delete | Out-Null }
    if ($curso) { Invoke-RestMethod -Uri "$root/api/cursos/$($curso.id)" -Method Delete | Out-Null }
    if ($estudiante) { Invoke-RestMethod -Uri "$root/api/estudiantes/$($estudiante.id)" -Method Delete | Out-Null }
}
