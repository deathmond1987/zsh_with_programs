#!/usr/bin/env bash
set -eo pipefail

reset="\033[0m"

red="\033[0;31m"
green="\033[0;32m"
white="\033[0;37m"
tan="\033[0;33m"

info() { printf "${white}➜ %s${reset}\n" "$@"
}
success() { printf "${green}✔ %s${reset}\n" "$@"
}
error() { >&2 printf "${red}✖ %s${reset}\n" "$@"
}
warn() { printf "${tan}➜ %s${reset}\n" "$@"
}

info_tips () {
    warn "INFO"
    echo -e "
    This script will install zsh, oh-my-zsh framework for zsh, powerlevel10k theme for zsh, additional plugins for zsh
    (zsh syntax highlightning, zsh-autosuggestions) and modern apps to replacing default built-in distributive apps
    (btop dust duf bat micro lsd gdu fd)."
    warn "PROXY"
    echo -e "If we need to use proxy to install - you must declare HTTP_PROXY env variable before run script:

        export HTTP_PROXY=ip:port"
    echo -e "
    script will try to install as much modern apps that script will find in repository of current distro.
    if some of apps will not found - remove aliases for that apps from end of ~/.zshrc file or install it mannualy
    Otherwise original apps will not work anymore!
    example .zshrc:
        alias htop=\"btop\"
        alias du=\"dust\"
        alias df=\"duf\" <-- remove this line if duf not found and you not install it mannualy
        alias cat=\"bat -pp -P\"
        alias nano=\"micro\"
        alias ls=\"lsd\"
        alias ncdu=\"gdu\""

    error "IMPORTANT:"
    info "You must enable fonts in your terminal"
    info "See here: https://github.com/romkatv/powerlevel10k#fonts <---"

    sleep 10
}

termux_install () {
    # in termux virtualenv we can`t use sudo.
    # so, we`ll download script, removing all sudo enters and re-run new script
        if [ -n "$TERMUX_VERSION" ]; then
            if [ -n "$TERMUX_PATCH" ]; then
                true
            else
                wget -O ./script.sh https://raw.githubusercontent.com/deathmond1987/homework/main/zsh_home_install.sh
                sed -i 's|sudo -E ||g' ./script.sh
                sed -i 's|sudo||g' ./script.sh
                chmod 755 ./script.sh
                export TERMUX_PATCH=true
                exec ./script.sh
            fi
        fi
}

alpine_install () {
    # check file os-release exist. that file not exist in that path in termux at least
    if [ -f "/etc/os-release" ]; then
    . /etc/os-release
        if [ "$ID" = "alpine" ]; then
            if [ "$ALPINE_PATCH" = "true" ]; then
                true
            else
                # getting raw script
                wget -O ./script.sh https://raw.githubusercontent.com/deathmond1987/homework/main/zsh_home_install.sh
                # ash not known about bash arrays. patching to line
                sed -i 's|APPS=( "btop" "dust" "duf" "bat" "micro" "lsd" "gdu" "fd" )||g' ./script.sh
                sed -i "s|    for apps in.*do|    for apps in btop dust duf bat micro lsd gdu fd; do|g" ./script.sh
                chmod 755 ./script.sh
                # export variable to stop cycle
                export ALPINE_PATCH=true
                # exec from ash to supress bash shebang in script
                ash ./script.sh
                exit 0
            fi
        fi
    fi
}
alpine_install

alert_root () {
    # check interactive shell
    if  [ "$(tty)" != "not a tty" ]; then
        # aware user about installing zsh to root
        if [ "$(id -u)" -eq 0 ]; then
            read -rp "You want install oh-my-zsh to root user? yes(y)/no(n): " ANSWER
            case $ANSWER in
                yes|y) warn "Oh-my-zsh will be installed in $HOME"
                    ;;
                no|n) warn "OK. If you want install zsh for your user - re-run this script from your user without sudo"
                    ;;
                    *) error "Unrecognised option"
                       alert_root
                    ;;
            esac
        fi
    else
        warn "zsh will be installed in $HOME !"
    fi
}

install_git_zsh () {
    # search package manager and config it to use proxy if HTTP_PROXY is not null. after this - installing needed packages
    if command -v dnf > /dev/null ; then
        success "dnf package manager found. installing zsh..."
        if [ -n "$HTTP_PROXY" ]; then
            echo "proxy=$HTTP_PROXY" | sudo tee -a /etc/dnf/dnf.conf
        fi
        pm="dnf install -y"
        sudo $pm git zsh curl -y
        sudo $pm install epel-release -y || true
    elif command -v apt > /dev/null ; then
        success "apt package manager found. installing zsh..."
        if [ -n "$HTTP_PROXY" ]; then
            echo "Acquire::http::Proxy \"http://$HTTP_PROXY\";" | sudo tee -a /etc/apt/apt.conf.d/proxy
        fi
        pm="apt install -y"
        sudo $pm git zsh curl
    elif command -v pacman > /dev/null ; then
        success "pacman package manager found. installing zsh..."
        http_proxy="$HTTP_PROXY"
        pm="pacman -S --noconfirm --needed"
        sudo $pm git zsh curl
    elif command -v zypper > /dev/null ; then
        success "zypper package manager found. installing zsh..."
        pm="zypper install -y"
        sudo $pm git zsh curl
    elif command -v apk > /dev/null ; then
        success "apk package manager found. installing zsh..."
        if [ -n "$HTTP_PROXY" ]; then
            # shellcheck disable=SC2034
            http_proxy=http://"$HTTP_PROXY"
            # shellcheck disable=SC2034
            https_proxy=http://"$HTTP_PROXY"
        fi
        pm="apk add"
        sudo -E $pm git zsh sudo shadow curl
    else
        error "Package manager not known"
        exit 1
    fi
    success "Dependencies of oh-my-zsh installed"
}

config_proxy_oh_my_zsh () {
    # if HTTP_PROXY is not null we must config git to use proxy and then install oh-my-zsh
    if [ -n "$HTTP_PROXY" ]; then
        warn "HTTP_PROXY found. Configuring proxy for git"
        #config git with proxy
        git config --global http.proxy http://"$HTTP_PROXY"
        git config --global http.proxyAuthMethod 'basic'
        git config --global http.sslVerify false
        # get oh-my-zsh
        warn "Installing oh-my-zsh"
        zsh -c "$(curl -fsSL -x "$HTTP_PROXY" https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        # since we in proxy default install of gitstatusd not working. disable download
        echo "POWERLEVEL9K_DISABLE_GITSTATUS=true" >> ~/.zshrc
        success "Done"
    else
        warn "Installing oh-my-zsh"
        zsh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        success "Done"
    fi
    ## change default zsh compilation dump to .config/zsh to avoid create compdump files in home dir
    sed -i '1 i\export ZDOTDIR=$HOME/.config/zsh' "$HOME"/.zshrc
    mkdir -p "$HOME"/.config/zsh
}

install_plugins () {
    warn "Installing and enabling plugins (autosuggestions, syntax-highlighting)"
    # get zsh syntax highlightning plugin
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    # get zsh autosuggections plugin
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    # enabling plugins in .zshrc config file
    sed -i 's/plugins=(git)/plugins=(docker docker-compose systemd git zsh-autosuggestions zsh-syntax-highlighting sudo zsh-navigation-tools)/g' $HOME/.zshrc
    success "Done"
}

install_powerlevel () {
    warn "Installing powerlevel10k theme for zsh"
    # get powerlevel10k theme for zsh
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
    # enable powerlevel10k theme in zsh config
    sed -i 's:ZSH_THEME="robbyrussell":ZSH_THEME="powerlevel10k/powerlevel10k":g' "$HOME"/.zshrc
    success "Done"
}

fix_zsh_docker () {
    warn "fix docker exec -it autocomplete"
    info "by default zsh completions for docker not working after inputting arguments. so, docker exec -ti not shows container names. fixing"
    # enabling stacking options for docker suggections. need to docker -it working with autosuggections
    echo -e "zstyle ':completion:*:*:docker:*' option-stacking yes\nzstyle ':completion:*:*:docker-*:*' option-stacking yes" >> "$HOME"/.zshrc
    success "Done"
}

change_shell () {
    # changing default shell
    warn "Changing default shell"
    if [ ! -z "$TERMUX_VERSION" ]; then
            chsh -s "$(command -v zsh)"
    else
        SUDO_USER=$(whoami)
        export SUDO_USER
        sudo -E usermod -s "$(command -v zsh)" "$SUDO_USER"
    fi
    success "Done"
}

linux_2023 () {
# now we trying to install additional modern unix programs
# in arch all apps in aur. we need to change pacman to aur helper
if [[ "$pm" == pacman* ]]; then
    # shellcheck disable=SC2089
    pm="yay -S --answerdiff None --answerclean None --noconfirm --mflags \"--noconfirm\""
fi

# app list
APPS=( "btop" "dust" "duf" "bat" "micro" "lsd" "gdu" "fd" )

warn "Installing modern apps"
# setting aliases. if program not found in repo - we ll remove alias
echo -e 'alias htop="btop"
alias du="dust"
alias df="duf"
alias cat="bat -pp -P"
alias nano="micro"
alias ls="lsd"
alias ncdu="gdu"' >> "$HOME"/.zshrc
    # installing apps
    for apps in "${APPS[@]}"; do
        INSTALL=failed
        if command -v "$apps" > /dev/null ; then
            success "$apps found. Nothing to do" && INSTALL=true
        else
            # shellcheck disable=SC2090
            $pm "$apps" && success "$apps found and installed" && INSTALL=true
        fi

        #if program not found in default repo - than we can at least give link to program github homepages
        if [ "$INSTALL" = "failed" ]; then
            error "$apps not found in repo"
            if [ "$apps" = "btop" ]; then
                if [ "$TERMUX_PATCH" = "true" ]; then
                    info "btop not working in termux due /proc/stat restricted on android"
                    sed -i '/[alias htop="btop"]/d' "$HOME"/.zshrc
                else
                    info "Install $apps manually from: https://github.com/aristocratos/btop/releases"
                    sed -i '/[alias htop="btop"]/d' "$HOME"/.zshrc
                fi
            elif [ "$apps" = "dust" ]; then
                info "Install $apps manually from: https://github.com/bootandy/dust/releases"
                sed -i '/[alias du="dust"]/d' "$HOME"/.zshrc
            elif [ "$apps" = "duf" ]; then
                info "Install $apps manually from: https://github.com/muesli/duf/releases"
                sed -i '/[alias df="duf"]/d' "$HOME"/.zshrc
            elif [ "$apps" = "bat" ]; then
                info "Install $apps manually from: https://github.com/sharkdp/bat/releases"
                sed -i '/[alias cat="bat -pp -P"]/d' "$HOME"/.zshrc
            elif [ "$apps" = "micro" ]; then
                info "Install $apps manually from: https://github.com/zyedidia/micro/releases"
                sed -i '/[alias nano="micro"]/d' "$HOME"/.zshrc
            elif [ "$apps" = "lsd" ]; then
                info "Install $apps manually from: https://github.com/lsd-rs/lsd/releases"
                sed -i '/[alias ls="lsd"]/d' "$HOME"/.zshrc
            elif [ "$apps" = "gdu" ]; then
                info "Install $apps manually from: https://github.com/dundee/gdu/releases"
                sed -i '/[alias ncdu="gdu"]/d' "$HOME"/.zshrc
            fi
        fi
    done
}

drop_proxy_config_git () {
    # cleanup git config if HTTP_PROXY was configured
    if [ -n "$HTTP_PROXY" ]; then
        warn "Removeing git proxy config"
        git config --global --unset http.proxy || true
        git config --global --unset http.proxyAuthMethod || true
        git config --global --unset http.sslVerify || true
        success "Done"
    fi
}

drop_proxy_pkg_manager_conf () {
if [ -n "$HTTP_PROXY" ]; then
    warn "Removing package manager proxy config"
    if command -v dnf > /dev/null ; then
        sudo sed -i "s/proxy=$HTTP_PROXY//g" tee -a /etc/dnf/dnf.conf
    elif command -v apt-get > /dev/null ; then
        sudo rm /etc/apt/apt.conf.d/proxy
    elif command -v pacman > /dev/null ; then
        true
    elif command -v zypper > /dev/null ; then
        true
    elif command -v apk > /dev/null ; then
        true
    else
        error "Package manager not known"
        exit 1
    fi
    success "Done"
fi
}

on_exit () {
    unset ZSH_SCRIPT_INFO
    unset TERMUX_PATCH
    unset ALPINE_PATCH
    echo ""
    warn "In next login to shell you need to answer few questions to configure powerlevel10k theme."
    warn "But before that you must configure your terminal fonts."
    success "Installing complete!"
}

main () {
#    info_tips
    termux_install
    alert_root
    install_git_zsh
    drop_proxy_config_git
    config_proxy_oh_my_zsh
    install_plugins
    install_powerlevel
    fix_zsh_docker
    change_shell
    linux_2023
    drop_proxy_config_git
    drop_proxy_pkg_manager_conf
    on_exit
}

main "$@"
