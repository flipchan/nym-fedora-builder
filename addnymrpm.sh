sudo rpm --import https://fedora.laissez-faire.trade/RPM-GPG-KEY-nym

sudo tee /etc/yum.repos.d/nym-vpn.repo <<'EOF'
[nym-vpn-stable]
name=Nym VPN Stable Repository
baseurl=https://fedora.laissez-faire.trade/fedora/$releasever/$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-nym
EOF

sudo dnf update
sudo dnf install nym-vpnd
echo " You have now installed nym-vpnd on fedora! Enable it by: sudo systemctl enable nym-vpnd"
