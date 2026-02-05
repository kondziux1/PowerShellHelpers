# Source - https://stackoverflow.com/a/31845512
# Posted by mpen, modified by community. See post 'Timeline' for change history
# Retrieved 2026-01-28, License - CC BY-SA 3.0

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 
