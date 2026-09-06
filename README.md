# nym-fedora-builder
Builds fedora .rpm packages for [nym-vpn](https://github.com/nymtech/nym-vpn-client)   



## Prep:   
```shell
sudo dnf install -y rpm-build createrepo_c curl git
```

## Install nym package repo and nym-vpnd package on fedora oneliner:
`curl -sSL https://raw.githubusercontent.com/flipchan/nym-fedora-builder/refs/heads/main/addnymrpm.sh | sudo bash`

## Build the latest stable nym package for fedora:  
```shell
./deploy-repo.sh  
```


### Auto updates:   
Use the cronjob in this folder to run it once a day.   



## Try live and use with fedora now:  
https://fedora.laissez-faire.trade/   
