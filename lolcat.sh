#!/usr/bin/env bash

# Name:         lolcat (LOM/OOB Letsencrypt Certificate Automation Tool)
# Version:      0.1.6
# Release:      1
# License:      CC-BA (Creative Commons By Attribution)
#               http://creativecommons.org/licenses/by/4.0/legalcode
# Group:        System
# Source:       N/A
# URL:          http://lateralblast.com.au/
# Distribution: Linux
# Vendor:       UNIX
# Packager:     Richard Spindler <richard@lateralblast.com.au>
# Description:  Shell script designed to simplify creation of letsencrypt SSL certificates for LOM/OOB devices

# shellcheck disable=SC2129

SCRIPT_ARGS="$*"
SCRIPT_FILE="$0"
SCRIPT_NAME="lolcat"
START_PATH=$( pwd )
SCRIPT_BIN=$( basename "$0" |sed "s/^\.\///g")
SCRIPT_FILE="$START_PATH/$SCRIPT_BIN"
SCRIPT_VERSION=$( grep '^# Version' < "$0" | awk '{print $3}' )
USER_NAME=$(whoami)
OS_NAME=$(uname)

# Defaults

DEFAULT_DNS="gandiv5"
DEFAULT_KEY_TYPE="rsa2048"
DEFAULT_OOB_TYPE="idrac"
DEFAULT_OOB_USER="root"
DEFAULT_OOB_PASS="calvin"
DEFAULT_KEY_PATH="$HOME/.lego"
RACADM_VERSION="11010"
RACADM_BIN="racadm"
LEGO_BIN="lego"
UBUNTU_CODENAME="jammy"
DO_WILDCARD="true"
DO_NOWILDCARD="false"
DO_TESTMODE="false"
DO_VERBOSE="false"

if [ "$OS_NAME" = "Linux" ]; then
  if [ "$(command -v lsb_release)" ]; then
    OS_DIST=$(lsb_release -is 2> /dev/null)
    if [ "$OS_DIST" = "Ubuntu" ]; then
      COMMON_GROUP="adm"
      COMMON_DIR="/var/snap/lego/common/.lego"
      DEFAULT_KEY_PATH="$COMMON_DIR/certificates"
    fi
  fi
else
  if [ "$OS_NAME" = "Darwin" ]; then
    OS_DIST=$(sw_vers --productName)
  fi
fi

# Function: print_cli_help
#
# Print script help information

print_cli_help () {
  cat <<-HELP

  Usage: ${0##*/} [OPTIONS...]

    --help        Help/Usage information
    --usage       Print usage information
    --version     Print version information            
    --domain(s)   Domain to generate certificate for
    --dns         DNS provider (default: $DEFAULT_DNS)
    --email       Email address
    --apikey      API Key for DNS Provider
    --token       API Key for DNS Provider
    --action      Perform action (e.g. create)
    --option(s)   Options (e.g. wildcard, verbose, testmode)
    --oobhost     OOB device hostname/IP
    --oobtype     OOB device type (default: $DEFAULT_OOB_TYPE)
    --oobuser     OOB device user (default: $DEFAULT_OOB_USER)
    --oobpass     OOB device pass (default: $DEFAULT_OOB_PASS)
    --keytype     Key type (default: $DEFAULT_KEY_TYPE)
    --keypath     Key path (default: $DEFAULT_KEY_PATH)
    --sslkey      SSL key file to upload to OOB device
    --sslcert     SSL cert file to uploard to OOB device

  Options:

    verbose       Verbose output (default: $DO_VERBOSE)
    wildcard      Wildcard domain (default: $DO_WILDCARD)
    nowildcard    Wildcard domain (default: $DO_NOWILDCARD)
    testmode      Run in test mode (default: $DO_TESTMODE)          

HELP
  exit
}

# Function: print_help
#
# Print help

print_help () {
  case "$1" in
    "cli")
      print_cli_help
      ;;
    *)
      print_cli_help
      ;;
  esac
}

print_cli_usage () {
  cat <<-USAGE

  Examples
  ========

  Create Let's Encrypt SSL cert for domain blah.com using defaults:

  ./lolcat.sh --action create --domain blah.com --token XXXXXXXXXXX --options verbose
  Information: Setting verbose to true
  Information: Setting key type to rsa2048
  Information: Setting DNS provider to gandiv5
  Information: Setting key path to /var/snap/lego/common/.lego/certificates
  Executing:   GANDIV5_PERSONAL_ACCESS_TOKEN=XXXXXXXXXXX ; /snap/bin/lego --email admin@blah.com --dns gandiv5 --domains "*.blah.com" --key-type rsa2048 run

  Deploy/upload SSL certs to iDRAC using defaults:

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

USAGE
  exit  
}

# Function: print_usage
#
# Print usage

print_usage () {
  case "$1" in
    "cli")
      print_cli_usage
      ;;
    *)
      print_cli_usage
      ;;
  esac
}

# Function: warning_message
#
# Output warning and exit

warning_message () {
  WARNING="$1"
  FUNCTION="$2"
  echo "Warning:     $WARNING"
  if [ "$FUNCTION" = "EXIT" ]; then
    exit
  else
    if [ "$FUNCTION" = "TEST" ]; then
      if [ "$DO_TESTMODE" = "false" ]; then
        exit
      fi
    fi
  fi
}

# Function: info_message
#
# Informational message

info_message () {
  MESSAGE="$1"
  echo "Information: $MESSAGE"
}

# Function: verbose_message
#
# Verbose output

verbose_message () {
  MESSAGE="$1"
  if [ "$DO_VERBOSE" = "true" ]; then
    echo "Information: $MESSAGE"
  fi
}

# Function: command_message
#
# Execute command

command_message () {
  COMMAND="$1"
  if [ "$DO_TESTMODE" = "true" ]; then
    echo "Command:     $COMMAND"
  else
    if [ "$DO_VERBOSE" = "true" ]; then
      echo "Executing:   $COMMAND"
    fi
  fi
}

# Function: check_environment
#
# Check environment

check_environment () {
  if [ -z "$(command -v lego)" ]; then
    if [ "$OS_NAME" = "Darwin" ]; then
      if [ "$(command -v brew)" ]; then
        info_message "Installing lego"
        brew install lego
      fi
    else
      if [ "$(command -v lsb_release)" ]; then
        OS_DIST=$(lsb_release -is 2> /dev/null)
        if [ "$OS_DIST" = "Ubuntu" ]; then
          info_message "Installing lego"
          sudo snap install lego
          if [ ! -d "$COMMON_DIR" ]; then
            sudo mkdir "$COMMON_DIR"
            sudo chown root:$COMMON_GROUP "$COMMON_DIR"
            sudo chmod g+w "$COMMON_DIR"
          fi
        fi
      fi
    fi
  fi
  if [ "$OOB_TYPE" = "idrac" ]; then
    if [ -z "$(command -v racadm)" ]; then
      if [ "$OS_NAME" = "Linux" ]; then
        if [ -f "/opt/dell/srvadmin/sbin/racadm" ]; then
          RACADM_BIN="/opt/dell/srvadmin/sbin/racadm"
        else
          warning_message "racadm not installed" "EXIT"
        fi
      fi
    else
      RACADM_BIN=$(which racadm)
    fi
    if [ -z "$(command -v racadm)" ]; then
      warning_message "racadm not installed" "EXIT"
    else
      verbose_message "Found $RACADM_BIN"
    fi
  fi
  if [ -z "$(command -v lego)" ]; then
    warning_message "lego not installed" "EXIT"
  else
    LEGO_BIN=$(which lego)
  fi
  if [ "$OS_NAME" = "Linux" ]; then
    if [ ! -d "$KEY_PATH" ]; then
      command_message "mkdir -p $KEY_PATH"
      command_message "sudo chown $USER_NAME.$USER_NAME $KEY_PATH"
      mkdir -p $KEY_PATH
      sudo chown $USER_NAME.$USER_NAME $KEY_PATH
    fi
  fi
}

# Function: process_defaults
#
# Process defaults

process_defaults () {
  if [ "$ACTION" = "create" ]; then
    if [ "$KEY_TYPE" = "" ]; then
      KEY_TYPE="$DEFAULT_KEY_TYPE"
    fi
    verbose_message "Setting key type to $KEY_TYPE"
    if [ "$DNS" = "" ]; then
      DNS="$DEFAULT_DNS"
    fi
    verbose_message "Setting DNS provider to $DNS"
    if [ "$DOMAIN" = "" ]; then
      warning_message "No keys or domain specified" "EXIT"
    fi
  fi
  if [ "$KEY_PATH" = "" ]; then
    KEY_PATH="$DEFAULT_KEY_PATH"
  fi
  verbose_message "Setting key path to $KEY_PATH"
  if [ "$ACTION" = "upload" ]; then
    if [ "$OOB_TYPE" = "" ]; then
      OOB_TYPE="$DEFAULT_OOB_TYPE"
    fi
    verbose_message "Setting OOB type to $OOB_TYPE"
    if [ "$OOB_USER" = "" ]; then
      OOB_USER="$DEFAULT_OOB_USER"
    fi
    verbose_message "Setting OOB user to $OOB_USER"
    if [ "$OOB_PASS" = "" ]; then
      OOB_PASS="$DEFAULT_OOB_PASS"
    fi
    verbose_message "Setting OOB user to $OOB_PASS"
    if [ "$SSL_KEY" = "" ] && [ "$SSL_CERT" = "" ]; then
      if [ "$DOMAIN" = "" ]; then
        warning_message "No keys or domain specified" "EXIT"
      fi
    fi
    if [ "$SSL_KEY" = "" ]; then
      if [ "$DO_WILDCARD" = "true" ]; then
        if [[ "$DOMAIN" =~ "*" ]]; then
          TEMP_DOMAIN=$(echo "$DOMAIN" |sed "s/\*/_/g")
          SSL_KEY="$KEY_PATH/$TEMP_DOMAIN.key"
        else
          SSL_KEY="$KEY_PATH/_.$DOMAIN.key"
        fi
      else
        if [[ "$DOMAIN" =~ "*" ]]; then
          DOMAIN=$(echo "$DOMAIN" |sed "s/\*/_/g")
        fi
        SSL_KEY="$KEY_PATH/$DOMAIN.key"
      fi
    fi
    if [ "$SSL_CERT" = "" ]; then
      if [ "$DO_WILDCARD" = "true" ]; then
        if [[ "$DOMAIN" =~ "*" ]]; then
          TEMP_DOMAIN=$(echo "$DOMAIN" |sed "s/\*/_/g")
          SSL_CERT="$KEY_PATH/$TEMP_DOMAIN.crt"
        else
          SSL_CERT="$KEY_PATH/_.$DOMAIN.crt"
        fi
      else
        if [[ "$DOMAIN" =~ "*" ]]; then
          DOMAIN=$(echo "$DOMAIN" |sed "s/\*/_/g")
        fi
        SSL_CERT="$KEY_PATH/$DOMAIN.crt"
      fi
    fi
    verbose_message "Setting SSL key to $SSL_KEY"
    if [ ! -f "$SSL_KEY" ]; then
      warning_message "File $SSL_KEY does not exist" TEST
    fi
    verbose_message "Setting SSL cert to $SSL_CERT"
    if [ ! -f "$SSL_CERT" ]; then
      warning_message "File $SSL_CERT does not exist" TEST
    fi
  fi
}

# Function: process_options
#
# Process option switchGANDIV5_PERSONAL_ACCESS_TOKEN=

process_options () {
  if [[ "$DOMAIN" =~ "*" ]] || [[ "$OPTION" =~ "wildcard" ]] || [ "$DO_WILDCARD" = "true" ]; then
    if [[ "$OPTION" =~ "nowildcard" ]]; then
      DO_WILDCARD="false"
    else
      DO_WILDCARD="true"
      if ! [[ "$DOMAIN" =~ "*" ]]; then
        DOMAIN="*.$DOMAIN"
      fi
    fi
  fi
  verbose_message "Setting wildcard to $DO_WILDCARD"
  if [[ "$OPTION" =~ "test" ]]; then
    DO_TESTMODE="true"
  fi
  verbose_message "Setting testmode to $DO_TESTMODE"
  if [[ "$OPTION" =~ "verbose" ]]; then
    DO_VERBOSE="true"
  fi
  verbose_message "Setting verbose to $DO_VERBOSE"
}

# Function: create_cert
#
# Create certificate

create_cert () {
  if [ -f "$TOKEN" ]; then
    TEMP=$(cat "$TOKEN")
    TOKEN="$TEMP"
  fi
  if [ "$TOKEN" = "" ]; then
    warning_message "No API key/token given" "EXIT"
  fi
  if [ "$EMAIL" = "" ]; then
    warning_message "No email address given" "EXIT"
  fi
  if [ "$DNS" = "gandiv5" ]; then
    if [ "$OS_NAME" = "Linux" ] && [ "$OS_DIST" = "Ubuntu" ]; then
      command_message "export GANDIV5_PERSONAL_ACCESS_TOKEN=$TOKEN ; $LEGO_BIN --email $EMAIL --dns $DNS --domains \"$DOMAIN\" --key-type $KEY_TYPE run"
      if [ "$DO_TESTMODE" = "false" ]; then
        export GANDIV5_PERSONAL_ACCESS_TOKEN=$TOKEN ; $LEGO_BIN --email $EMAIL --dns $DNS --domains "$DOMAIN" --key-type $KEY_TYPE run
      fi
    else
      command_message "export GANDIV5_PERSONAL_ACCESS_TOKEN=$TOKEN ; $LEGO_BIN --path $KEY_PATH --email $EMAIL --dns $DNS --domains \"$DOMAIN\" --key-type $KEY_TYPE run"
      if [ "$DO_TESTMODE" = "false" ]; then
        export GANDIV5_PERSONAL_ACCESS_TOKEN=$TOKEN ; $LEGO_BIN --path $KEY_PATH --email $EMAIL --dns $DNS --domains "$DOMAIN" --key-type $KEY_TYPE run
      fi
    fi
  fi
}

# Function: upload_idrac_cert
#
# Upload cert to iDRAC

upload_idrac_cert () {
  if [ "$DO_TESTMODE" = "true" ]; then
    command_message "$RACADM_BIN -r $OOB_HOST -u $OOB_USER -p $OOB_PASS sslkeyupload -t 1 -f $SSL_KEY"
    command_message "$RACADM_BIN -r $OOB_HOST -u $OOB_USER -p $OOB_PASS sslcertupload -t 1 -f $SSL_CERT"
    command_message "$RACADM_BIN -r $OOB_HOST -u $OOB_USER -p $OOB_PASS racreset"
  else
    if [ -f "$SSL_KEY" ]; then
      command_message "$RACADM_BIN -r $OOB_HOST -u $OOB_USER -p $OOB_PASS sslkeyupload -t 1 -f $SSL_KEY"
      cd $KEY_PATH ; $RACADM_BIN -r $OOB_HOST -u $OOB_USER -p $OOB_PASS sslkeyupload -t 1 -f $SSL_KEY
    else
      warning_message "SSL key file $SSL_KEY does not exist" "EXIT"
    fi
    if [ -f "$SSL_CERT" ]; then
      command_message "$RACADM_BIN -r $OOB_HOST -u $OOB_USER -p $OOB_PASS sslcertupload -t 1 -f $SSL_CERT"
      cd $KEY_PATH ; $RACADM_BIN -r $OOB_HOST -u $OOB_USER -p $OOB_PASS sslcertupload -t 1 -f $SSL_CERT
    else
      warning_message "SSL cert file $SSL_CERT does not exist" "EXIT"
    fi
    command_message "$RACADM_BIN -r $OOB_HOST -u $OOB_USER -p $OOB_PASS racreset"
    $RACADM_BIN -r $OOB_HOST -u $OOB_USER -p $OOB_PASS racreset
  fi
}

# Function: upload_cert
#
# Upload cert to OOB device

upload_cert () {
  if [ "$OOB_TYPE" = "idrac" ]; then
    upload_idrac_cert
  fi
}

# Function: process_actions
#
# Process action switch

process_actions () {
  case $ACTION in
  "help"|"printhelp")
      print_help
      ;;
    "usage"|"printusage"|"examples")
      print_usage
      ;;
    "create")
      create_cert
      ;;
    "upload")
      upload_cert
      ;;
    *)
      handle_output "Action: $ACTION is not a valid action"
      exit
      ;;
  esac
}

# Handle command line arguments

if [ "$SCRIPT_ARGS" = "" ]; then
  print_help
fi

while test $# -gt 0
do
  if [ "$1" = "-h" ]; then
    print_help "$2"
    exit
  fi
  if [ "$2" = "" ]; then
    if ! [[ "$1" =~ "version" ]] && ! [[ "$1" =~ "help" ]] && ! [[ "$1" =~ "usage" ]]; then
      warning_message "No $1 specified" "EXIT"
    fi
  fi
  case $1 in
    --action)
      ACTION="$2"
      shift 2
      ;;
    --option|--options)
      OPTION="$2"
      shift 2
      ;;
    --dns)
      DNS="$2"
      shift 2
      ;;
    --domains|--domain)
      DOMAIN="$2"
      shift 2
      ;;
    --email)
      EMAIL="$2"
      shift 2
      ;;
    --oobtype)
      OOB_TYPE="$2"
      shift 2
      ;;
    --oobhost)
      OOB_HOST="$2"
      shift 2
      ;;
    --oobuser)
      OOB_USER="$2"
      shift 2
      ;;
    --oobpass)
      OOB_PASS="$2"
      shift 2
      ;;
    --apikey|--token)
      TOKEN="$2"
      shift 2
      ;;
    --keytype)
      KEY_TYPE="$2"
      shift 2
      ;;
    --keypath)
      KEY_PATH="$2"
      shift 2
      ;;
    --help)
      print_help "cli"
      exit
      ;;
    --version)
      echo "$SCRIPT_VERSION"
      shift
      exit
      ;;
    --usage)
      print_usage "$2"
      exit
      ;;
    --)
      shift
      break
      ;;
    *)
      print_help "$2"
      exit
      ;;
  esac
done

if [ "$DNS" = "" ]; then
  DNS="$DEFAULT_DNS"
fi

if [ "$SIZE" = "" ]; then
  SIZE="$DEFAULT_SIZE"
fi

if [ "$TYPE" = "" ]; then
  TYPE="$DEFAULT_TYPE"
fi

process_options
process_defaults
check_environment
if [ "$ACTION" = "check" ]; then
  exit
fi
process_actions
