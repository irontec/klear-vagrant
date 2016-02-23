#!/bin/bash
saveIFS=$IFS
IFS=$(echo -e -en "\n\b")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

function checkPort {
    changePort=true
    port=$1
    #netstat -ntpl | grep :${params[dockerHttpPort]} -q
    #docker ps -a | grep "0.0.0.0:$port->" -q
    docker inspect $(docker ps -aq) | grep HostPort | grep $port
    result=$?
    if [ $result -eq 0 ]
    then 
        #echo -e "${RED}Puerto $port ocupado${NC}"
        newPort=$((port+1))
        checkPort $newPort
    #else
        #echo -e "${GREEN}Puerto $port libre${NC}"
    fi
}

if [ -z "$1" ]
then
    echo -e -e "${RED}Hay que especificar un directorio de destino${NC}"
    exit 1
fi 

if [[ "$1" = /* ]]
then
    dir=$1
else
    dir=`pwd`/$1
fi

dir=${dir%.}
dir=${dir%/}
dir=${dir// /\ }

dirBasename=`basename "$dir"`

if [ -L $0 ]
then
    scriptFile=$(readlink -f "$0")
else
    scriptFile=$0
fi

if [[ "$scriptFile" = /* ]]
then
    scriptDir=`dirname $scriptFile`
else
    scriptDir=`pwd`/`dirname $scriptFile`
fi
scriptDir=${scriptDir// /\ }

mkdir "$dir/.initVagrant"
cp -r "$scriptDir/"* "$dir/.initVagrant"
rm "$dir/.initVagrant/initVagrant.sh"

lowerDirBasename=${dirBasename,,}

#Elegir el rol a usar
echo -e "${YELLOW}Elige el rol que quieres configurar: ${NC}"
for file in $(find "$dir/.initVagrant/Provision/roles/"*)
do
    role=`basename $file`
    roleFormatted=${role/#0/ }
    roleFormatted=${roleFormatted/# 0/  }
    roleFormatted=${roleFormatted//-/: }
    roleFormatted=${roleFormatted//_/ }
    roleFormatted=${roleFormatted//.yml/}
    echo -e "${BLUE}    $roleFormatted${NC}"
done
echo -e "${YELLOW}Rol número [por defecto ${BLUE}1${YELLOW}]: ${NC}"
read roleNumber
if [ -z "${roleNumber}" ]
then
    roleNumber="001"
else
	printf -v roleNumber "%03d" $roleNumber
fi

roleFile=$(find "$dir/.initVagrant/Provision/roles/$roleNumber-"*)
roleName=`basename $roleFile`
echo "    - include: roles/$roleName" >> "$dir/.initVagrant/Provision/playbook.yml"

echo ${roleFile}

declare -A params

propossedProyectName=${lowerDirBasename// /}
echo -e "${GREEN}Nombre del proyecto (Solo letras y/o números. Por defecto \"${BLUE}$propossedProyectName${GREEN}\"): ${NC}"
read params[proyectName]
if [ -z "${params[proyectName]}" ]
then
    params[proyectName]="$propossedProyectName"
fi
params[proyectNameToLowwer]="${params[proyectName],,}"

echo -e "${GREEN}Nombre de la imagen de docker a usar (por defecto '${BLUE}irontec/debian:jessieInit${GREEN}'): ${NC}"
read params[dockerImage]
if [ -z "${params[dockerImage]}" ]
then
    params[dockerImage]='irontec/debian:jessieInit'
fi
#params[dockerImage]="${params[dockerImage]//\//\\/}"

###Puertos a mapear###
params[dockerPhp5SshPort]="2522"
checkPort ${params[dockerPhp5SshPort]}
params[dockerPhp5SshPort]=$port
echo -e "${YELLOW}se mapeará el puerto ${params[dockerPhp5SshPort]} local con el puerto 22 del contenedor${NC}"
dockerPhp5Ports="[\"${params[dockerPhp5SshPort]}:22\""
params[dockerPhp7SshPort]="2522"
checkPort ${params[dockerPhp7SshPort]}
params[dockerPhp7SshPort]=$port
echo -e "${YELLOW}se mapeará el puerto ${params[dockerPhp7SshPort]} local con el puerto 22 del contenedor${NC}"
dockerPhp7Ports="[\"${params[dockerPhp7SshPort]}:22\""

grep -iq webserver ${roleFile}
if [ "$?" == "0" ]
then  
	params[dockerPhp5HttpPort]="8580"
	checkPort ${params[dockerPhp5HttpPort]}
	params[dockerPhp5HttpPort]=$port
	echo -e "${YELLOW}se mappeará el puerto ${params[dockerPhp5HttpPort]} local con el puerto 80 del contenedor${NC}"
	dockerPhp5Ports="${dockerPhp5Ports},\"${params[dockerPhp5HttpPort]}:80\""
	params[dockerPhp7HttpPort]="8780"
    checkPort ${params[dockerPhp7HttpPort]}
    params[dockerPhp7HttpPort]=$port
	echo -e "${YELLOW}se mappeará el puerto ${params[dockerPhp7HttpPort]} local con el puerto 80 del contenedor${NC}"
	dockerPhp7Ports="${dockerPhp7Ports},\"${params[dockerPhp7HttpPort]}:80\""
    params[dockerPhp5HttpsPort]="9543"
	checkPort ${params[dockerPhp5HttpsPort]}
	params[dockerPhp5HttpsPort]=$port
	echo -e "${YELLOW}se mapeará el puerto ${params[dockerPhp5HttpsPort]} local con el puerto 443 del contenedor${NC}"
	dockerPhp5Ports="${dockerPhp5Ports},\"${params[dockerPhp5HttpsPort]}:443\""
    params[dockerPhp7HttpsPort]="9743"
    checkPort ${params[dockerPhp7HttpsPort]}
    params[dockerPhp7HttpsPort]=$port
    echo -e "${YELLOW}se mapeará el puerto ${params[dockerPhp7HttpsPort]} local con el puerto 443 del contenedor${NC}"
    dockerPhp7Ports="${dockerPhp7Ports},\"${params[dockerPhp7HttpsPort]}:443\""
fi
params[dockerPhp5Ports]="${dockerPhp5Ports}]"
params[dockerPhp7Ports]="${dockerPhp7Ports}]"


###Volúmenes###
runKlearStarter=false
params[klearSyncedFolder]=""
grep -iq zendframework ${roleFile}
if [ "$?" == "0" ]
then  
	echo -e "${GREEN}Carpeta de la librería de Klear (por defecto en '${BLUE}/opt/klear-development${GREEN}'): ${NC}"
	read params[klearLibraryFolder]
	if [ -z "${params[klearLibraryFolder]}" ]
	then
	    params[klearLibraryFolder]="/opt/klear-development"
	fi
	params[klearSyncedFolder]="config.vm.synced_folder \"${params[klearLibraryFolder]}\", \"/opt/klear-development\""
    runKlearStarter=true
fi

###Database###
params[dataBaseName]=""
params[dataBaseUser]=""
params[dataBasePassword]=""
grep -iq database ${roleFile}
if [ "$?" == "0" ]
then  
	echo -e "${GREEN}Nombre de la base de datos (por defecto ${BLUE}${params[proyectNameToLowwer]}${GREEN}): ${NC}"
	read params[dataBaseName]
	if [ -z "${params[dataBaseName]}" ]
	then
	    params[dataBaseName]=${params[proyectNameToLowwer]}
	fi
	echo -e "${GREEN}Usuario de la base de datos (por defecto ${BLUE}root${GREEN}): ${NC}"
	read params[dataBaseUser]
	if [ -z "${params[dataBaseUser]}" ]
	then
	    params[dataBaseUser]="root"
	fi
	echo -e "${YELLOW}Contraseña de la base de datos: ${NC}"
	read -s params[dataBasePassword]
	if [ -z "${params[dataBasePassword]}" ]
	then
	    echo -e "${RED}Debes especificar una contraseña para la base de datos${NC}"
	    exit 2
	fi
fi

params[dImageLine]="d.image = \"${params[dockerImage]}\""
params[dBuildDirLine]='d.build_dir = "\./"'
uid=$(id -u)
params[uid]=$uid

if [ "$uid" != "1000" ]; then
   echo -e "${YELLOW}El uid del usuario es $uid por lo que no se puede usar la imagen que se encuentra en el servidor"
   echo -e "Hay que construir una imagen nueva a partir del Dockerfile"
   echo -e "Al hacer 'vagrant up' se creará una imagen nueva${NC}"
   params[dImageLine]="#${params[dImageLine]}"
else
    params[dBuildDirLine]="#${params[dBuildDirLine]}"
fi

for file in $(find "$dir/.initVagrant/"* -not -name "start.sh" -not -name "README.md")
do
    for i in "${!params[@]}"
    do
        if [ ! -d "$file" ]
        then
        	param=${params[$i]//\//\\\/}
        	param=${param//\#/\\\#}
            regex="s/{{$i}}/${param}/g"
            regex=${regex//\"/\\\"}
            
            sed -i "$regex" $file
            if [ "$?" != "0" ]
            then
            	echo "sed -i \"$regex\" $file"
    		fi
        fi
    done
done

cp -r $dir/.initVagrant/* $dir/
rm -rf $dir/.initVagrant

IFS=$saveIFS

if [ "$runKlearStarter" = true ]
then
	echo -e "${GREEN}Ejecutando 'composer create-project irontec/klear-starter $dir/temp'.${NC}"

	composer create-project irontec/klear-starter $dir/temp
	mv $dir/temp/* $dir/
	mv $dir/temp/.* $dir/
	rm -rf $dir/temp
fi

echo -e "${GREEN}Se ha configurado correctamente el proyecto para usar con Vagrant, Ansible y Docker."
echo -e "Ejecuta 'vagrant up' para arrancar el contenedor${NC}"

exit 0