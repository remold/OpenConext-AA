#!/bin/bash
##
## Installation script for OpenConext Shibboleth AA 
## If needed activate the DEBUG
#export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x
##
## Base directory where the scripts (and config etc) are downloaded.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SRC_DIR='/usr/local/src'
VERSION="${2:-2.4.3}"
MYSQL_VERSION="${2:-5.1.34}"
IDP_URL="https://shibboleth.net/downloads/identity-provider/latest/shibboleth-identityprovider-${VERSION}-bin.zip"
IDP_KEY_URL="http://shibboleth.net/downloads/identity-provider/latest/shibboleth-identityprovider-${VERSION}-bin.zip.asc"
SHIB_KEYS_URL='http://shibboleth.net/downloads/PGP_KEYS'
MYSQL_URL="http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-$MYSQL_VERSION.zip"

## Some displaying functions
function echoHeader {
NOW=$(date +"%T")
echo -e "\n"
echo -e "#############################################################################"
echo -e "# $1 ($NOW)"
echo -e "#############################################################################"
echo -e "\n"
sleep 2
}

echoHeader "Installing Shibboleth IdP"

## Set JAVA_HOME
export JAVA_HOME=/usr

## Get zip files names
FILE=${IDP_URL##*/}
FILEKEY=${IDP_KEY_URL##*/}
MYSQL_FILE=${MYSQL_URL##*/}

echoHeader "Downloading $FILE source files in $SRC_DIR"

if [ -d "/opt/shibboleth-idp/" ]; then
echo "It looks like there is already an IdP installed here! Trying an update..."
sleep 2
fi

cd "${SRC_DIR}"

## Download Shibboleth IdP
wget $IDP_URL -O "${SRC_DIR}/$FILE" &&
wget $IDP_KEY_URL -O "${SRC_DIR}/$FILEKEY" &&
wget $SHIB_KEYS_URL -O "${SRC_DIR}/KEYS" &&

echo -e "Shibboleth IdP downloads done!\n"

## Check files integrity
gpg --import KEYS
gpg --verify $FILEKEY
unzip $FILE

## install Shibboleth IdP
cd "shibboleth-identityprovider-${VERSION}"

echoHeader "IdP Installation. Please answer the following questions"

sh install.sh

## Add MySQL JDBC connector for IdP and OPTIONNALY to tomcat
echo "Getting MySQL JDBC connector..."
sleep 2
cd $SRC_DIR
wget $MYSQL_URL -O $MYSQL_FILE &&
unzip $MYSQL_FILE
## Remove .zip and get dir name
MYSQL_DIR="${MYSQL_FILE%.zip}"

cp $MYSQL_DIR/mysql-connector-java-$MYSQL_VERSION-bin.jar /opt/shibboleth-idp/lib/mysql-connector-java-$MYSQL_VERSION-bin.jar
if [ ! -f /opt/tomcat/shared/lib/mysql-connector-java.jar ]; then
cp $MYSQL_DIR/mysql-connector-java-$MYSQL_VERSION-bin.jar /opt/tomcat/lib/mysql-connector-java-$MYSQL_VERSION-bin.jar
fi

## Go back to the script directory 
cd $DIR
cd ..

## copy AA IdP config files (ATTENTION: Attribute Filter is just a sample)
mv /opt/shibboleth-idp/conf/attribute-resolver.xml /opt/shibboleth-idp/conf/attribute-resolver.xml.dist
mv /opt/shibboleth-idp/conf/attribute-filter.xml /opt/shibboleth-idp/conf/attribute-filter.xml.dist
mv /opt/shibboleth-idp/conf/service.xml /opt/shibboleth-idp/conf/service.xml.dist
cp configs/attribute-resolver.xml /opt/shibboleth-idp/conf/attribute-resolver.xml
cp configs/attribute-filter.xml /opt/shibboleth-idp/conf/attribute-filter.xml
cp configs/service.xml /opt/shibboleth-idp/conf/service.xml

## Adding IdP Context Deployment Fragment
if [ ! -d "/etc/tomcat6/Catalina/localhost" ]; then
mkdir /etc/tomcat6/Catalina/localhost
fi
cp configs/idp.xml /etc/tomcat6/Catalina/localhost/idp.xml

chown -R tomcat /opt/shibboleth-idp

## OPTIONAL: adding a JAR to enable SOAP endpoints only if tomcat is used as port 8443 manager
## IF you choose this, please deisable HTTPD 8443 port magement in the following HTTPD config files
#cd $SRC_DIR
#wget "https://build.shibboleth.net/nexus/content/repositories/releases/edu/internet2/middleware/security/tomcat6/tomcat6-dta-ssl/1.0.0/tomcat6-dta-ssl-1.0.0.jar" 
#cp tomcat6-dta-ssl-1.0.0.jar /opt/tomcat/lib/tomcat6-dta-ssl-1.0.0.jar
#cd $DIR
#cd ..

#Adding attribute autority httpd virtualhost
cp configs/aa.conf /etc/httpd/conf.d/aa.conf

## Edit httpd config to listen on port 8443
LISTENLINE='Listen 8443'
PORTLINE='NameVirtualHost *:8443'

sed -i.bak "/Listen 443/ a$LISTENLINE\n" /etc/httpd/conf.d/ssl.conf
sed -i.bak "\$a$PORTLINE\n" /etc/httpd/conf.d/_default.conf

echoHeader "DONE!"
