@echo off
echo ==========================================
echo      DEEP CLEANING FLUTTER PROJECT
echo ==========================================
echo.
echo 1. Creating temp directory for mirroring...
if not exist temp_empty_cleaner mkdir temp_empty_cleaner

echo.
echo 2. Cleaning 'build' directory...
if exist build (
    robocopy temp_empty_cleaner build /MIR > nul
    rmdir build /s /q
)

echo.
echo 3. Cleaning 'android\app\build' directory...
if exist android\app\build (
    robocopy temp_empty_cleaner android\app\build /MIR > nul
    rmdir android\app\build /s /q
)

echo.
echo 4. Cleaning 'windows\flutter\ephemeral' directory...
if exist windows\flutter\ephemeral (
    robocopy temp_empty_cleaner windows\flutter\ephemeral /MIR > nul
    rmdir windows\flutter\ephemeral /s /q
)

echo.
echo 5. Cleaning '.dart_tool' directory...
if exist .dart_tool (
    robocopy temp_empty_cleaner .dart_tool /MIR > nul
    rmdir .dart_tool /s /q
)

echo.
echo 6. Removing temp directory...
rmdir temp_empty_cleaner /s /q

echo.
echo 7. Running basic flutter clean...
call flutter clean

echo.
echo 8. Fetching dependencies...
call flutter pub get

echo.
echo ==========================================
echo      CLEAN COMPLETE! READY TO RUN.
echo ==========================================
pause
