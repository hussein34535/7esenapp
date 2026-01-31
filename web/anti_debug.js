
(function () {
    // 1. Disable Right Click
    document.addEventListener('contextmenu', function (e) {
        e.preventDefault();
        return false;
    });

    // 2. Disable DevTools Keys
    document.addEventListener('keydown', function (e) {
        // F12
        if (e.keyCode == 123) {
            e.preventDefault();
            return false;
        }
        // Ctrl+Shift+I, Ctrl+Shift+J, Ctrl+Shift+C
        if (e.ctrlKey && e.shiftKey && (e.keyCode == 73 || e.keyCode == 74 || e.keyCode == 67)) {
            e.preventDefault();
            return false;
        }
        // Ctrl+U (View Source)
        if (e.ctrlKey && e.keyCode == 85) {
            e.preventDefault();
            return false;
        }
    });

    // 3. DevTools Detection & Console Clearing
    // This loop clears potential leaks and attempts to freeze debugger if opened
    setInterval(function () {
        // Clear console checking
        if (window.console && console.clear) {
            console.clear();
        }

        // Debugger trap: heavily impacts performance if DevTools is open
        // This makes stepping through code painful
        const start = new Date().getTime();
        debugger;
        const end = new Date().getTime();

        if (end - start > 100) {
            // DevTools detected!
            document.body.innerHTML = '<h1>Security Alert: Developer Tools Detected.</h1>';
            // Redirect or crash
            window.location.reload();
        }
    }, 1000);

    // 4. Obfuscate Global XHR Interceptor variable if possible (rename in cleanup)
    // For now, we clear the logs from previous scripts by overwriting basic console methods temporarily
    const noop = function () { };
    // window.console.log = noop;
    // window.console.warn = noop; 
    // window.console.error = noop;
    // (Disabled globally here to allow user debugging IF needed, but recommended in production)

})();
