@echo off
echo Deleting corrupted android build folder...
if exist "android\app\build" (
    rmdir /s /q "android\app\build"
    echo Deleted android\app\build
) else (
    echo android\app\build not found (Good)
)

echo Deleting root build folder...
if exist "build" (
    rmdir /s /q "build"
    echo Deleted build
)

echo Cleaning Flutter...
call flutter clean
echo.
echo DONE. Please run 'flutter run' now.
pause
