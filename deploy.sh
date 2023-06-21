#!/bin/bash
RUN_DIR=$(pwd -LP)
#the presence of a .env file overrides the production file, which overrides staging, which overrides local
source ../../.env.local
source ../../.env.staging
source ../../.env.production  
source  ../../.env

#the following variables need to be in at least one of the above files.
#APP_NAME="name-of-app" #pm2 handle for the process
#APP_DIR="/home/userdir/$APP_NAME"  #needs to be an absolute directory. Webserver should point to the "current" subdirectory within
#REPO="git@gitlab.yourhost.com:project/repo.git"
#BRANCH="master"
#ENV="production" #or staging or local.  defaults to production
#PORT=port to run the app on
#STORAGE_DIR="$APP_DIR/storage" #optional: a directory for persistant storage, if necessary


echo "App Name: $APP_NAME"
echo "App Dir: $APP_DIR"
echo "Repo: $REPO"
echo "Branch: $BRANCH"
echo "Environment: $ENV"
echo "Port: $PORT"
echo "Storage Directory: $STORAGE_DIR"
echo "Run Dir: $RUN_DIR"

cd $APP_DIR/current
LAST=$(git rev-parse HEAD)
echo "$LAST is last commit" 

#create directory for new release
DATE=`date +%Y%m%d%H%M%S`
echo "Creating $APP_DIR/releases/$DATE"
mkdir $APP_DIR/releases/$DATE
cd $APP_DIR/releases/$DATE

#copy in the repo
echo "Cloning $REPO into $APP_DIR/releases/$DATE"
git clone -b $BRANCH $REPO .

#check if it is indeed a new commit
NEW=$(git rev-parse HEAD)
echo "$NEW is new commit" 
if [ $LAST = $NEW ]; then
  echo "Commit is same hash, aborting!!"
  cp -f $RUN_DIR/latest_deploy.log $APP_DIR/latest_deploy.log
  cd $APP_DIR
  rm -Rf $APP_DIR/releases/$DATE
  #if its an ssh terminal return to prompt, otherwise exit the thread
  if [[ -t 0 || -p /dev/stdin ]]; then
    return
  else
    exit 1
  fi
fi

# create symbolic links to persistant server environment files
DOTENV=""
if [ ! -z "$ENV" ]; then
  DOTENV=.$ENV  #if ENV is set, add a period separator to the filename
fi
echo "linking $APP_DIR/.env$DOTENV to .env"
ln -s $APP_DIR/.env$DOTENV .env
#add link to persistant storage if necessary
if [ $STORAGE_DIR ]; then
  echo "linking $APP_DIR/releases/$DATE/storage to $STORAGE_DIR"
  ln -s $STORAGE_DIR $APP_DIR/releases/$DATE/storage 
fi


echo "installing npm packages"
npm install
echo "building $APP_DIR/releases/$DATE $DOTENV"
if dotenv -e .env$DOTENV -- npx next build; then 
  echo "build successful"
else
  echo "build failed! deleting release and aborting" #important to free the space in case failed deployments pile up
  cp -f $RUN_DIR/latest_deploy.log $APP_DIR/latest_deploy.log
  cd $APP_DIR
  rm -Rf $APP_DIR/releases/$DATE
  if [[ -t 0 || -p /dev/stdin ]]; then
    return
  else
    exit 1
  fi
fi

#remove existing /current link and re-link to this latest directory
echo "linking $APP_DIR/releases/$DATE to $APP_DIR/current"
rm $APP_DIR/current
ln -s $APP_DIR/releases/$DATE $APP_DIR/current

#restart the node server to serve latest build
echo "restarting node server for $APP_NAME at $APP_DIR/releases/$DATE"
echo "cd $APP_DIR/releases/$DATE"
      cd $APP_DIR/releases/$DATE
echo "pm2 delete $APP_NAME"
      pm2 delete $APP_NAME
echo "lsof -i tcp:${PORT} | awk 'NR!=1 {print $2}' | xargs kill"
      lsof -i tcp:${PORT} | awk 'NR!=1 {print $2}' | xargs kill
echo 'pm2 start npx --time --name="$APP_NAME" --no-treekill --node-args="--max-old-space-size=3096" -- next start -- --port=$PORT'
      pm2 start npx --time --name="$APP_NAME" --no-treekill --node-args="--max-old-space-size=3096" -- next start -- --port=$PORT



#delete anything older than the last 4 releases
OLD=$(ls -tl $APP_DIR/releases | grep '^d' | awk '{print $(NF)}' | tail -n+5 | sed "s|^|$APP_DIR/releases/|")
OLD_ONELINE="$OLD | sed -z 's/\n/ /g'"
echo "removing: $OLD"
if [ ! $OLD_ONELINE = "$APP_DIR/releases/" ]; then
  rm -Rf $OLD
fi


echo "updating this script copy in appdir with the latest from the repo"
chmod u+x $APP_DIR/releases/$DATE/deploy.sh
cp -f $APP_DIR/releases/$DATE/deploy.sh $APP_DIR/deploy.sh
chmod u+x $APP_DIR/deploy.sh

#cd ~
echo "deployed!"
#cp -f $RUN_DIR/last_deploy.log $APP_DIR/last_deploy.log