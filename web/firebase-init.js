var firebaseConfig = {
  apiKey: "AIzaSyC01PEs2nFUXrwxKLvjOKkdFHM18DBO_CA",
  authDomain: "esen-notifications.firebaseapp.com",
  projectId: "esen-notifications",
  storageBucket: "esen-notifications.firebasestorage.app",
  messagingSenderId: "555639744428",
  appId: "1:555639744428:web:27822969de854b937d3c09",
  measurementId: "G-Y80JLHBVRB"
};
// Initialize Firebase
if (typeof firebase !== 'undefined') {
  if (!firebase.apps.length) {
    console.log('[Firebase] Initializing Compat App...');
    firebase.initializeApp(firebaseConfig);
  }
} else {
  console.warn('[Firebase] SDK not loaded!');
}

// Global Error Logger for WASM Debugging
window.onerror = function(message, source, lineno, colno, error) {
  console.error('[Global Error]', {message, source, lineno, colno, error});
};
