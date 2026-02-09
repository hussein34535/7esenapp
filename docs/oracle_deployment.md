# Deploying Flutter PWA to Oracle Cloud

This guide explains how to host your Flutter Web PWA on Oracle Cloud using **Object Storage** (Buckets) or a **Compute Instance** (VM).

## Option 1: Oracle Cloud Object Storage (Recommended for Static Sites)

This method is serverless, fast, and free/cheap.

1.  **Build the Project**:
    ```bash
    flutter build web --wasm --release
    ```
    This creates the `build/web` folder.

2.  **Create a Bucket**:
    -   Log in to **Oracle Cloud Console**.
    -   Go to **Storage** -> **Buckets**.
    -   Click **Create Bucket**.
    -   Name: `hesen-pwa` (or similar).
    -   **Important**: Uncheck "Emit Object Events" if not needed.
    -   Click **Create**.

3.  **Configure Public Access**:
    -   Click on your new bucket.
    -   Under **Visibility**, click **Edit Visibility**.
    -   Select **Public** (so anyone can see your site).

4.  **Upload Files**:
    -   Go to likely `Upload` and select all files from your local `build/web` folder.
    -   **Tip**: Maintain the folder structure (e.g., `assets/`, `icons/`). You might need to use a tool like **Cyberduck** or **OCI CLI** for easier folder uploading, as the web console can be tedious for folders.

    **Using OCI CLI (Command Line):**
    ```bash
    oci os object bulk-upload -bn hesen-pwa --src-dir build/web
    ```

5.  **Access the Site**:
    -   The URL will be something like:
        `https://objectstorage.<region>.oraclecloud.com/n/<namespace>/b/hesen-pwa/o/index.html`
    -   To make it look professional (e.g., `www.hesentv.com`), you need to use a **Load Balancer** or **API Gateway**, but for testing, the direct link works.

## Option 2: Compute Instance (Virtual Machine) with Nginx

If you already have a VM (Ubuntu/Linux) on Oracle Cloud.

1.  **Build the Project**:
    ```bash
    flutter build web --wasm --release
    ```

2.  **SSH into your VM**:
    ```bash
    ssh ubuntu@<your-vm-ip>
    ```

3.  **Install Nginx**:
    ```bash
    sudo apt update
    sudo apt install nginx
    ```

4.  **Upload Files**:
    Use `scp` to copy the `build/web` files to the VM:
    ```bash
    scp -r build/web/* ubuntu@<your-vm-ip>:/var/www/html/
    ```

5.  **Configure Nginx**:
    Edit the default config:
    ```bash
    sudo nano /etc/nginx/sites-available/default
    ```
    Ensure `root` points to `/var/www/html` and adds fallback for SPA (Single Page App):
    ```nginx
    server {
        listen 80;
        server_name _;
        root /var/www/html;
        index index.html;

        location / {
            try_files $uri $uri/ /index.html;
        }
    }
    ```

6.  **Restart Nginx**:
    ```bash
    sudo systemctl restart nginx
    ```

7.  **Access**:
    Open `http://<your-vm-ip>` in your browser.
