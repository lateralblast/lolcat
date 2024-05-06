![Cat laughing](https://raw.githubusercontent.com/lateralblast/lolcat/master/lolcat.jpg)

LOLCAT
------

LOM/OOB Letsencrypt Certificate Automation Tool

Version
-------

Current Version: 0.1.6

Prerequisites
-------------

The following tools are required for getting Let's Encrypt certiicates:

- [lego](https://go-acme.github.io/lego/)

The following tools are required for iDRAC support:

- racadm or 
- [dracadm](https://github.com/lateralblast/dracadm) (dockerised racadm)

Introduction
------------

This scipt is designed to generate letsencrpyt certificates for LOM/OOB devices such as iDRAC and install them. It is designed to handle special circumstances like iDRAC requiring 2048 bit keys/certs.

Currently this script has support for iDRACs and Gandi, but can easily be expanded to use other providers as it uses lego.

If you are using this script for iDRACs, racadm is required. If you are using this script on a platform that does not support racadm, e.g. MacOS, you can run it in a docker container using [dracadm](https://github.com/lateralblast/dracadm)

Features
--------

If domain is specified with upload action and SSL cert/key files are not specified,
the script will try to determine the filename for the SSL cert/key files.

Usage
-----

You can get help using the -h or --help switch:

```
./lolcat.sh --help

  Usage: lolcat.sh [OPTIONS...]

    --help        Help/Usage information
    --usage       Print usage information
    --version     Print version information            
    --domain(s)   Domain to generate certificate for
    --dns         DNS provider (default: gandiv5)
    --email       Email address
    --apikey      API Key for DNS Provider
    --token       API Key for DNS Provider
    --action      Perform action (e.g. create)
    --option(s)   Options (e.g. wildcard)
    --oobhost     OOB device hostname/IP
    --oobtype     OOB device type (default: idrac)
    --oobuser     OOB device user (default: root)
    --oobpass     OOB device pass (default: calvin)
    --keytype     Key type (default: rsa2048)
    --keypath     Key path (default: /var/snap/lego/common/.lego/certificates)
    --sslkey      SSL key file to upload to OOB device
    --sslcert     SSL cert file to uploard to OOB device

  Options:

    verbose       Verbose output (default: false)
    wildcard      Wildcard domain (default: false)
    nowildcard    Wildcard domain (default: false)
    testmode      Run in test mode (default: false)  

```

Examples
--------

Create Let's Encrypt SSL cert for domain blah.com using defaults:

```
./lolcat.sh --action create --email admin@blah.com --domain blah.com --token XXXXXXXXXXX --options verbose
Information: Setting verbose to true
Information: Setting key type to rsa2048
Information: Setting DNS provider to gandiv5
Information: Setting key path to /var/snap/lego/common/.lego/certificates
Executing:   GANDIV5_PERSONAL_ACCESS_TOKEN=XXXXXXXXXXX ; /snap/bin/lego --email admin@blah.com --dns gandiv5 --domains "*.blah.com" --key-type rsa2048 run
```

Deploy/upload SSL certs to iDRAC using defaults:

```
./lolcat.sh --action upload --oobhost 192.168.1.2 --options verbose --domain blah.com
Information: Setting verbose to true
Information: Setting key path to /var/snap/lego/common/.lego/certificates
Information: Setting OOB type to idrac
Information: Setting OOB user to root
Information: Setting OOB user to calvin
Information: Setting SSL key to /var/snap/lego/common/.lego/certificates/_.*.blah.com.key
Information: Setting SSL cert to /var/snap/lego/common/.lego/certificates/_.*.blah.com.crt
Information: Found /usr/bin/racadm
Executing:   /usr/bin/racadm -r 192.168.1.2 -u root -p calvin -i sslkeyupload -t 1 -f /var/snap/lego/common/.lego/certificates/_.*.blah.com.key
Executing:   /usr/bin/racadm -r 192.168.1.2 -u root -p calvin -i sslcertupload -t 1 -f /var/snap/lego/common/.lego/certificates/_.*.blah.com.crt
Executing:   /usr/bin/racadm -r 192.168.1.2 -u root -p calvin racreset
```
