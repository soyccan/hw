#!/bin/sh

if [ -z "$1" ]; then
    echo "Usage: $0 accounts_file"
    exit 1
fi

maxuid=-1
uidlist=''
while read line; do
    uid=`echo $line | cut -d : -f 3`
    echo uid:$uid
    uidlist="$uidlist $uid"
    if [ "$uid" -gt "$maxuid" ]; then
        maxuid="$uid"
    fi
done < /var/yp/master.passwd

if [ $maxuid != -1 ]; then
    maxuid="$(( $maxuid + 1 ))"
    echo maxuid: $maxuid, uidlist: [$uidlist]
    while read line; do
        user=`echo $line | cut -d , -f 1`
        fullname=`echo $line | cut -d , -f 2`
        password=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10`
        homedir=/net/home/$user
        mkdir $homedir
        cp /.cshrc $homedir
        echo Adding user=$user fullname=$fullname uid=$maxuid password=$password homedir=$homedir
        if [ "$uidlist" != *"$maxuid"* ]; then # if uidlist contains maxuid
            echo "$user::$maxuid:2001::0:0:$fullname (automatically created account):$homedir:/bin/tcsh" >> /var/yp/master.passwd
            make -C /var/yp
            chsh -s /bin/tcsh $user
            echo $password | pw usermod $user -h 0 
        fi
    done < "$1"
fi
