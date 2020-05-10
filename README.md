# onpremdistributed

Before you run this, you must prepare your machines

- Host1 => Main Install

- Host2 => filler

- Host3 => appdata-processor


As root 

- Step 1
Create a ssh key on Host1 (if your don't have one already) using: 
  ssh-keygen -t rsa -C "root@host1" (might not be super secured but I'm no security expert)
  
Add content of /root/.ssh/id_rsa.pub in file /root/.ssh/authorized_keys on Host2 and Host3

- Step 2
From Host1, install the Instana as single box

- Step 3
Form Host1, run /root/prepare_multihost.sh



