# rekliner/next-pm2-deploy

A template for deploying next sites with zero downtime to a linux server running pm2.  

This is not a Nextjs app in itself, just a set of files to be added to your existing app.

# Features

- Follows the deployment methods used by envoyer.io
- Zero downtime: It only enables the new commit once the installation and build is successful.  Then a symbolic link is "instantly" swapped to use the newest code.
- Responds to `yoursite.com/api/deploy` endpoint
- Rate limited to prevent endpoint abuse - using [code from Vercel](https://github.com/vercel/next.js/tree/canary/examples/api-routes-rate-limit)
- Checks for existing deployment and prevents running 2 concurrent deployments
- Optional deploy key header for basic security
- Cancels deployment if it's the same commit as is currently live
- Cleans up older or failed deployment files to keep disk space consistant

# Setup

- Install [PM2](https://github.com/Unitech/pm2) on the server.  Command for Ubuntu/Debian is `sudo apt install pm2`
- Install reverse proxy like NGINX if you don't want traffic directly to your app. [There are a million tutorials.](https://gist.github.com/kocisov/2a9567eb51b83dfef48efce02ef3ab06)  It should point to the `current` directory in your project folder.  This is a symbolic link created at first deployment.  
- Only the .env file needs to be edited.  Necessary variables are in the `.env.example` in this repo.
- Multiple .env files supported. One or more can be present. The override heirachy is .env.local -> .env.staging -> .env.production -> .env
- Create a directory on the webserver for your project.  
- Add a subdirectory `releases` and if persistant storage is desired `storage`
- Add the files in this template to your existing Next app repo (except this reamde of course!)
- Upload your .env file to the server in the main project directory (No, it should not be in your repo!)
- Clone your next app into the `releases` directory.
- Run the deploy script from the newly cloned folder.  `. deploy.sh` or `bash deploy.sh`
- Don't forget to save your PM2 setup in case of server reboot: `pm2 startup && pm2 save`

# What will happen

- A log file will be started in the current directory `last_deploy.log`
- A new directory will be created with the current timestamp in the `releases` directory
- NPM requirements will be installed
- A production build will be created using `npx next build`
- The `current` symbolic link will be recreated to point to this new build.
- The previous PM2 process will be deleted and a new one begun using `npx next start` with the new files

# To deploy

- A visit to `yoursite.com/api/deploy` will trigger deployment.  By default more than one visit a minute is ignored.
- In Github or Gitlab a `Webhook` can be set up for a branch under the repo `Settings`.  
This way a deployment will be triggered by gitlab requesting `yoursite.com/api/deploy` whenever code is checked in to that branch.  
Also, a deployment key or secret can be added to help secure your endpoint. (look for tutorials on the header this adds to the request)
- Running the deploy.sh script manually from one of the release directories works just fine.
