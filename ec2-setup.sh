#/bin/bash
# scp -r -P1234 seed@localhost:.keys .
# scp -P1234 seed@localhost:.ssh/config .ssh/config
# curl -H "Cache-Control: no-cache" https://raw.githubusercontent.com/theabstractconnection/configs/master/ec2-setup.sh >> ec2-setup.sh; chmod +x ec2-setup.sh; ./ec2-setup.sh

set -e
export IFS=
touch ec2-setup.log # TODO LOG TO FILE

read -sp ">>> Enter the NEW password        : " USER_PASSWORD && echo
read -p  ">>> Enter your Github full name   : " GITHUB_FULL_NAME
read -p  ">>> Enter your Github email       : " GITHUB_EMAIL
read -sp ">>> Enter your Github password    : " GITHUB_PASSWORD && echo
read -p  ">>> Enter your Github GPG key id  : " GITHUB_GPG_KEY_ID && echo

# REMOVE USELESS KEYS

cd ~/.keys
#RECURSIVELY APPLY CMD/SCRIPT FROM CWD IN EACH SUBDIR
global() {
  shopt -s globstar # enable Recursive Globing
  origdir="$PWD"
  for i in **/; do
    cd "$i" || true # ignore error
    echo -n "${PWD}: "
    eval "$1" # pass command inside ""
    # eval "$@" # pass script script.sh
    echo
    cd "$origdir"
  done
}
shopt -s extglob # enable Extended Pattern Matching
global "rm -rf !(ssh|pgp|ssl|passwordLess_serverKey.*|*.pgp|theabstractconnection_cloudflare.*)"
cd ~

# CHANGE USER PASSWORD
echo "☠☠☠ Updating $USER password"
echo $USER_PASSWORD | sudo passwd ec2-user --stdin 

# UPDATE SYSTEM
echo "☠☠☠ Updating system"
sudo yum update -y

# INSTALL ZSH GIT OH-MY-ZSH & CHANGE SHELL to ZSH
echo "☠☠☠ Insalling util-linux-user zsh git"
sudo yum install util-linux-user zsh git -y
echo "☠☠☠ Changing shell for $USER to zsh"
echo "$USER_PASSWORD" |  chsh -s $(which zsh)
echo "☠☠☠ Installing oh-my-zsh"
echo "n\nexit\n" | sh -c "$(wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"

# INSTALL ZSH THEME
echo "☠☠☠ Installing ZSH theme"
export ZSH="/home/$USER/.oh-my-zsh"
export ZSH_CUSTOM="$ZSH/custom"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k 2>&1

# ADD MISSING PLUGINS
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting 2>&1

# CLONE DOTFILES
echo "☠☠☠ Cloning Dotfiles"
git clone https://github.com/abstracts33d/dotfiles.git 2>&1


# IMPORT GPG KEY
echo "☠☠☠ Importing SSH/GPG keys"
sed -i 's/s33d_ed25519/passwordLess_serverKey.pem/g' ~/.ssh/config

echo "☠☠☠ Adding GPG keys"
export GPG_TTY=$(tty)
gpg --list-secret-keys
cd ~/.keys/pgp
for name in *; do
  if [ ! -d "$name" ]; then
    if [[ ! "$name" =~ '\.sh$' ]] && [ "$name" != 'README.md' ]; then
      echo "☠☠☠  > Importing KEY : $name"
      gpg --import $name || true
    fi
  fi
done
gpg --list-secret-keys

# SETUP DOTFILES
echo "☠☠☠ Installing Dotfiles"
cd ~/dotfiles
./install.sh
./git_setup.sh -u "${GITHUB_FULL_NAME}" -e "${GITHUB_EMAIL}" -k "${GITHUB_GPG_KEY_ID}"
git remote set-url origin git@github.com:abstracts33d/dotfiles.git
cd ~

# CLONE CONFIGS
echo "☠☠☠ Cloning Config"
ssh-keyscan -H github.com >> ~/.ssh/known_hosts 2>&1 # ADD GITHUB KEY TO KNOWN_HOSTS
git clone git@github.com:theabstractconnection/configs.git 2>&1

# CLONE CONFIGS
echo "☠☠☠ Cloning Envs"
git clone git@github.com:abstracts33d/envs.git 2>&1

# INSTALL CODEDEPLOY AGENT
# GET BUCKET_NAME AND REGION_IDENTIFIER FROM HERE
# https://docs.aws.amazon.com/codedeploy/latest/userguide/resource-kit.html#resource-kit-bucket-names
echo "☠☠☠ Installing CODEDEPLOY agent"
sudo yum install yum-plugin-versionlock -y 
sudo yum install ruby wget -y # INSTALL SYSTEM RUBY
PATH=/usr/bin:$PATH wget -O codeDeployInstall "https://aws-codedeploy-eu-west-3.s3.eu-west-3.amazonaws.com/latest/install"
chmod +x ./codeDeployInstall
sudo ./codeDeployInstall auto
sudo service codedeploy-agent status
sudo yum versionlock ruby # LOCK SYSTEMRUBY TO 2.0.0 IF CODEDEPLOY NEED TO BE REINSTALLED

# INSTALL AMAZON-LINUX-EXTRA PACKAGES
# INSTALL DOCKER
echo "☠☠☠ Installing Docker"
sudo amazon-linux-extras enable docker
sudo yum clean metadata && sudo yum install docker -y
sudo usermod -a -G docker ec2-user
sudo systemctl enable docker
# sudo systemctl start docker # NEED TO LOGOUT

# INSTALL DOCKER-COMPOSE
# GRAB LATEST RELEASE FROM HERE https://github.com/docker/compose/releases
echo "☠☠☠ Installing Docker Compose"
sudo curl -L https://github.com/docker/compose/releases/download/1.25.4/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose 
sudo chmod +x /usr/local/bin/docker-compose 
docker-compose version

# INSTALL NGINX
echo "☠☠☠ Installing Nginx"
sudo amazon-linux-extras enable nginx1
sudo yum clean metadata && sudo yum install nginx -y

echo "☠☠☠ Configuring Nginx"
sudo mkdir -p /etc/nginx/certs
sudo ln -s ~/.keys/ssl/theabstractconnection_cloudflare.key /etc/nginx/certs/theabstractconnection_cloudflare.key
sudo ln -s ~/.keys/ssl/theabstractconnection_cloudflare.pem /etc/nginx/certs/theabstractconnection_cloudflare.pem
sudo ln -s ~/configs/the-abstract-connection_nginx_server.conf /etc/nginx/conf.d/server.conf
sudo systemctl enable nginx
sudo systemctl start nginx

# INSTALL NVM NODE YARN PM2
echo "☠☠☠ Installing NVM"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash
. ~/.nvm/nvm.sh
echo "☠☠☠ Installing NODE"
nvm install node
node -e "console.log('Running Node.js ' + process.version)"
echo "☠☠☠ Installing YARN"
npm install -g yarn
export PATH="$(yarn global bin):$PATH"
echo 'export PATH="$(yarn global bin):$PATH"' >> ~/.bashrc
echo "☠☠☠ Installing PM2"
yarn global add pm2
sudo mkdir -p /opt/bin
sudo ln -s $(which pm2) /opt/bin/pm2

# INSTALL RBENV RUBY BUNDLER
echo "☠☠☠ Installing RBENV"
sudo yum groupinstall "Development Tools" -y
git clone https://github.com/rbenv/rbenv.git ~/.rbenv 2>&1
export PATH="$HOME/.rbenv/bin:$PATH"
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
~/.rbenv/bin/rbenv init || true
eval "$(rbenv init -)"
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build 2>&1

echo "☠☠☠ Installing RUBY"
sudo yum install openssl-devel readline-devel -y
rbenv install 2.6.5
rbenv global 2.6.5
echo "☠☠☠ Installing BUNDLER & RAILS"
gem install bundler rails rake

echo "☠☠☠ Creating PROJECT directory"
# CREATE PROJECTS FOLDER
mkdir -p projects && cd projects

sudo reboot