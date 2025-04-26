#!/bin/bash

if ! grep -q "arch" /etc/os-release; then
    echo ":: This script is designed to run on Arch Linux."
    exit 1
fi

if [ ! -d "$HOME/dotfiles" ]; then
    echo ":: The directory $HOME/dotfiles does not exist."
    exit 1
fi

execute_command() {
    sudo -u blend BUILDDIR=/root/build
    }
 
 install_yay() {
     echo ":: Installing yay..."
     execute_command sudo pacman -Sy
     execute_command sudo pacman -S --needed --noconfirm base-devel git
     execute_command git clone https://aur.archlinux.org/yay.git /tmp/yay
     cd /tmp/yay
     execute_command makepkg -si --noconfirm --needed
 }
 
 install_microtex() {
     cd ~/dotfiles/setup/MicroTex/
     execute_command makepkg -si
 }
 
 install_agsv1() {
     cd ~/dotfiles/setup/agsv1/
     execute_command makepkg -si
 }

install_aur_package() {
    local pkg_name=$1
    echo ":: Installing package: $pkg_name"
    
    # Create temp directory
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || exit 1
    
    # Download PKGBUILD (try AUR first, then official repos)
    if ! curl -s "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=$pkg_name" -o PKGBUILD; then
        # Fallback to official repos if AUR fails
        if ! asp export "$pkg_name"; then
            echo "!! Failed to find package: $pkg_name"
            rm -rf "$temp_dir"
            return 1
        fi
        cd "$pkg_name" || exit 1
    fi
    
    # Build and install
    execute_command makepkg -si --noconfirm --needed
    cd ..
    rm -rf "$temp_dir"
}

install_microtex() {
    cd ~/dotfiles/setup/MicroTex/ || exit 1
    execute_command makepkg -si
}

install_agsv1() {
    cd ~/dotfiles/setup/agsv1/ || exit 1
    execute_command makepkg -si
}

install_packages() {
    echo ":: Installing packages"
    
    # First install asp for getting official PKGBUILDs
    install_aur_package asp
    
    # Install all packages using makepkg
    local packages=(
        hyprland hyprshot hyprcursor hypridle hyprlang hyprpaper hyprpicker hyprlock
        hyprutils hyprwayland-scanner xdg-dbus-proxy xdg-desktop-portal
        xdg-desktop-portal-gtk xdg-desktop-portal-hyprland xdg-user-dirs
        xdg-utils libxdg-basedir python-pyxdg swww gtk3 gtk4
        adw-gtk-theme libdbusmenu-gtk3 python-pip python-pillow sddm
        nm-connection-editor network-manager-applet
        networkmanager gnome-bluetooth-3.0 wl-gammarelay-rs bluez bluez-libs bluez-utils
        cliphist wl-clipboard libadwaita swappy nwg-look
        pavucontrol polkit-gnome brightnessctl man-pages gvfs xarchiver zip imagemagick
        blueman fastfetch bibata-cursor-theme python-pywayland dbus
        libdrm mesa fwupd bun-bin pipewire wireplumber udiskie
        lm_sensors gnome-system-monitor playerctl ttf-meslo-nerd ttf-google-sans
        ttf-font-awesome ttf-opensans ttf-roboto lshw
        fontconfig dart-sass ttf-meslo-nerd-font-powerlevel10k cpio meson cmake
        python-materialyoucolor-git gtksourceview3 gtksourceviewmm cairomm
        gtkmm3 tinyxml2 python-requests python-numpy
        sddm-theme-corners-git ttf-material-symbols-variable-git
    )
    
    for pkg in "${packages[@]}"; do
        install_aur_package "$pkg"
    done
    
    install_agsv1
}

setup_sensors() {
    execute_command sudo sensors-detect --auto >/dev/null
}

check_config_folders() {
    local CHECK_CONFIG_FOLDERS="ags alacritty hypr swappy"
    local DATETIME=$(date '+%Y-%m-%d %H:%M:%S')
    local EXISTING="NO"

    mkdir -p "$HOME/.backup/$DATETIME/"

    for dir in $CHECK_CONFIG_FOLDERS; do
        if [ -d "$HOME/.config/$dir" ]; then
            echo ":: Backing up existing $dir config..."
            mv "$HOME/.config/$dir" "$HOME/.backup/$DATETIME/"
            EXISTING="YES"
        fi
    done

    if [[ $EXISTING == "YES" ]]; then
        echo ":: Old config folder(s) backed up to ~/.backup/$DATETIME/"
    fi
}

install_icon_theme() {
    echo ":: Installing Tela icons (default: nord)..."
    mkdir -p /tmp/install
    cd /tmp/install
    git clone https://github.com/vinceliuice/Tela-icon-theme
    cd Tela-icon-theme
    ./install.sh nord
    echo -e "Tela-nord-dark\nTela-nord-light" >"$HOME/dotfiles/.settings/icon-theme"
    cd "$HOME/dotfiles"
}

setup_colors() {
    echo ":: Setting colors (default: blue)..."
    execute_command python -O "$HOME/dotfiles/material-colors/generate.py" --color "#0000FF"
}


copy_files() {
    echo ":: Copying files..."
    mkdir -p "$HOME/.config"
    "$HOME/dotfiles/setup/copy.sh"
    if [ ! -d "$HOME/wallpaper" ]; then
        cp -r "$HOME/dotfiles/wallpapers" "$HOME/wallpaper"
    fi
}

create_links() {
    echo ":: Creating symlinks..."
    ln -f "$HOME/dotfiles/electron-flags.conf" "$HOME/.config/electron-flags.conf"
    ln -sf "$HOME/dotfiles/ags" "$HOME/.config/ags"
    ln -sf "$HOME/dotfiles/alacritty" "$HOME/.config/alacritty"
    ln -sf "$HOME/dotfiles/hypr" "$HOME/.config/hypr"
    ln -sf "$HOME/dotfiles/swappy" "$HOME/.config/swappy"
}

remove_gtk_buttons() {
    echo ":: Removing GTK window buttons..."
    gsettings set org.gnome.desktop.wm.preferences button-layout ':'
}

setup_services() {
    echo ":: Enabling services..."
    sudo systemctl enable --now bluetooth.service
    sudo systemctl enable --now NetworkManager.service
}

update_user_dirs() {
    echo ":: Updating user directories..."
    xdg-user-dirs-update
}

misc_tasks() {
    echo ":: Running final tasks..."
    hyprctl reload
    agsv1 --init
    execute_command python "$HOME/dotfiles/hypr/scripts/wallpaper.py" -R
}

main() {
    if [[ $1 == "packages" ]]; then
        install_packages
        exit 0
    fi

    install_packages
    install_microtex
    setup_sensors
    check_config_folders
    install_icon_theme
    #setup_sddm
    copy_files
    create_links
    setup_colors
    remove_gtk_buttons
    setup_services
    update_user_dirs
    misc_tasks

    echo ":: All done! Please restart your PC."
}

main "$@"
