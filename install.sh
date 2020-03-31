#!/usr/bin/env zsh

echo -n "Checking bitbucket access"
bitbucket_access=$(ssh -T git@bitbucket.org 2>&1)
if [[ $bitbucket_access =~ "^logged in as" ]]; then
    echo " - seems good"
else
    echo ""
    echo "-------------------------------------------------------"
    echo "No access to BitBucket detected. If you don't need it, just ignore this. Otherwise fix it and try again."
    echo "Consider 'ssh-add -K' or updating your .ssh/config like described at https://nerderati.com/2011/03/17/simplify-your-life-with-an-ssh-config-file/"
    echo "-------------------------------------------------------"
fi
echo -n "Checking github access"
github_access=$(ssh -T git@github.com 2>&1)
if [[ $github_access =~ "^Hi " ]]; then
    echo " - seems good"
else
    echo ""
    echo "-------------------------------------------------------"
    echo "Please fix access to github an try again."
    echo "Consider 'ssh-add -K' or updating your .ssh/config like described at https://nerderati.com/2011/03/17/simplify-your-life-with-an-ssh-config-file/"
    echo "-------------------------------------------------------"
    return
fi

# we expect some version of zsh is installed
echo "Installing zplug"
curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
echo ""
echo "Loading zplug"
source ~/.zplug/init.zsh
echo ""
echo "Installing lw-zsh"
ZPLUG_PROTOCOL=ssh
export LC_ALL= && export LANG=en_US.UTF-8
zplug "lunarway/lw-zsh"
if [ ! -d ~/.zplug/repos/lunarway/lw-zsh ] && [ ! -d ~/.zplug/repos/lunarway/lw-zsh ]; then
    zplug install
else
    zplug update lunarway/lw-zsh
fi
echo ""
echo "Installing default plugins"
source ~/.zplug/repos/lunarway/lw-zsh/default-plugins.zsh
zplug install
echo ""
echo "Moving existing ~/.zshrc"
backup=~/.zshrc.$(date +%Y-%m-%d_%H-%M-%S).backup
cp ~/.zshrc $backup
echo ""
echo "Generating new .zshrc"
vared -p "Please specify your Lunar email: " -c tmp
cp ~/.zplug/repos/lunarway/lw-zsh/.zshrc.example ~/.zshrc
sed -i -- "s/your-initials@lunarway.com/$tmp/g" ~/.zshrc
echo ""
echo "---------------------------------------------------------------------------------------------------------"
echo "Lunar Way's default zsh is installed"
echo ""
echo "To re-apply your customized alias' and more copy stuff back from $backup to ~/.zshrc."
echo ""
echo "Follow font and iterm profile setup at https://github.com/lunarway/lw-zsh"
echo ""
echo "Close this terminal and re-open a new one"
echo "---------------------------------------------------------------------------------------------------------"
echo
