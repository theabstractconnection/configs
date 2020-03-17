# CHANGE USER PASSWORD
sudo passwd ec2-user
# UPDATE SYSTEM
sudo yum update -y

# INSTALL ZSH GIT OH-MY-ZSH & CHANGE SHELL to ZSH
sudo yum install -y util-linux-user zsh git
chsh -s $(which zsh)
sh -c "$(wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"

# CLONE DOTFILES
git clone https://github.com/abstracts33d/dotfiles.git

# COPY SSH/GPG KEYS & IMPORT GPG KEY
mkdir .keys
mkdir .keys/ssh
mkdir .keys/gpg

scp -P1234 seed@localhost:.keys/ssh/s33d_ed25519 .keys/ssh/s33d_ed25519
scp -r -P1234 seed@localhost:.keys/pgp/ .keys/pgp
scp -P1234 seed@localhost:.ssh/config .ssh/config

export GPG_TTY=$(tty)
gpg --list-secret-keys

cd ~/.keys/pgp
for name in *; do
  if [ ! -d "$name" ]; then
    if [[ ! "$name" =~ '\.sh$' ]] && [ "$name" != 'README.md' ]; then
      echo "-----> Importing KEY : $name"
      gpg --import $name
    fi
  fi
done

gpg --list-secret-keys

# SETUP DOTFILES
cd dotfiles
gpg --list-secret-keys --keyid-format LONG
./install.sh 
./git_setup.sh


# UPDATE DOTFILE REMOTE TO SSH
git remote set-url origin git@github.com:abstracts33d/dotfiles.git

cd
# INSTALL ZSH THEME
export ZSH="/home/$USER/.oh-my-zsh"
export ZSH_CUSTOM="$ZSH/custom"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k

# ADD MISSING PLUGINS
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting

# CLONE CONFIGS
git clone git@github.com:theabstractconnection/configs.git

# INSTALL AMAZON-LINUX-EXTRA PACKAGES
which amazon-linux-extras

# DOCKER
sudo amazon-linux-extras enable docker
sudo yum clean metadata && sudo yum install docker
sudo usermod -a -G docker ec2-user
sudo systemctl enable docker
sudo systemctl start docker # NEED TO LOGOUT

# INSTALL DOCKER-COMPOSE
sudo curl -L https://github.com/docker/compose/releases/download/1.25.4/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose # GRAB LATEST RELEASE FROM HERE https://github.com/docker/compose/releases
sudo chmod +x /usr/local/bin/docker-compose 

# NGINX
sudo amazon-linux-extras enable nginx1 -y
sudo yum clean metadata && sudo yum install nginx -y

sudo mkdir /etc/nginx/certs
sudo scp -P1234 seed@localhost:.keys/ssl/theabstractconnection_cloudflare.key /etc/nginx/certs/theabstractconnection_cloudflare.key
sudo scp -P1234 seed@localhost:.keys/ssl/theabstractconnection_cloudflare.pem /etc/nginx/certs/theabstractconnection_cloudflare.pem
sudo cp configs/the-abstract-connection_nginx_server.conf /etc/nginx/conf.d/server.conf
sudo systemctl enable nginx
sudo systemctl start nginx


# CREATE PROJECTS FOLDER
mkdir projects && cd projects
