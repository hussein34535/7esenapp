const fs = require('fs');
const https = require('https');
const path = require('path');

const fonts = [
    { url: 'https://github.com/google/fonts/raw/main/ofl/cairo/Cairo-Regular.ttf', dest: 'assets/fonts/Cairo-Regular.ttf' },
    { url: 'https://github.com/google/fonts/raw/main/ofl/cairo/Cairo-Bold.ttf', dest: 'assets/fonts/Cairo-Bold.ttf' }
];

const download = (url, dest) => {
    const file = fs.createWriteStream(dest);
    https.get(url, (response) => {
        if (response.statusCode === 302 || response.statusCode === 301) {
            download(response.headers.location, dest); // Follow redirect
            return;
        }
        response.pipe(file);
        file.on('finish', () => {
            file.close();
            console.log(`Downloaded ${dest}`);
        });
    }).on('error', (err) => {
        fs.unlink(dest);
        console.error(`Error downloading ${url}: ${err.message}`);
    });
};

// Ensure directory exists
if (!fs.existsSync('assets/fonts')) {
    fs.mkdirSync('assets/fonts', { recursive: true });
}

fonts.forEach(font => download(font.url, font.dest));
