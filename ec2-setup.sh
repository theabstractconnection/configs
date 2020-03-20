#/bin/bash
# curl https://raw.githubusercontent.com/theabstractconnection/configs/master/ec2-setup.sh | bash

set -e
export IFS=

read -p  "Enter your Localhost username : " LOCAL_USERNAME
read -sp "Enter your Localhost password : " LOCAL_PASSWORD && echo
read -p  "Enter your Github full name   : " GITHUB_FULL_NAME
read -p  "Enter your Github email       : " GITHUB_EMAIL
read -sp "Enter your Github password    : " GITHUB_PASSWORD && echo
read -p  "Enter your Github GPG key id  : " GITHUB_GPG_KEY_ID && echo

# CHANGE USER PASSWORD
# sudo passwd ec2-user
echo "*** Updating $USER password"
echo $LOCAL_PASSWORD | sudo passwd ec2-user --stdin 

# UPDATE SYSTEM
echo "*** Updating system"
sudo yum update -y

# INSTALL ZSH GIT OH-MY-ZSH & CHANGE SHELL to ZSH
echo "*** Insalling util-linux-user zsh git"
sudo yum install util-linux-user zsh git -y
echo "*** Changing shell for $USER to zsh"
chsh -s $(which zsh)
echo "*** Installing oh-my-zsh"
echo "n\nexit\n" | sh -c "$(wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"

# INSTALL ZSH THEME
echo "*** Installing ZSH theme"
export ZSH="/home/$USER/.oh-my-zsh"
export ZSH_CUSTOM="$ZSH/custom"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k 2>&1

# ADD MISSING PLUGINS
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting 2>&1

# CLONE DOTFILES
echo "*** Cloning Dotfiles"
git clone https://$GITHUB_USERNAME:$GITHUB_PASSWORD@https://github.com/abstracts33d/dotfiles.git 2>&1

# INSTALLING SSHPASS
echo "*** Installing sshpass"
wget http://sourceforge.net/projects/sshpass/files/sshpass/1.06/sshpass-1.06.tar.gz/download 
mv download sshpass-1.06.tar.gz
gunzip sshpass-1.06.tar.gz
tar xvf sshpass-1.06.tar
cd sshpass-1.06
sudo yum groupinstall "Development Tools"
sudo ./configure
sudo make install

# COPY SSH/GPG KEYS & IMPORT GPG KEY
echo "*** Copying SSH/GPG keys"
mkdir -p .keys2/{ssh,gpg,ssl}
sshpass -p ${LOCAL_PASSWORD} scp -P1234 $LOCAL_USERNAME@localhost:.keys/ssh/passwordLess_serverKey.pem .keys/ssh/passwordLess_serverKey.pem
sshpass -p ${LOCAL_PASSWORD} scp -P1234 $LOCAL_USERNAME@localhost:.ssh/config .ssh/config
sshpass -p ${LOCAL_PASSWORD} scp -r -P1234 $LOCAL_USERNAME@localhost:.keys/pgp/ .keys/pgp
sed -i 's/s33d_ed25519/passwordLess_serverKey.pem/g' ~/.ssh/config

echo "*** Adding GPG keys"
export GPG_TTY=$(tty)
gpg --list-secret-keys
cd ~/.keys/pgp
for name in *; do
  if [ ! -d "$name" ]; then
    if [[ ! "$name" =~ '\.sh$' ]] && [ "$name" != 'README.md' ]; then
      echo "***  > Importing KEY : $name"
      gpg --import $name
    fi
  fi
done
gpg --list-secret-keys

# SETUP DOTFILES
echo "*** Installing Dotfiles"
cd dotfiles
./install.sh
./git_setup.sh -u "${GITHUB_FULL_NAME}" -e "${GITHUB_EMAIL}" -k "${GITHUB_GPG_KEY_ID}"
git remote set-url origin git@github.com:abstracts33d/dotfiles.git
cd ../

# CLONE CONFIGS
echo "*** Cloning Config"
git clone git@github.com:theabstractconnection/configs.git 2>&1

# INSTALL AMAZON-LINUX-EXTRA PACKAGES
# INSTALL DOCKER
echo "*** Installing Docker"
sudo amazon-linux-extras enable docker
sudo yum clean metadata && sudo yum install docker -y
sudo usermod -a -G docker ec2-user
sudo systemctl enable docker
# sudo systemctl start docker # NEED TO LOGOUT

# INSTALL DOCKER-COMPOSE
# GRAB LATEST RELEASE FROM HERE https://github.com/docker/compose/releases
echo "*** Installing Docker Compose"
sudo curl -L https://github.com/docker/compose/releases/download/1.25.4/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose 
sudo chmod +x /usr/local/bin/docker-compose 
docker-compose version

# INSTALL NGINX
echo "*** Installing Nginx"
sudo amazon-linux-extras enable nginx1
sudo yum clean metadata && sudo yum install nginx -y

echo "*** Configuring Nginx"
sudo mkdir /etc/nginx/certs
sshpass -p ${LOCAL_PASSWORD}  scp -P1234 $LOCAL_USERNAME@localhost:.keys/ssl/theabstractconnection_cloudflare.key .keys/ssl/theabstractconnection_cloudflare.key
sshpass -p ${LOCAL_PASSWORD}  scp -P1234 $LOCAL_USERNAME@localhost:.keys/ssl/theabstractconnection_cloudflare.pem .keys/ssl/theabstractconnection_cloudflare.pem
sudo ln -s /home/ec2-user/.keys/ssl/theabstractconnection_cloudflare.key /etc/nginx/certs/theabstractconnection_cloudflare.key
sudo ln -s /home/ec2-user/.keys/ssl/theabstractconnection_cloudflare.pem /etc/nginx/certs/theabstractconnection_cloudflare.pem
sudo ln -s /home/ec2-user/configs/the-abstract-connection_nginx_server.conf /etc/nginx/conf.d/server.conf
sudo systemctl enable nginx
sudo systemctl start nginx

# INSTALL NVM NODE YARN PM2
echo "*** Installing NVM"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash
. ~/.nvm/nvm.sh
echo "*** Installing NODE"
nvm install node
node -e "console.log('Running Node.js ' + process.version)"
echo "*** Installing YARN"
npm install -g yarn
export PATH="$(yarn global bin):$PATH"
echo 'export PATH="$(yarn global bin):$PATH"' >> ~/.bashrc
echo "*** Installing PM2"
yarn global add pm2
sudo mkdir /opt/bin
sudo ln -s /home/ec2-user/.config/yarn/global/node_modules/.bin/pm2 /opt/bin/pm2

# INSTALL RBENV RUBY BUNDLER
echo "*** Installing RBENV"
git clone https://github.com/rbenv/rbenv.git ~/.rbenv 2>&1
export PATH="$HOME/.rbenv/bin:$PATH"
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
${HOME}/.rbenv/bin/rbenv init
git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build 2>&1
echo "*** Installing RUBY"
rbenv install 2.6.5
echo "*** Installing BUNDLER"
gem install bundler

# INSTALL CODEDEPLOY AGENT
# NEED RUBY & WGET
# GET BUCKET_NAME AND REGION_IDENTIFIER FROM HERE
# https://docs.aws.amazon.com/codedeploy/latest/userguide/resource-kit.html#resource-kit-bucket-names
echo "*** Installing CODEDEPLOY agent"
export CODEDEPLOY_BUCKET_NAME=aws-codedeploy-eu-west-3	
echo 'export CODEDEPLOY_BUCKET_NAME=aws-codedeploy-eu-west-3' >> ~/.bashrc
export AWS_REGION_IDENTIFIER=eu-west-3
echo 'export AWS_REGION_IDENTIFIER=eu-west-3' >> ~/.bashrc
cd ${HOME}
wget -O codeDeployInstall "https://${BUCKET_NAME}.s3.${REGION_IDENTIFIER}.amazonaws.com/latest/install"
chmod +x ./codeDeployInstall
sudo ./codeDeployInstall auto
sudo service codedeploy-agent status

echo "*** Creating PROJECT directory"
# CREATE PROJECTS FOLDER
mkdir projects && cd projects
