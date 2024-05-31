# quil-manager
 Quilibrium Node deployment & management script for Quilibrium v1.4.18-p2

## Table of Contents
- [Installation](#installation)
- [Usage](#usage)
- [Options & Features](#options--features)

## Installation
 1. Download the `.sh` script file to the server.

 2. Under the directory where the script is located, run the following command to give the script execution permission.
```shell
chmod +x quil-manager.sh
```

## Usage
 1. Run the script with the following command.
```shell
./quil-manager.sh
```

 2. Select the options following the below steps:
    - Option 1: Deploy Quilibrium Node (Only run once)
    - Option 2: Verify the configurations and settings. Compare the output with the expected output in the [Options & Features](#options--features) section.
    - Option 4: Install qclient and grpcurl
    - Option 5: Start the Quilibrium Node and run for the first time to generate the .config folder.
    - (Optional) Option 3: Modify the .config.yml file.
    - (Optional) Reboot the server to apply the ufw changes with 'sudo reboot'
    - Option 5: Start the Quilibrium Node
    - When `REPAIR` is generated in the `.config` folder, sync the Quilibrium Node with Option 9.
    - (Optional) Backup the Quilibrium Node when `keys.yml` is fully generated (no longer showing `null`) with Option 10.
    
## Options & Features
 1. **Deploy Quilibrium Node (Only run once)**
    Deploy Quilibrium Node for new servers or re-deploy Quilibrium Node for existing servers. (Recommended to run only once)

 2. **Verify the configuration file**
    Verify the ufw settings and node configuration file. The output should show the following if the node is properly configured.

    Current UFW status:
    ```
    Status: active

    To                         Action      From
    --                         ------      ----
    22                         ALLOW       Anywhere                  
    8336                       ALLOW       Anywhere                  
    443                        ALLOW       Anywhere                  
    22 (v6)                    ALLOW       Anywhere (v6)             
    8336 (v6)                  ALLOW       Anywhere (v6)             
    443 (v6)                   ALLOW       Anywhere (v6) 
    ```            

    Current go version:
    ```
    go version go1.20.14 linux/amd64
    ```

    Current network settings:
    ```
    net.core.rmem_max = 600000000
    net.core.wmem_max = 600000000
    ```

    Current config.yml settings:
    ```
    listenGrpcMultiaddr: /ip4/127.0.0.1/tcp/8337
    statsMultiaddr: "/dns/stats.quilibrium.com/tcp/443"
    ```

    Current service configuration:
    ```
    [Unit]
    Description=Ceremony Client Go App Service
    [Service]
    Type=simple
    Restart=always
    RestartSec=5s
    WorkingDirectory=/root/ceremonyclient/node
    Environment=GOEXPERIMENT=arenas
    ExecStart=/root/ceremonyclient/node/node-1.4.18-linux-amd64
    [Install]
    WantedBy=multi-user.target
    ```

    Current qclient and grpcurl installation status:
    ```
    grpcurl  qclient
    ```

    3. **Modify the .config.yml file**
    After running the node for the first time, the .config.yml file will be generated. This option will modify the `listenGrpcMultiaddr` and `statsMultiaddr` settings in the .config.yml file to enable the GRPC.

    4. **Install qclient and grpcurl**
    Install qclient and grpcurl for the Quilibrium Node.

    5. **Start the Quilibrium Node**
    Start the Quilibrium Node service.

    6. **Stop the Quilibrium Node**
    Stop the Quilibrium Node service.

    7. **View the Quilibrium Node logs**
    Display real-time logs of the Quilibrium Node. Press `Ctrl + C` to exit the log.

    8. **View the Quilibrium Node status(GRPC)**
    Display the status of the Quilibrium Node using GRPC. Install the `grpcurl` and modify the .config.yml file before using this option.

    9. **Sync the Quilibrium Node**
    Replace the `store` folder with the latest snapshot and create a backup of the current `store` folder.

    10. **Backup the Quilibrium Node**
    Create a backup of the `config.yml` and `keys.yml`. A scp command will be generated for you to copy the backup file to your local machine.

    11. **Update the Quilibrium Node**
    Update the Quilibrium Node to the latest version.




