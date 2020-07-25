#!/usr/bin/env zsh

echo -n "Checking BitBucket access"
bitbucket_access=$(ssh -T git@bitbucket.org 2>&1)
if [[ $bitbucket_access =~ "^logged in as" ]]; then
    echo " - OK"
else
    echo ""
    echo "-------------------------------------------------------"
    echo "No access to BitBucket detected. If you don't need it, just ignore this. Otherwise fix it and try again."
    echo "Consider 'ssh-add -K' or updating your .ssh/config like described at https://nerderati.com/2011/03/17/simplify-your-life-with-an-ssh-config-file/"
    echo "-------------------------------------------------------"
fi
echo -n "Checking GitHub access"
github_access=$(ssh -T git@github.com 2>&1)
if [[ $github_access =~ "^Hi " ]]; then
    echo " - OK"
else
    echo ""
    echo "-------------------------------------------------------"
    echo "Please fix access to GitHub an try again."
    echo "Consider 'ssh-add -K' or updating your .ssh/config like described at https://nerderati.com/2011/03/17/simplify-your-life-with-an-ssh-config-file/"
    echo "-------------------------------------------------------"
    return
fi

# we expect some version of zsh is installed
if [ -z "$ZPLUG_HOME" ]; then
    echo "Installing zplug"
    curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
else
    echo "Updating zplug"
    (cd $ZPLUG_HOME && git pull --ff-only)
fi

echo ""
echo "Loading zplug"
source $HOME/.zplug/init.zsh
echo ""
echo "Installing lw-zsh"
ZPLUG_PROTOCOL=ssh
export LC_ALL= && export LANG=en_US.UTF-8
zplug "lunarway/lw-zsh"
if [ ! -d $HOME/.zplug/repos/lunarway/lw-zsh ] && [ ! -d $HOME/.zplug/repos/lunarway/lw-zsh ]; then
    zplug install
else
    zplug update lunarway/lw-zsh
fi
echo ""
echo "Installing default plugins"
source $HOME/.zplug/repos/lunarway/lw-zsh/default-plugins.zsh
zplug install

# Backup existing .zshrc if it exists
if [ -f $HOME/.zshrc ]; then
    echo ""
    backup=$HOME/.zshrc.$(date +%Y-%m-%d_%H-%M-%S).backup
    echo "Moving existing $HOME/.zshrc into $backup"
    cp $HOME/.zshrc $backup
    backup_message='
To re-apply your customized aliases and more copy stuff back from '$backup' to '$HOME'/.zshrc.
'
fi

echo ""
echo "Generating new .zshrc"
vared -p "Please specify your Lunar email: " -c tmp
cp $HOME/.zplug/repos/lunarway/lw-zsh/.zshrc.example $HOME/.zshrc

sed -i '' "s/your-initials@lunarway.com/$tmp/g" $HOME/.zshrc

echo ""
echo "---------------------------------------------------------------------------------------------------------"
echo "Lunar's default zsh configuration is installed"
echo "$backup_message"
echo "Follow font and iterm profile setup at https://github.com/lunarway/lw-zsh"
echo ""
echo "Close this terminal and re-open a new one"
echo "---------------------------------------------------------------------------------------------------------"
echo
