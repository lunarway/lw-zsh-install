#!/usr/bin/env zsh

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
if [ ! -f $HOME/.zinit/bin/zinit.zsh ]; then
    echo "Installing zinit"
    git clone https://github.com/zdharma-continuum/zinit.git $HOME/.zinit/bin
    if [ $? != 0 ]; then
        echo "Failed to install zinit"
        return
    fi
else
    echo "Updating zinit"
    (cd $HOME/.zinit/bin && git reset --hard && git pull --ff-only)
    if [ $? != 0 ]; then
        echo "Failed to update zinit installation"
        return
    fi
fi

echo ""
echo "Loading zinit"
source $HOME/.zinit/bin/zinit.zsh
if [ $? != 0 ]; then
    echo "Failed to load"
    return
fi
echo ""
echo "Installing lw-zsh"

export LC_ALL= && export LANG=en_US.UTF-8

if [ ! -d $HOME/.zinit/plugins/lunarway---lw-zsh ]; then
    zinit load "ssh://git@github.com/lunarway/lw-zsh"
    if [ $? != 0 ]; then
        echo "Failed to install lw-zsh zinit package"
        return
    fi
else
    zinit update lunarway/lw-zsh
    if [ $? != 0 ]; then
        echo "Failed to update lw-zsh zinit package"
        return
    fi
fi
echo ""
echo "Installing default plugins"
source $HOME/.zinit/plugins/lunarway---lw-zsh/default-plugins.zsh
if [ $? != 0 ]; then
    echo "Failed to register lw-zsh default packages"
    return
fi

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
cp $HOME/.zinit/plugins/lunarway---lw-zsh/.zshrc.example $HOME/.zshrc

vared -p "Please specify your Lunar email: " -c email
sed -i '' "s/your-initials@lunarway.com/$email/g" $HOME/.zshrc

lwPath="~/lunar"
vared -p "Please specify the path to where all Lunar repositories will be stored: " -c lwPath
sed -i '' 's#LW_PATH=.*#LW_PATH='"$lwPath"'#g' $HOME/.zshrc
goPath="~/go"
vared -p "Please specify the Go path: " -c goPath
sed -i '' 's#GOPATH=.*#GOPATH='"$goPath"'#g' $HOME/.zshrc

echo ""
echo "---------------------------------------------------------------------------------------------------------"
echo "Lunar's default zsh configuration is installed"
echo "$backup_message"
echo "Follow font and iterm profile setup at https://github.com/lunarway/lw-zsh"
echo ""
echo "Close this terminal and re-open a new one"
echo "---------------------------------------------------------------------------------------------------------"
echo
