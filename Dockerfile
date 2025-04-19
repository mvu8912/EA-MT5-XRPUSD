FROM dorowu/ubuntu-desktop-lxde-vnc:latest

# Add Google Chrome repository GPG key
RUN curl -s https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
RUN echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list

# Install tools for repository management
RUN apt-get update && apt-get install -y curl gnupg lsb-release desktop-file-utils

# Add Microsoft repository for VSCode (example)
RUN curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg \
    && install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/ \
    && echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list

# Add Docker repository (example)
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

# Update and install packages, then clean up
RUN apt-get update \
    && apt-get install -y google-chrome-stable code docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Remove temporary files
RUN rm -f microsoft.gpg

# Create a desktop file for VSCode to register it as a protocol handler
RUN echo '[Desktop Entry]\n\
Type=Application\n\
Name=Visual Studio Code\n\
Exec=/usr/share/code/code --no-sandbox %U\n\
Icon=code\n\
Terminal=false\n\
MimeType=x-scheme-handler/vscode; \n\
Categories=Development; IDE; \n' > /usr/share/applications/code.desktop \
&& update-desktop-database

RUN groupadd -g 140 docker
