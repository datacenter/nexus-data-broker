Certified Redhat versions: Redhat 7.5, Redhat 7.7

Certified NDB Versions: NDB 3.10.1

Steps to deploy the service startup script
------------------------------------------

1. How to get a file form git hub
    i)  Download git to clone repository - sudo yum install git
    ii) git --version ( check for the version after successfull installation)
    iii) git clone https://github.com/datacenter/nexus-data-broker.git

2.Move to "nexusdatabroker/serviceScripts/redhat" directory
    Edit the following lines in the ndb script.
    NDB_PATH - Update the location of the NDB
    for example: If the NDB is extracted under /home/user, then update path as /home/user/xnc

3. Copy ndb script to "/etc/init.d" directory. Change the permissions to 755 with command "chmod 755 ndb"

4. Run with the following command to make ndb as a service even after crash/reboot
   chkconfig --level 35 ndb on

5. Start/stop the NDB using the below command.


service ndb start/stop/status/restart
The options:-

    start   -- Starts the process.

    stop    -- Stops the process.

    status  -- Displays whether the process is running or not and its process id.

    restart -- Stops and starts the process.
