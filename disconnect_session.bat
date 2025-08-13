@echo off
for /f "tokens=3" %%i in ('query user %USERNAME%') do (
  %windir%\System32\tscon.exe %%i /dest:console
)